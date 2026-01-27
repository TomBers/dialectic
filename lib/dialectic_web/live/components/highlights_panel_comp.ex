defmodule DialecticWeb.HighlightsPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Contexts.Highlights

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
          Highlights.update_highlight_note(highlight, note)
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

  defp link_type_color("explain"), do: "text-amber-500"
  defp link_type_color("question"), do: "text-blue-500"
  defp link_type_color("pro"), do: "text-green-500"
  defp link_type_color("con"), do: "text-red-500"
  defp link_type_color("related_idea"), do: "text-purple-500"
  defp link_type_color("deep_dive"), do: "text-indigo-500"
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
    <div class="bg-white border border-gray-200 rounded-md">
      <div class="px-2 py-1 text-[11px] font-semibold text-gray-700 flex justify-between items-center">
        <span>Highlights ({length(@highlights)})</span>
        <button
          type="button"
          phx-click="toggle_highlights_panel"
          class="text-gray-400 hover:text-gray-600 sm:hidden"
        >
          <.icon name="hero-x-mark" class="w-4 h-4" />
        </button>
      </div>
      <div class="p-1 text-[11px] text-gray-700 space-y-1">
        <div class="max-h-[calc(100vh-12rem)] overflow-y-auto">
          <%= if length(@highlights) > 0 do %>
            <ul class="space-y-1">
              <%= for highlight <- @highlights do %>
                <li class="group p-1 bg-gray-50 hover:bg-gray-100 rounded text-xs relative">
                  <%= if @editing_highlight_id == highlight.id do %>
                    <form phx-submit="save_note" phx-target={@myself} class="flex flex-col gap-2 p-1">
                      <input type="hidden" name="highlight_id" value={highlight.id} />
                      <textarea
                        name="note"
                        class="w-full text-xs border-gray-300 rounded focus:ring-indigo-500 focus:border-indigo-500"
                        rows="3"
                        placeholder="Add a note..."
                      ><%= highlight.note %></textarea>
                      <div class="flex justify-end gap-2">
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          phx-target={@myself}
                          class="text-gray-500 hover:text-gray-700"
                        >
                          Cancel
                        </button>
                        <button
                          type="submit"
                          class="bg-indigo-600 text-white px-2 py-1 rounded hover:bg-indigo-700"
                        >
                          Save
                        </button>
                      </div>
                    </form>
                  <% else %>
                    <div
                      class="flex flex-col gap-1 cursor-pointer"
                      phx-click="highlight_clicked"
                      phx-value-id={highlight.id}
                      phx-value-node-id={highlight.node_id}
                    >
                      <div class="font-medium text-gray-600 truncate pr-12">
                        "{highlight.selected_text_snapshot}"
                      </div>
                      <%= if highlight.note && highlight.note != "" do %>
                        <div class="text-gray-500 italic truncate">
                          {highlight.note}
                        </div>
                      <% end %>
                      <div class="flex items-center gap-2 text-[10px] text-gray-400">
                        <span>Node: {highlight.node_id}</span>
                        <%= if has_links?(highlight) do %>
                          <span class="text-gray-300">•</span>
                          <div class="flex items-center gap-1">
                            <%= for link <- highlight.links do %>
                              <button
                                type="button"
                                phx-click="node_clicked"
                                phx-value-id={link.node_id}
                                title={"Navigate to " <> link_type_label(link.link_type) <> ": " <> link.node_id}
                                class="hover:scale-125 hover:opacity-80 transition-all cursor-pointer rounded-sm"
                              >
                                <.icon
                                  name={link_type_icon(link.link_type)}
                                  class={"w-4 h-4 " <> link_type_color(link.link_type)}
                                />
                              </button>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                    <div class="absolute top-1 right-1 hidden group-hover:flex gap-1 bg-white/80 rounded">
                      <button
                        type="button"
                        data-copy-url={
                          DialecticWeb.Endpoint.url() <>
                            "/g/" <>
                            @graph_struct.slug <>
                            "?highlight=" <> to_string(highlight.id)
                        }
                        onclick="navigator.clipboard.writeText(this.dataset.copyUrl).then(() => alert('Link copied to clipboard!'))"
                        class="text-gray-400 hover:text-indigo-500 p-0.5 rounded"
                        title="Copy link to highlight"
                      >
                        <.icon name="hero-link" class="w-3 h-3" />
                      </button>
                      <%= if @current_user && @current_user.id == highlight.created_by_user_id do %>
                        <button
                          phx-click="edit_highlight"
                          phx-target={@myself}
                          phx-value-id={highlight.id}
                          class="text-gray-400 hover:text-indigo-500 p-0.5 rounded"
                          title="Edit note"
                        >
                          <.icon name="hero-pencil" class="w-3 h-3" />
                        </button>
                        <button
                          phx-click="delete_highlight"
                          phx-target={@myself}
                          phx-value-id={highlight.id}
                          class="text-gray-400 hover:text-red-500 p-0.5 rounded"
                          title="Delete highlight"
                        >
                          <.icon name="hero-trash" class="w-3 h-3" />
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% else %>
            <p class="text-gray-400 italic px-1">No highlights yet.</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
