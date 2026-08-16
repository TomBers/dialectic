defmodule DialecticWeb.RightPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.GridActivity
  alias Dialectic.Repo
  alias DialecticWeb.Utils.NodeTitleHelper

  @moduledoc """
  Accordion-style right panel with:
  - Node Information (shareable link + exports)
  - Streams (list, focus/toggle, and start)
  - Keyboard Shortcuts
  """

  @impl true
  def update(assigns, socket) do
    node_id =
      case Map.get(assigns, :node) do
        %{} = n ->
          Map.get(n, :id)

        _ ->
          case Map.get(socket.assigns, :node) do
            %{} = n -> Map.get(n, :id)
            _ -> nil
          end
      end

    graph_id =
      case Map.get(assigns, :graph_id) do
        id when is_binary(id) and id != "" ->
          id

        _ ->
          case Map.get(assigns, :graph_struct) do
            %{} = gs ->
              Map.get(gs, :title) || Map.get(socket.assigns, :graph_id, "")

            _ ->
              Map.get(socket.assigns, :graph_id, "")
          end
      end

    share_path =
      if not is_nil(node_id) and node_id != "" and (is_binary(graph_id) and graph_id != "") do
        "/#{graph_id}?node=#{node_id}"
      else
        "/#{graph_id}"
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:share_path, share_path)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:search_results, fn -> [] end)
      |> assign_new(:group_states, fn -> %{} end)
      |> assign_new(:prompt_mode, fn -> "university" end)
      |> assign_new(:highlights, fn -> [] end)
      |> assign_new(:activity_logs, fn -> load_activity_logs(graph_id) end)
      |> assign_new(:editing_highlight_id, fn -> nil end)
      |> assign_new(:open_sections, fn -> MapSet.new() end)
      |> maybe_open_configure(Map.get(assigns, :open_section))

    {:ok, socket}
  end

  defp maybe_open_configure(socket, "configure") do
    update(socket, :open_sections, &MapSet.put(&1, "configure"))
  end

  defp maybe_open_configure(socket, _section), do: socket

  @valid_sections ~w(configure workspace activity export utilities)

  defp load_activity_logs(graph_id) when is_binary(graph_id) and graph_id != "" do
    GridActivity.list_for_graph(graph_id)
  end

  defp load_activity_logs(_graph_id), do: []

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket)
      when section in @valid_sections do
    open_sections = socket.assigns.open_sections

    new_open_sections =
      if MapSet.member?(open_sections, section) do
        MapSet.delete(open_sections, section)
      else
        MapSet.put(open_sections, section)
      end

    {:noreply, assign(socket, :open_sections, new_open_sections)}
  end

  def handle_event("toggle_section", _params, socket) do
    # Ignore unknown section keys to prevent memory growth
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_highlight", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         highlight when not is_nil(highlight) <- Dialectic.Highlights.get_highlight(int_id) do
      if current_user && current_user.id == highlight.created_by_user_id do
        # Preload links before deleting to avoid JSON encoding error during broadcast
        highlight = Repo.preload(highlight, :links)
        Dialectic.Highlights.delete_highlight(highlight)
      end
    end

    {:noreply, socket}
  end

  def handle_event("edit_highlight", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {int_id, ""} -> {:noreply, assign(socket, editing_highlight_id: int_id)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  def handle_event("save_note", %{"highlight_id" => id, "note" => note}, socket) do
    current_user = socket.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         highlight when not is_nil(highlight) <- Dialectic.Highlights.get_highlight(int_id) do
      if current_user && current_user.id == highlight.created_by_user_id do
        Dialectic.Highlights.update_highlight(highlight, %{note: note})
      end
    end

    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  defp owner?(graph_struct, current_user) do
    current_user && graph_struct && graph_struct.user_id == current_user.id
  end

  defp translate_targets do
    [
      {"English (en)", "en"},
      {"Spanish (es)", "es"},
      {"French (fr)", "fr"},
      {"German (de)", "de"},
      {"Portuguese (pt)", "pt"},
      {"Chinese Simplified (zh-CN)", "zh-CN"},
      {"Japanese (ja)", "ja"},
      {"Russian (ru)", "ru"},
      {"Arabic (ar)", "ar"},
      {"Hindi (hi)", "hi"}
    ]
  end

  defp encoded_node_text(node) do
    content =
      node
      |> Kernel.||(%{})
      |> Map.get(:content, "")
      |> to_string()

    # Use the longest target language code ("zh-CN", 5 chars) to compute a conservative max
    base_url = "https://translate.google.com/?sl=auto&tl=zh-CN&text="
    suffix = "&op=translate"
    max_url_len = 2000
    max_text_encoded_len = max_url_len - String.length(base_url) - String.length(suffix)

    truncated = truncate_for_encoded_length(content, max_text_encoded_len)
    URI.encode_www_form(truncated)
  end

  defp google_translate_url(encoded_text, tl) do
    "https://translate.google.com/?sl=auto&tl=#{tl}&text=#{encoded_text}&op=translate"
  end

  defp activity_timestamp(nil), do: ""

  defp activity_timestamp(%DateTime{} = inserted_at) do
    "#{inserted_at.day} #{Calendar.strftime(inserted_at, "%b")} · #{Calendar.strftime(inserted_at, "%H:%M")}"
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

  # Truncates content so that URI.encode_www_form(result) fits within max_encoded_len.
  # Uses binary search on grapheme count to find the longest prefix that encodes within budget.
  defp truncate_for_encoded_length(content, max_encoded_len) do
    encoded = URI.encode_www_form(content)

    if String.length(encoded) <= max_encoded_len do
      content
    else
      total_graphemes = String.length(content)
      # Start with an empty best candidate and search for the longest valid prefix.
      do_truncate_search(content, 0, total_graphemes, "", max_encoded_len)
    end
  end

  # Binary search helper that carries the best (longest valid) prefix found so far.
  defp do_truncate_search(_content, low, high, best, _max_encoded_len) when low >= high do
    best
  end

  defp do_truncate_search(content, low, high, best, max_encoded_len) do
    mid = div(low + high, 2)
    candidate = String.slice(content, 0, mid)
    encoded_len = String.length(URI.encode_www_form(candidate))

    if encoded_len <= max_encoded_len do
      # Candidate fits: it becomes the new best, and we try a longer prefix.
      do_truncate_search(content, mid + 1, high, candidate, max_encoded_len)
    else
      # Candidate too long: search the lower half without changing best.
      do_truncate_search(content, low, mid, best, max_encoded_len)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <%!-- Configure Section --%>
      <details
        id="details-configure"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "configure")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="configure"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-indigo-50 text-indigo-600">
                <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Answer level</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Standard to Expert
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-stone-200 bg-[#f4f1e9] px-3 py-3">
          <div class="space-y-2.5">
            <div class="text-[11px] font-semibold uppercase tracking-[0.14em] text-teal-800">
              Explanation level
            </div>
            <div class="grid grid-cols-3 border border-stone-300 bg-white p-0.5 shadow-inner">
              <%= for {mode, label, description} <- [
                {"high_school", "Standard", "Simple language and concrete examples."},
                {"university", "Detailed", "Useful terminology, context, and nuance."},
                {"expert", "Expert", "Rigorous evidence and competing views."}
              ] do %>
                <button
                  type="button"
                  id={"answer-level-#{mode}"}
                  phx-click={
                    Phoenix.LiveView.JS.push("set_prompt_mode")
                    |> Phoenix.LiveView.JS.dispatch("toggle-panel",
                      to: "#graph-layout",
                      detail: %{id: "right-panel"}
                    )
                  }
                  phx-value-prompt_mode={mode}
                  aria-pressed={if(@prompt_mode == mode, do: "true", else: "false")}
                  class={[
                    "group flex min-h-16 flex-col items-start px-3 py-2 text-left transition-colors duration-150",
                    if @prompt_mode == mode do
                      "border border-slate-900 bg-slate-900 text-white shadow-sm"
                    else
                      "border border-transparent text-slate-600 hover:bg-stone-50 hover:text-slate-900"
                    end
                  ]}
                >
                  <span class="text-xs font-semibold">{label}</span>
                  <span class={[
                    "mt-0.5 text-[10px] leading-4",
                    if(@prompt_mode == mode, do: "text-slate-300", else: "text-slate-500")
                  ]}>
                    {description}
                  </span>
                </button>
              <% end %>
            </div>
            <p class="text-[10px] leading-4 text-slate-600">
              Sets the language and depth of new AI answers.
            </p>
          </div>
        </div>
      </details>

      <%!-- Workspace Section --%>
      <details
        id="details-workspace"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "workspace")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="workspace"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-emerald-50 text-emerald-600">
                <.icon name="hero-folder" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Access & collaboration</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Groups, editing, and visibility
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5 space-y-3">
          <%!-- Groups subsection --%>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
                Groups ({length(@work_streams)})
              </div>
              <button
                type="button"
                phx-click="open_start_stream_modal"
                class="inline-flex items-center gap-1 text-[11px] font-medium text-indigo-600 hover:text-indigo-800 transition-colors"
              >
                <.icon name="hero-plus" class="w-3 h-3" /> New
              </button>
            </div>
            <div class="max-h-40 overflow-y-auto">
              <%= if @work_streams && length(@work_streams) > 0 do %>
                <ul class="space-y-1">
                  <%= for s <- @work_streams do %>
                    <li class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-md bg-gray-50 hover:bg-gray-100 transition-colors">
                      <span class="text-xs text-gray-700 truncate flex-1">{s.id}</span>
                      <div class="flex items-center gap-1">
                        <button
                          type="button"
                          phx-click="focus_stream"
                          phx-value-id={s.id}
                          class="px-2 py-1 rounded-md text-[10px] font-medium text-gray-600 hover:bg-white hover:text-gray-800 transition-colors"
                        >
                          Focus
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_stream"
                          phx-value-id={s.id}
                          class="px-2 py-1 rounded-md text-[10px] font-medium text-gray-600 hover:bg-white hover:text-gray-800 transition-colors"
                        >
                          Toggle
                        </button>
                        <%= if s.id != "Main" do %>
                          <button
                            type="button"
                            phx-click="delete_stream"
                            phx-value-id={s.id}
                            class="px-2 py-1 rounded-md text-[10px] font-medium text-red-600 hover:bg-red-50 hover:text-red-700 transition-colors"
                            title="Delete group (must be empty)"
                          >
                            <.icon name="hero-trash" class="w-3 h-3" />
                          </button>
                        <% end %>
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% else %>
                <p class="text-[11px] text-gray-400 text-center py-2">No groups yet</p>
              <% end %>
            </div>
          </div>

          <%!-- Access subsection (owner only) --%>
          <%= if owner?(@graph_struct, @current_user) do %>
            <div class="pt-2 border-t border-gray-100 space-y-2">
              <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
                Access
              </div>
              <DialecticWeb.LockComp.render id="lock-graph" graph_struct={@graph_struct} />
              <button
                phx-click={
                  Phoenix.LiveView.JS.dispatch("toggle-panel",
                    to: "#graph-layout",
                    detail: %{id: "right-panel"}
                  )
                  |> Phoenix.LiveView.JS.push("open_share_modal")
                }
                class="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium border border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors"
              >
                <%= if @graph_struct.is_public do %>
                  <.icon name="hero-share" class="w-3.5 h-3.5" />
                  <span>Share Grid</span>
                <% else %>
                  <.icon name="hero-user-plus" class="w-3.5 h-3.5" />
                  <span>Manage Collaborators</span>
                <% end %>
              </button>
            </div>
          <% end %>
        </div>
      </details>

      <%!-- Activity Section --%>
      <details
        id="details-activity"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "activity")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="activity"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-amber-50 text-amber-600">
                <.icon name="hero-clock" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Activity</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Questions, additions, and edits
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-stone-200 bg-[#f4f1e9] px-3 py-3">
          <%= if @activity_logs && length(@activity_logs) > 0 do %>
            <ol
              id="grid-activity-log"
              class="max-h-72 divide-y divide-stone-200 overflow-y-auto border-y border-stone-200 bg-white px-3"
            >
              <li
                :for={log <- @activity_logs}
                id={"grid-activity-log-#{log.id}"}
                class="grid grid-cols-[0.75rem_minmax(0,1fr)] gap-2.5 py-3"
              >
                <% node_ref = activity_node_ref(log, @graph_id) %>
                <span class="mt-1.5 h-2.5 w-2.5 rounded-full border-2 border-white bg-amber-500 ring-1 ring-amber-200">
                </span>
                <div class="min-w-0">
                  <p class="text-xs leading-5 text-slate-700">
                    <span id={"grid-activity-actor-#{log.id}"} class="font-semibold text-slate-950">
                      {GridActivity.actor_name(log.actor_name)}
                    </span>
                    <span>{GridActivity.action_label(log)}</span>
                  </p>
                  <time
                    id={"grid-activity-time-#{log.id}"}
                    datetime={activity_datetime(log.inserted_at)}
                    class="block text-[10px] font-medium uppercase tracking-[0.08em] text-slate-500"
                  >
                    {activity_timestamp(log.inserted_at)}
                  </time>
                  <%= if node_ref && node_ref.deleted do %>
                    <span
                      id={"grid-activity-node-#{log.id}"}
                      class="mt-2 flex max-w-full items-start gap-2 border border-stone-200 bg-stone-50 px-2.5 py-2 text-[11px] font-medium leading-4 text-slate-500"
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
          <% else %>
            <p id="grid-activity-log-empty" class="text-[11px] text-gray-400 text-center py-2">
              No activity yet
            </p>
          <% end %>
        </div>
      </details>

      <%!-- Export Section --%>
      <details
        id="details-export"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "export")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="export"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-sky-50 text-sky-600">
                <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Export</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Download your grid
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <div class="grid grid-cols-1 gap-2">
            <button
              type="button"
              class="download-png flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              aria-label="Download PNG"
              title="Download PNG (Alt-click to capture full graph)"
            >
              <.icon name="hero-photo" class="w-4 h-4 text-emerald-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download PNG</div>
                <div class="text-[10px] text-gray-500">Image snapshot of graph</div>
              </div>
            </button>
            <.link
              href={
                path =
                  if @graph_struct && @graph_struct.slug,
                    do: "/api/graphs/md/#{@graph_struct.slug}",
                    else: "/api/graphs/md/#{URI.encode(@graph_id)}"

                if assigns[:token],
                  do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
                  else: path
              }
              download={
                if @graph_struct && @graph_struct.slug,
                  do: "#{@graph_struct.slug}.md",
                  else: "#{@graph_id}.md"
              }
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download Markdown"
            >
              <.icon name="hero-document-text" class="w-4 h-4 text-purple-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download Markdown</div>
                <div class="text-[10px] text-gray-500">Plain text with formatting</div>
              </div>
            </.link>

            <.link
              href={
                path =
                  if @graph_struct && @graph_struct.slug,
                    do: "/api/graphs/json/#{@graph_struct.slug}",
                    else: "/api/graphs/json/#{URI.encode(@graph_id)}"

                if assigns[:token],
                  do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
                  else: path
              }
              download={
                if @graph_struct && @graph_struct.slug,
                  do: "#{@graph_struct.slug}.json",
                  else: "#{@graph_id}.json"
              }
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download JSON (for image generation)"
            >
              <.icon name="hero-code-bracket" class="w-4 h-4 text-blue-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download JSON</div>
                <div class="text-[10px] text-gray-500">Minimal data for visualization</div>
              </div>
            </.link>
          </div>
        </div>
      </details>

      <%!-- Utilities Section --%>
      <details
        id="details-utilities"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "utilities")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="utilities"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-orange-50 text-orange-600">
                <.icon name="hero-language" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Translate</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Read this node in other languages
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <% encoded_text = encoded_node_text(@node) %>
          <div class="flex flex-wrap gap-1.5">
            <%= for {label, code} <- translate_targets() do %>
              <a
                href={google_translate_url(encoded_text, code)}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center px-2.5 py-1.5 rounded-lg border border-gray-200 bg-white text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-900 transition-colors shadow-sm"
              >
                {label}
              </a>
            <% end %>
          </div>
          <p class="mt-2 text-[10px] text-gray-400">
            Opens Google Translate with the current node's content.
          </p>
        </div>
      </details>
    </div>
    """
  end
end
