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
    <div class={"node mb-2 " <> @node.class}>
      <h2>{@node.id}</h2>

      <div class="proposition">
        <!-- If expanded, show full content; otherwise show truncated. -->
        <%= if @expanded do %>
          {full_html(@node.content || "")}
        <% else %>
          {truncated_html(@node.content || "", @cut_off)}
        <% end %>
        
    <!-- Only render the toggle link if content is longer than the cutoff. -->
        <%= if String.length(@node.content || "") > @cut_off do %>
          <span>
            <a href="#" phx-click="toggle-expand" phx-target={@myself} class="text-blue-600 text-sm">
              {if @expanded, do: "Show less", else: "Show more"}
            </a>
          </span>
        <% end %>
      </div>
    </div>
    """
  end
end
