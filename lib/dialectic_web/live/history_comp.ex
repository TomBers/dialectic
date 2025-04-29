defmodule DialecticWeb.HistoryComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.ChatMsgComp

  def update(assigns, socket) do
    parents =
      GraphManager.path_to_node(assigns.graph_id, assigns.node)

    {:ok, socket |> assign(assigns) |> assign(parents: parents)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] max-h-[80%]">
      <%= if length(@parents) > 0 do %>
        <h1 class="text-lg mb-4 flex items-center">
          <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 mr-2" /> Conversation Timeline
        </h1>
      <% else %>
        <div class="text-center py-6">
          <h2 class="text-2xl font-semibold mb-3">Welcome to MuDG!</h2>
          <p class="text-gray-600 mb-4">
            A place for collaborative knowledge exploration and meaningful conversations.
          </p>
          <p class="text-gray-600 mb-4">
            Share the URL to collaborate with others.
          </p>
          <p class="text-sm text-gray-500 italic">
            Start typing below / click a node to begin your conversation journey.
          </p>
        </div>
      <% end %>

      <div class="flex-1 overflow-y-auto">
        <%= for parent <- @parents do %>
          <.live_component
            module={ChatMsgComp}
            node={parent}
            user={@user}
            id={parent.id <>"_chatMsg" }
          />
        <% end %>
      </div>
    </div>
    """
  end
end
