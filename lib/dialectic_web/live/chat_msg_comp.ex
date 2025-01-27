defmodule DialecticWeb.ChatMsgComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      # Default `:expanded` to false if not explicitly set
      |> assign_new(:expanded, fn -> false end)
      # Default cutoff length
      |> assign_new(:cut_off, fn -> 200 end)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle-expand", _params, socket) do
    {:noreply, assign(socket, :expanded, not socket.assigns.expanded)}
  end

  defp truncated_html(content, cut_off) do
    # If content is already under the cutoff, just return the full text
    if String.length(content) <= cut_off do
      full_html(content)
    else
      truncated = String.slice(content, 0, cut_off) <> "..."
      Earmark.as_html!(truncated) |> Phoenix.HTML.raw()
    end
  end

  defp full_html(content) do
    Earmark.as_html!(content) |> Phoenix.HTML.raw()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "node mb-4 rounded-lg shadow-sm",
      "flex items-start gap-3",
      message_border_class(@node.class)
    ]}>
      <div class="shrink-0">
        <h2 class="w-8 h-8 flex items-center justify-center rounded-lg bg-gray-100 text-gray-700 font-mono text-sm">
          {@node.id}
        </h2>
      </div>

      <div class="proposition flex-1 max-w-none">
        <article class="prose prose-stone prose-sm">
          <%= if @expanded do %>
            {full_html(@node.content || "")}
          <% else %>
            {truncated_html(@node.content || "", @cut_off)}
          <% end %>
        </article>

        <%= if String.length(@node.content || "") > @cut_off do %>
          <button
            phx-click="toggle-expand"
            phx-target={@myself}
            class="mt-2 text-blue-600 hover:text-blue-800 text-sm font-medium focus:outline-none"
          >
            <%= if @expanded do %>
              Show less
            <% else %>
              Show more
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Add this helper function to handle message border styling
  defp message_border_class(class) do
    case class do
      "user" -> "border-l-4 border-red-400 bg-white"
      "answer" -> "border-l-4 border-green-400 bg-white"
      "thesis" -> "border-l-4 border-green-600 bg-white"
      "antithesis" -> "border-l-4 border-blue-600 bg-white"
      "synthesis" -> "border-l-4 border-purple-600 bg-white"
      _ -> "border border-gray-200 bg-white"
    end
  end
end
