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
  defp link_type_icon("clarify"), do: "hero-light-bulb"
  defp link_type_icon("assumptions"), do: "hero-cube-transparent"
  defp link_type_icon("counterexample"), do: "hero-x-mark"
  defp link_type_icon("implications"), do: "hero-arrow-trending-up"
  defp link_type_icon("blind_spots"), do: "hero-eye-slash"
  defp link_type_icon("says_who"), do: "hero-user"
  defp link_type_icon("who_disagrees"), do: "hero-users"
  defp link_type_icon("steel_man"), do: "hero-star"
  defp link_type_icon("what_if"), do: "hero-question-mark-circle"
  defp link_type_icon(_), do: "hero-link"

  defp link_type_color("explain"), do: "text-gray-500"
  defp link_type_color("question"), do: "text-sky-500"
  defp link_type_color("pro"), do: "text-emerald-500"
  defp link_type_color("con"), do: "text-red-500"
  defp link_type_color("related_idea"), do: "text-orange-500"
  defp link_type_color("clarify"), do: "text-teal-500"
  defp link_type_color("assumptions"), do: "text-amber-500"
  defp link_type_color("counterexample"), do: "text-red-500"
  defp link_type_color("implications"), do: "text-indigo-500"
  defp link_type_color("blind_spots"), do: "text-purple-500"
  defp link_type_color("says_who"), do: "text-sky-500"
  defp link_type_color("who_disagrees"), do: "text-rose-500"
  defp link_type_color("steel_man"), do: "text-yellow-500"
  defp link_type_color("what_if"), do: "text-fuchsia-500"
  defp link_type_color(_), do: "text-gray-500"

  defp link_type_label("explain"), do: "Explanation"
  defp link_type_label("question"), do: "Question"
  defp link_type_label("pro"), do: "Pro Argument"
  defp link_type_label("con"), do: "Con Argument"
  defp link_type_label("related_idea"), do: "Related Idea"
  defp link_type_label("clarify"), do: "Clarify Terms"
  defp link_type_label("assumptions"), do: "Assumptions"
  defp link_type_label("counterexample"), do: "Counterexample"
  defp link_type_label("implications"), do: "Implications"
  defp link_type_label("blind_spots"), do: "Blind Spots"
  defp link_type_label("says_who"), do: "Source Check"
  defp link_type_label("who_disagrees"), do: "Who Disagrees"
  defp link_type_label("steel_man"), do: "Steel Man"
  defp link_type_label("what_if"), do: "What If"
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
            Map.put_new(
              acc,
              node_id,
              NodeTitleHelper.extract_node_title(node, max_length: :infinity)
            )
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
    <div class="flex flex-col gap-4 pb-6">
      <%= if length(@highlights) > 0 do %>
        <%= for highlight <- @highlights do %>
          <div
            id={"highlight-card-#{highlight.id}"}
            class="group overflow-hidden rounded-[1.4rem] border border-slate-200 bg-white shadow-[0_14px_32px_-26px_rgba(15,23,42,0.4)] transition duration-200 hover:border-slate-300 hover:shadow-[0_18px_38px_-26px_rgba(15,23,42,0.48)]"
          >
            <%= if @editing_highlight_id == highlight.id do %>
              <.form
                for={%{}}
                id={"highlight-note-form-#{highlight.id}"}
                phx-submit="save_note"
                phx-target={@myself}
                class="flex flex-col gap-4 p-4"
              >
                <input type="hidden" name="highlight_id" value={highlight.id} />
                <div class="space-y-1">
                  <label
                    for={"highlight-note-#{highlight.id}"}
                    class="text-xs font-semibold text-slate-700"
                  >
                    Note
                  </label>
                  <textarea
                    id={"highlight-note-#{highlight.id}"}
                    name="note"
                    class="min-h-[7rem] w-full rounded-xl border border-slate-300 bg-slate-50 px-3 py-2.5 text-sm text-slate-900 shadow-inner placeholder:text-slate-400 focus:border-teal-600 focus:outline-none focus:ring-2 focus:ring-teal-100"
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
                    class="inline-flex items-center justify-center rounded-full border border-slate-200 bg-white px-3.5 py-2 text-xs font-semibold text-slate-600 transition hover:bg-slate-50 hover:text-slate-900"
                  >
                    Cancel
                  </button>
                  <button
                    id={"highlight-note-save-#{highlight.id}"}
                    type="submit"
                    class="inline-flex items-center justify-center rounded-full bg-slate-950 px-3.5 py-2 text-xs font-semibold text-white shadow-sm transition hover:bg-slate-800"
                  >
                    Save Note
                  </button>
                </div>
              </.form>
            <% else %>
              <div class="flex flex-col">
                <button
                  id={"highlight-jump-#{highlight.id}"}
                  type="button"
                  class="relative m-2.5 rounded-2xl bg-white px-4 py-4 text-left ring-1 ring-inset ring-slate-200 transition hover:bg-slate-50 hover:ring-amber-300"
                  phx-click="highlight_clicked"
                  phx-value-id={highlight.id}
                  phx-value-node-id={highlight.node_id}
                  title="Go to highlight"
                >
                  <blockquote class="border-l-2 border-amber-400 pl-3.5 font-serif text-[15px] italic leading-7 text-slate-900 break-words sm:text-base">
                    “{highlight.selected_text_snapshot}”
                  </blockquote>
                  <div class="mt-3 flex items-start gap-2 pl-3.5">
                    <.icon
                      name="hero-document-text"
                      class="mt-0.5 h-3.5 w-3.5 shrink-0 text-slate-400"
                    />
                    <p class="min-w-0 text-[11px] font-medium leading-4 text-slate-500 break-words">
                      {node_title(@node_titles, highlight.node_id)}
                    </p>
                    <%= if visible_in_view?(highlight, @visible_node_ids) do %>
                      <span
                        class="mt-1 inline-flex h-2.5 w-2.5 shrink-0 rounded-full bg-emerald-500 ring-2 ring-emerald-100"
                        title="Visible in the current view"
                        aria-label="In view"
                      ></span>
                    <% end %>
                  </div>
                </button>

                <%= if note_present?(highlight) do %>
                  <div class="mx-3 mt-0 rounded-xl bg-amber-50/70 p-3 text-xs leading-5 text-slate-700 ring-1 ring-inset ring-amber-200/70 break-words">
                    <div class="mb-1.5 flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-[0.16em] text-amber-700">
                      <.icon name="hero-chat-bubble-left-ellipsis" class="h-3.5 w-3.5" /> Your note
                    </div>
                    <p>{highlight.note}</p>
                  </div>
                <% end %>

                <div class="flex flex-col gap-3 px-3 pb-3 pt-2.5">
                  <%= if has_links?(highlight) do %>
                    <div class="rounded-xl border border-indigo-100 bg-indigo-50/50 p-1">
                      <p class="px-2 pb-1 pt-1.5 text-[9px] font-semibold uppercase tracking-[0.16em] text-indigo-700">
                        Connected ideas
                      </p>
                      <div class="flex flex-wrap gap-2">
                        <%= for link <- highlight.links do %>
                          <button
                            id={"highlight-link-#{highlight.id}-#{link.node_id}"}
                            type="button"
                            phx-click="navigate_to_node"
                            phx-value-node_id={link.node_id}
                            title={"Navigate to " <> link_type_label(link.link_type)}
                            class="inline-flex max-w-full items-start gap-1.5 rounded-lg border border-indigo-200 bg-white px-2.5 py-1.5 text-left transition hover:border-indigo-300 hover:bg-indigo-100"
                          >
                            <.icon
                              name={link_type_icon(link.link_type)}
                              class={"mt-0.5 h-3.5 w-3.5 shrink-0 " <> link_type_color(link.link_type)}
                            />
                            <span class="min-w-0 whitespace-normal break-words text-[10px] font-medium leading-4 text-slate-600">
                              {node_title(@node_titles, link.node_id)}
                            </span>
                          </button>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <div class="flex items-center justify-end gap-1.5 border-t border-slate-100 pt-2.5">
                    <button
                      id={"highlight-share-#{highlight.id}"}
                      type="button"
                      phx-click="open_share_modal"
                      phx-value-highlight_id={highlight.id}
                      class="inline-flex items-center gap-1 rounded-full px-2.5 py-1.5 text-[11px] font-semibold text-slate-500 transition hover:bg-slate-100 hover:text-slate-900"
                      title="Share quote"
                    >
                      <.icon name="hero-share" class="h-3.5 w-3.5" />
                      <span>Share</span>
                    </button>

                    <%= if @current_user && @current_user.id == highlight.created_by_user_id do %>
                      <button
                        id={"highlight-note-edit-#{highlight.id}"}
                        type="button"
                        phx-click="edit_highlight"
                        phx-target={@myself}
                        phx-value-id={highlight.id}
                        class="inline-flex items-center gap-1 rounded-full px-2.5 py-1.5 text-[11px] font-semibold text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
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
                        class="inline-flex items-center gap-1 rounded-full px-2.5 py-1.5 text-[11px] font-semibold text-slate-400 transition hover:bg-red-50 hover:text-red-700"
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
        <div class="flex flex-col items-center justify-center rounded-[1.5rem] border border-dashed border-slate-300 bg-white px-5 py-14 text-center shadow-[0_14px_32px_-28px_rgba(15,23,42,0.4)]">
          <div class="rounded-2xl bg-teal-50 p-3 text-teal-700 ring-1 ring-inset ring-teal-200/70">
            <.icon name="hero-bookmark" class="h-6 w-6" />
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
