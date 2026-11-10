defmodule DialecticWeb.GridHistoryComp do
  use DialecticWeb, :live_component
  import DialecticWeb.ActivityComponents, only: [activity_actor: 1]
  alias Dialectic.GridActivity
  alias DialecticWeb.Utils.NodeTitleHelper

  @page_size 25

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:events, dom_id: &"grid-activity-log-#{&1.id}")
     |> stream(:events, [])}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(Map.drop(assigns, [:refresh]))
      |> assign_new(:empty?, fn -> true end)
      |> assign_new(:has_more?, fn -> false end)
      |> assign_new(:before, fn -> nil end)
      |> assign_new(:last_day, fn -> nil end)

    {:ok, if(assigns[:refresh], do: load_page(socket, nil, true), else: socket)}
  end

  @impl true
  def handle_event("load_earlier", _params, socket) do
    {:noreply,
     if(socket.assigns.has_more?,
       do: load_page(socket, socket.assigns.before, false),
       else: socket
     )}
  end

  defp load_page(socket, before, reset?) do
    events =
      GridActivity.list_for_graph(socket.assigns.graph_id, limit: @page_size + 1, before: before)

    page = Enum.take(events, @page_size)
    last = List.last(page)

    {page, last_day} =
      Enum.map_reduce(page, if(reset?, do: nil, else: socket.assigns.last_day), fn event,
                                                                                   previous_day ->
        day = Calendar.strftime(event.inserted_at, "%d %B %Y")
        {Map.put(event, :day_label, if(day != previous_day, do: day)), day}
      end)

    socket
    |> assign(:empty?, if(reset?, do: page == [], else: socket.assigns.empty?))
    |> assign(:last_day, last_day)
    |> assign(:has_more?, length(events) > @page_size)
    |> assign(:before, if(last, do: {last.inserted_at, last.id}, else: before))
    |> stream(:events, page, reset: reset?)
  end

  defp activity_timestamp(nil), do: ""

  defp activity_timestamp(%DateTime{} = inserted_at) do
    "#{inserted_at.day} #{Calendar.strftime(inserted_at, "%b %Y")} · #{Calendar.strftime(inserted_at, "%H:%M")}"
  end

  defp activity_timestamp(inserted_at), do: to_string(inserted_at)

  defp activity_datetime(%DateTime{} = inserted_at), do: DateTime.to_iso8601(inserted_at)
  defp activity_datetime(_inserted_at), do: nil

  defp activity_node_ref(%{node_id: node_id} = log, graph_id)
       when is_binary(node_id) and node_id != "" do
    case GraphManager.find_node_by_id(graph_id, node_id) do
      nil ->
        activity_node_ref_from_metadata(log)

      node ->
        %{
          id: node_id,
          title: NodeTitleHelper.extract_node_title(node, max_length: 70),
          deleted: Map.get(node, :deleted, false)
        }
    end
  end

  defp activity_node_ref(_log, _graph_id), do: nil

  defp activity_node_ref_from_metadata(log) do
    metadata = Map.get(log, :metadata) || %{}

    case Map.get(metadata, "node_title") do
      title when is_binary(title) and title != "" ->
        %{
          id: log.node_id,
          title: title,
          deleted: log.action == "node.deleted"
        }

      _ ->
        nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="grid-history-content" class="px-3 pb-4">
      <p id="grid-history-description" class="mb-5 text-sm leading-6 text-slate-600">
        Follow the questions, contributions, and edits that shaped this grid, and meet the people behind them.
      </p>
      <div
        id="grid-history-origin"
        class="mb-5 rounded-xl border border-stone-300 border-l-4 border-l-teal-800 bg-white p-4"
      >
        <p class="mb-2 text-xs font-semibold uppercase tracking-wide text-teal-800">
          This grid began
        </p>
        <.activity_actor id="grid-history-creator" actor={@creator} name="Community contributor" />
        <p class="mt-2 text-sm text-slate-600">
          Created
          <time datetime={activity_datetime(@graph_struct.inserted_at)}>{activity_timestamp(
            @graph_struct.inserted_at
          )}</time>
        </p>
        <p class="mt-2 text-sm font-medium text-slate-900">{@graph_struct.title}</p>
      </div>
      <p :if={!@empty?} class="mb-2 text-[11px] font-medium text-slate-600">
        Questions, contributions, and edits · newest first
      </p>
      <ol
        id="grid-activity-log"
        phx-update="stream"
        class="divide-y divide-stone-300"
      >
        <li
          :for={{dom_id, log} <- @streams.events}
          id={dom_id}
          class="py-4"
        >
          <h3 :if={log.day_label} class="mb-4 text-xs font-semibold text-slate-600">
            {log.day_label}
          </h3>
          <% node_ref = activity_node_ref(log, @graph_id) %>
          <div class="min-w-0">
            <p class="flex flex-wrap items-center gap-1.5 text-sm leading-6 text-slate-700">
              <.activity_actor
                id={"grid-activity-actor-#{log.id}"}
                actor={log.actor}
                name={log.actor_name}
              />
              <span>{GridActivity.action_label(log)}</span>
            </p>
            <time
              id={"grid-activity-time-#{log.id}"}
              datetime={activity_datetime(log.inserted_at)}
              class="block text-[11px] font-medium uppercase tracking-[0.08em] text-slate-600"
            >
              {activity_timestamp(log.inserted_at)}
            </time>
            <%= if node_ref && node_ref.deleted do %>
              <span
                id={"grid-activity-node-#{log.id}"}
                class="mt-2 flex max-w-full items-start gap-2 border border-stone-200 bg-stone-50 px-2.5 py-2 text-[11px] font-medium leading-4 text-slate-600"
                title={node_ref.title}
              >
                <.icon name="hero-trash" class="mt-0.5 h-3.5 w-3.5 shrink-0" />
                <span class="line-clamp-2">{node_ref.title}</span>
              </span>
            <% else %>
              <%= if node_ref do %>
                <button
                  type="button"
                  id={"grid-activity-node-#{log.id}"}
                  phx-click="navigate_to_node"
                  phx-value-node_id={node_ref.id}
                  class="mt-2 flex w-full items-start gap-2 border border-stone-200 bg-stone-50 px-2.5 py-2 text-left text-[11px] font-medium leading-4 text-slate-700 transition-colors hover:border-teal-600 hover:bg-white hover:text-slate-950"
                  title={node_ref.title}
                >
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="mt-0.5 h-3.5 w-3.5 shrink-0 text-teal-700"
                  />
                  <span class="line-clamp-2">{node_ref.title}</span>
                </button>
              <% end %>
            <% end %>
          </div>
        </li>
      </ol>
      <p :if={@empty?} id="grid-activity-log-empty" class="py-6 text-sm leading-6 text-slate-600">
        This grid’s history will appear here as people ask questions, add ideas, and make edits.
      </p>
      <button
        :if={@has_more?}
        id="grid-history-load-earlier"
        type="button"
        phx-click="load_earlier"
        phx-target={@myself}
        class="mt-4 min-h-11 w-full rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-50"
        phx-disable-with="Loading…"
      >
        Load earlier activity
      </button>
    </div>
    """
  end
end
