defmodule DialecticWeb.HighlightsPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Highlights
  alias Dialectic.Graph.GraphActions
  alias DialecticWeb.Utils.NodeTitleHelper

  @impl true
  def update(assigns, socket) do
    graph_id = assigns[:graph_id] || socket.assigns[:graph_id]
    node_titles = resolve_node_titles(assigns, socket.assigns, graph_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:graph_id, graph_id)
     |> assign(:node_titles, node_titles)
     |> assign_new(:editing_highlight_id, fn -> nil end)
     |> assign_new(:visible_node_ids, fn -> [] end)}
  end

  @impl true
  def handle_event("delete_highlight", %{"id" => id}, socket) do
    with {:ok, highlight_id} <- parse_highlight_id(id),
         current_user when not is_nil(current_user) <- socket.assigns.current_user,
         highlight when not is_nil(highlight) <- Highlights.get_highlight(highlight_id),
         true <- highlight.created_by_user_id == current_user.id do
      Highlights.delete_highlight(highlight)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_highlight", %{"id" => id}, socket) do
    case parse_highlight_id(id) do
      {:ok, highlight_id} -> {:noreply, assign(socket, editing_highlight_id: highlight_id)}
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  @impl true
  def handle_event("save_note", %{"highlight_id" => id, "note" => note}, socket) do
    with {:ok, highlight_id} <- parse_highlight_id(id),
         current_user when not is_nil(current_user) <- socket.assigns.current_user,
         highlight when not is_nil(highlight) <- Highlights.get_highlight(highlight_id),
         true <- highlight.created_by_user_id == current_user.id do
      Highlights.update_highlight(highlight, %{note: note})
    end

    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  defp parse_highlight_id(id) when is_integer(id), do: {:ok, id}

  defp parse_highlight_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {highlight_id, ""} -> {:ok, highlight_id}
      _ -> :error
    end
  end

  defp parse_highlight_id(_id), do: :error

  defp link_type_icon("explain"), do: "hero-light-bulb"
  defp link_type_icon("question"), do: "hero-question-mark-circle"
  defp link_type_icon("pro"), do: "hero-hand-thumb-up"
  defp link_type_icon("con"), do: "hero-hand-thumb-down"
  defp link_type_icon("related_idea"), do: "hero-arrow-path"
  defp link_type_icon("deep_dive"), do: "hero-book-open"
  defp link_type_icon(_), do: "hero-link"

  defp link_type_color("explain"), do: "text-gray-500"
  defp link_type_color("question"), do: "text-sky-500"
  defp link_type_color("pro"), do: "text-emerald-500"
  defp link_type_color("con"), do: "text-red-500"
  defp link_type_color("related_idea"), do: "text-orange-500"
  defp link_type_color("deep_dive"), do: "text-cyan-500"
  defp link_type_color(_), do: "text-gray-500"

  defp link_type_label("explain"), do: "Explanation"
  defp link_type_label("question"), do: "Question"
  defp link_type_label("pro"), do: "Pro Argument"
  defp link_type_label("con"), do: "Con Argument"
  defp link_type_label("related_idea"), do: "Related Idea"
  defp link_type_label("deep_dive"), do: "Deep Dive"
  defp link_type_label(_), do: "Link"

  defp has_links?(highlight) do
    highlight.links && length(highlight.links) > 0
  end

  defp note_present?(highlight) do
    is_binary(highlight.note) && String.trim(highlight.note) != ""
  end

  defp visible_in_view?(highlight, visible_node_ids) do
    highlight.node_id in (visible_node_ids || [])
  end

  defp note_count(highlights) do
    Enum.count(highlights, &note_present?/1)
  end

  defp total_link_count(highlights) do
    Enum.reduce(highlights, 0, fn highlight, total ->
      total + length(highlight.links || [])
    end)
  end

  defp resolve_node_titles(new_assigns, current_assigns, graph_id) do
    node_titles =
      Map.merge(current_assigns[:node_titles] || %{}, new_assigns[:node_titles] || %{})

    if is_binary(graph_id) and graph_id != "" do
      node_ids =
        (new_assigns[:highlights] || current_assigns[:highlights] || [])
        |> Enum.flat_map(fn highlight ->
          [highlight.node_id | Enum.map(highlight.links || [], & &1.node_id)]
        end)
        |> Enum.uniq()

      Enum.reduce(node_ids, node_titles, fn node_id, acc ->
        case GraphActions.find_node(graph_id, node_id) do
          nil ->
            acc

          node ->
            Map.put_new(acc, node_id, NodeTitleHelper.extract_node_title(node, max_length: 48))
        end
      end)
    else
      node_titles
    end
  end

  defp node_title(node_titles, node_id) do
    Map.get(node_titles || %{}, node_id, "Untitled")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 pb-4">
      <%= if length(@highlights) > 0 do %>
        <div class="rounded-2xl border border-slate-200 bg-slate-50 shadow-sm">
          <div class="grid grid-cols-3 divide-x divide-slate-200">
            <div class="px-3 py-3">
              <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                Highlights
              </p>
              <p class="mt-1 text-lg font-semibold text-slate-900">{length(@highlights)}</p>
            </div>
            <div class="px-3 py-3">
              <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                Notes
              </p>
              <p class="mt-1 text-lg font-semibold text-slate-900">{note_count(@highlights)}</p>
            </div>
            <div class="px-3 py-3">
              <p class="text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                Links
              </p>
              <p class="mt-1 text-lg font-semibold text-slate-900">{total_link_count(@highlights)}</p>
            </div>
          </div>
        </div>

        <%= for highlight <- @highlights do %>
          <div
            id={"highlight-card-#{highlight.id}"}
            class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm transition-colors hover:border-slate-300"
          >
            <%= if @editing_highlight_id == highlight.id do %>
              <.form
                for={%{}}
                id={"highlight-note-form-#{highlight.id}"}
                phx-submit="save_note"
                phx-target={@myself}
                class="flex flex-col gap-3 p-4"
              >
                <input type="hidden" name="highlight_id" value={highlight.id} />
                <div class="space-y-1">
                  <label
                    for={"highlight-note-#{highlight.id}"}
                    class="text-xs font-semibold text-gray-700"
                  >
                    Note
                  </label>
                  <textarea
                    id={"highlight-note-#{highlight.id}"}
                    name="note"
                    class="w-full text-sm border border-indigo-200 rounded-md px-3 py-2 focus:ring-indigo-500 focus:border-indigo-500 min-h-[6rem] bg-indigo-50/30"
                    rows="4"
                    placeholder="Why this matters"
                    autofocus
                  ><%= highlight.note %></textarea>
                </div>
                <div class="flex justify-end gap-2">
                  <button
                    id={"highlight-note-cancel-#{highlight.id}"}
                    type="button"
                    phx-click="cancel_edit"
                    phx-target={@myself}
                    class="px-3 py-1.5 text-sm font-medium text-gray-600 bg-gray-100 rounded-md hover:bg-gray-200"
                  >
                    Cancel
                  </button>
                  <button
                    id={"highlight-note-save-#{highlight.id}"}
                    type="submit"
                    class="px-3 py-1.5 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
                  >
                    Save Note
                  </button>
                </div>
              </.form>
            <% else %>
              <div class="flex flex-col">
                <button
                  type="button"
                  class="mx-4 mt-3 rounded-xl border border-slate-200 border-t-4 border-t-blue-500 bg-slate-50 px-4 py-3 text-left transition hover:border-slate-300 hover:border-t-blue-600 hover:bg-slate-100"
                  phx-click="highlight_clicked"
                  phx-value-id={highlight.id}
                  phx-value-node-id={highlight.node_id}
                  title="Go to highlight"
                >
                  <div class="mb-3 flex items-start justify-between gap-3">
                    <div class="min-w-0 flex items-center gap-2">
                      <p class="truncate text-sm font-semibold text-slate-900">
                        {node_title(@node_titles, highlight.node_id)}
                      </p>
                      <%= if visible_in_view?(highlight, @visible_node_ids) do %>
                        <span
                          class="mt-0.5 inline-flex h-2.5 w-2.5 shrink-0 rounded-full bg-emerald-500 ring-2 ring-emerald-100"
                          title="Visible in the current view"
                          aria-label="In view"
                        >
                        </span>
                      <% end %>
                    </div>
                  </div>
                  <blockquote class="border-l-2 border-slate-300 pl-4 font-serif text-[15px] leading-7 text-slate-900 break-words sm:text-base">
                    “{highlight.selected_text_snapshot}”
                  </blockquote>
                </button>

                <%= if note_present?(highlight) do %>
                  <div class="mx-4 mt-2.5 rounded-xl border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700 break-words">
                    <div class="mb-1.5 flex items-center gap-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                      <.icon name="hero-chat-bubble-left-ellipsis" class="h-3.5 w-3.5" /> Note
                    </div>
                    <p>{highlight.note}</p>
                  </div>
                <% end %>

                <div class="flex flex-col gap-2.5 px-4 py-3">
                  <%= if has_links?(highlight) do %>
                    <div class="rounded-xl border border-slate-200 bg-slate-50/80 p-2.5">
                      <div class="flex flex-wrap gap-2">
                        <%= for link <- highlight.links do %>
                          <button
                            type="button"
                            phx-click="navigate_to_node"
                            phx-value-node_id={link.node_id}
                            title={"Navigate to " <> link_type_label(link.link_type)}
                            class="inline-flex max-w-full items-center gap-1.5 rounded-full border border-white bg-white px-2.5 py-1.5 text-left shadow-sm transition hover:border-slate-300 hover:bg-slate-100"
                          >
                            <.icon
                              name={link_type_icon(link.link_type)}
                              class={"h-3.5 w-3.5 shrink-0 " <> link_type_color(link.link_type)}
                            />
                            <span class="truncate text-[11px] font-medium text-slate-700">
                              {link_type_label(link.link_type)}
                            </span>
                            <span class="truncate text-[10px] text-slate-500">
                              {node_title(@node_titles, link.node_id)}
                            </span>
                          </button>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <div class="flex items-center justify-end gap-1.5 border-t border-slate-100 pt-1">
                    <button
                      type="button"
                      data-copy-url={DialecticWeb.Endpoint.url() <> graph_path(@graph_struct, highlight.node_id, highlight: highlight.id)}
                      onclick="navigator.clipboard.writeText(this.dataset.copyUrl).then(() => {
                        const el = this.querySelector('.copy-feedback');
                        el.classList.remove('hidden');
                        setTimeout(() => el.classList.add('hidden'), 2000);
                      })"
                      class="relative inline-flex items-center gap-1 rounded-full border border-slate-200 bg-white px-2.5 py-1.5 text-[11px] font-semibold text-slate-600 transition hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900"
                      title="Copy link"
                    >
                      <.icon name="hero-link" class="h-3.5 w-3.5" />
                      <span>Copy link</span>
                      <span class="copy-feedback hidden absolute bottom-full left-1/2 z-10 mb-1 -translate-x-1/2 whitespace-nowrap rounded bg-slate-900 px-2 py-1 text-[10px] text-white">
                        Copied!
                      </span>
                    </button>

                    <%= if @current_user && @current_user.id == highlight.created_by_user_id do %>
                      <button
                        id={"highlight-note-edit-#{highlight.id}"}
                        type="button"
                        phx-click="edit_highlight"
                        phx-target={@myself}
                        phx-value-id={highlight.id}
                        class="inline-flex items-center gap-1 rounded-full border border-slate-200 px-2.5 py-1.5 text-[11px] font-semibold text-slate-700 transition-colors hover:bg-slate-50"
                        title={if note_present?(highlight), do: "Edit note", else: "Add note"}
                        aria-label={
                          if note_present?(highlight),
                            do: "Edit highlight note",
                            else: "Add highlight note"
                        }
                      >
                        <.icon name="hero-pencil-square" class="h-3.5 w-3.5" />
                        <span>
                          {if note_present?(highlight), do: "Edit note", else: "Add note"}
                        </span>
                      </button>

                      <button
                        type="button"
                        phx-click="delete_highlight"
                        phx-target={@myself}
                        phx-value-id={highlight.id}
                        data-confirm="Are you sure you want to delete this highlight?"
                        class="inline-flex items-center gap-1 rounded-full border border-transparent px-2.5 py-1.5 text-[11px] font-semibold text-slate-500 transition hover:border-red-200 hover:bg-red-50 hover:text-red-700"
                        title="Delete highlight"
                      >
                        <.icon name="hero-trash" class="h-3.5 w-3.5" />
                        <span>Delete</span>
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <div class="flex flex-col items-center justify-center rounded-3xl border border-dashed border-slate-300 bg-white px-4 py-14 text-center shadow-sm">
          <div class="rounded-full bg-slate-100 p-3">
            <.icon name="hero-bookmark" class="h-6 w-6 text-slate-400" />
          </div>
          <h3 class="mt-4 text-sm font-semibold text-slate-900">No highlights yet</h3>
          <p class="mt-2 max-w-xs text-xs leading-5 text-slate-500">
            Select text to save it here.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
