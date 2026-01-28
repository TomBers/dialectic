defmodule DialecticWeb.HighlightsPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Highlights

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:editing_highlight_id, fn -> nil end)}
  end

  @impl true
  def handle_event("delete_highlight", %{"id" => id}, socket) do
    case Highlights.get_highlight(id) do
      nil ->
        {:noreply, socket}

      highlight ->
        if highlight.created_by_user_id == socket.assigns.current_user.id do
          Highlights.delete_highlight(highlight)
        end

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_highlight", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_highlight_id: id)}
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  @impl true
  def handle_event("save_note", %{"highlight_id" => id, "note" => note}, socket) do
    case Highlights.get_highlight(id) do
      nil ->
        {:noreply, socket}

      highlight ->
        if highlight.created_by_user_id == socket.assigns.current_user.id do
          Highlights.update_highlight(highlight, %{note: note})
        end

        {:noreply, assign(socket, editing_highlight_id: nil)}
    end
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 pb-4">
      <%= if length(@highlights) > 0 do %>
        <%= for highlight <- @highlights do %>
          <div class="bg-white border border-gray-200 rounded-lg shadow-sm p-4 hover:border-indigo-300 transition-colors group">
            <%= if @editing_highlight_id == highlight.id do %>
              <form phx-submit="save_note" phx-target={@myself} class="flex flex-col gap-3">
                <input type="hidden" name="highlight_id" value={highlight.id} />
                <div class="space-y-1">
                  <label class="text-xs font-semibold text-gray-700">Note</label>
                  <textarea
                    name="note"
                    class="w-full text-sm border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500 min-h-[5rem]"
                    rows="3"
                    placeholder="Add a note..."
                    autofocus
                  ><%= highlight.note %></textarea>
                </div>
                <div class="flex justify-end gap-2">
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    phx-target={@myself}
                    class="px-3 py-1.5 text-sm font-medium text-gray-600 bg-gray-100 rounded-md hover:bg-gray-200"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-3 py-1.5 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
                  >
                    Save Note
                  </button>
                </div>
              </form>
            <% else %>
              <div class="flex flex-col gap-3">
                <div
                  class="cursor-pointer"
                  phx-click="highlight_clicked"
                  phx-value-id={highlight.id}
                  phx-value-node-id={highlight.node_id}
                  title="Go to highlight"
                >
                  <div class="text-sm text-gray-800 border-l-2 border-indigo-400 pl-3 py-0.5 italic hover:text-indigo-700 transition-colors break-words">
                    "{highlight.selected_text_snapshot}"
                  </div>
                </div>

                <%= if highlight.note && highlight.note != "" do %>
                  <div class="text-xs text-gray-600 bg-gray-50 p-2 rounded break-words">
                    {highlight.note}
                  </div>
                <% end %>

                <div class="flex items-end justify-between pt-2 border-t border-gray-100 mt-1">
                  <div class="flex flex-col gap-1.5 flex-1 min-w-0">
                    <%= if has_links?(highlight) do %>
                      <div class="flex flex-wrap gap-1.5">
                        <%= for link <- highlight.links do %>
                          <button
                            type="button"
                            phx-click="navigate_to_node"
                            phx-value-node_id={link.node_id}
                            title={"Navigate to " <> link_type_label(link.link_type)}
                            class="flex items-center gap-1 px-1.5 py-0.5 rounded bg-gray-50 border border-gray-200 hover:bg-indigo-50 hover:border-indigo-200 transition-colors max-w-full"
                          >
                            <.icon
                              name={link_type_icon(link.link_type)}
                              class={"w-3.5 h-3.5 flex-shrink-0 " <> link_type_color(link.link_type)}
                            />
                            <span class="text-[10px] text-gray-600 font-medium truncate max-w-[80px]">
                              Node {String.slice(link.node_id, 0, 6)}...
                            </span>
                          </button>
                        <% end %>
                      </div>
                    <% else %>
                      <div class="text-[10px] font-semibold text-gray-400 uppercase tracking-wider">
                        Node {String.slice(highlight.node_id, 0, 6)}
                      </div>
                    <% end %>
                  </div>

                  <div class="flex items-center gap-1 ml-2 flex-shrink-0">
                    <button
                      type="button"
                      data-copy-url={
                        DialecticWeb.Endpoint.url() <>
                          "/g/" <>
                          @graph_struct.slug <>
                          "?highlight=" <> to_string(highlight.id)
                      }
                      onclick="navigator.clipboard.writeText(this.dataset.copyUrl).then(() => {
                        const el = this.querySelector('.copy-feedback');
                        el.classList.remove('hidden');
                        setTimeout(() => el.classList.add('hidden'), 2000);
                      })"
                      class="relative p-1.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-md transition-colors"
                      title="Copy link"
                    >
                      <.icon name="hero-link" class="w-4 h-4" />
                      <span class="copy-feedback hidden absolute bottom-full left-1/2 -translate-x-1/2 mb-1 bg-gray-800 text-white text-[10px] py-1 px-2 rounded whitespace-nowrap z-10">
                        Copied!
                      </span>
                    </button>

                    <%= if @current_user && @current_user.id == highlight.created_by_user_id do %>
                      <button
                        type="button"
                        phx-click="edit_highlight"
                        phx-target={@myself}
                        phx-value-id={highlight.id}
                        class="p-1.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-md transition-colors"
                        title="Edit note"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </button>

                      <button
                        type="button"
                        phx-click="delete_highlight"
                        phx-target={@myself}
                        phx-value-id={highlight.id}
                        data-confirm="Are you sure you want to delete this highlight?"
                        class="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors"
                        title="Delete highlight"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <div class="flex flex-col items-center justify-center py-12 px-4 text-center">
          <div class="bg-gray-100 p-3 rounded-full mb-3">
            <.icon name="hero-bookmark" class="w-6 h-6 text-gray-400" />
          </div>
          <h3 class="text-sm font-semibold text-gray-900 mb-1">No highlights yet</h3>
          <p class="text-xs text-gray-500">
            Select any text in a node to create a highlight, add notes, or link ideas.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
