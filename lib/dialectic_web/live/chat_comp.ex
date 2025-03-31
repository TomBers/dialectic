defmodule DialecticWeb.ChatComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.ChatMsgComp
  alias DialecticWeb.NoteMenuComp

  def update(assigns, socket) do
    parents =
      GraphManager.path_to_node(assigns.graph_id, assigns.node)

    {:ok, socket |> assign(assigns) |> assign(parents: parents)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] max-h-[80%]">
      <%= if length(@parents) > 0 do %>
        <.live_component
          module={NoteMenuComp}
          node={@node}
          user={@user}
          show_action_btns={true}
          id={"note-menu-" <> @node.id}
        />
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
      <div class="bg-white shadow-lg border-t border-gray-200 p-2">
        <div class="flex items-center">
          <label for="auto-reply-toggle" class="flex items-center cursor-pointer">
            <div class="relative">
              <input
                type="checkbox"
                id="auto-reply-toggle"
                class="sr-only"
                checked={@auto_reply}
                name="auto_reply"
                phx-click="toggle_auto_reply"
              />
              <div class={"w-10 h-6 rounded-full transition #{if @auto_reply, do: "bg-green-500", else: "bg-gray-300"}"}>
              </div>
              <div class={"absolute left-1 top-1 w-4 h-4 rounded-full transition transform #{if @auto_reply, do: "translate-x-4 bg-white", else: "bg-white"}"}>
              </div>
            </div>
            <span class="ml-3 text-sm font-medium text-gray-900">
              {if @auto_reply, do: "Auto-reply on", else: "Auto-reply off"}
            </span>
          </label>
          <.icon
            name="hero-information-circle"
            class="ml-2 h-5 w-5 text-gray-500"
            tooltip="When enabled, the system will automatically respond to incoming questions.  When disabled, just your comment will be added."
          />
        </div>
        <%= if @auto_reply do %>
          <.form for={@form} phx-submit="reply-and-answer" id={"chat-reply-answer-form-" <> @node.id}>
            <div class="flex-1">
              <.input
                :if={@node.id != "NewNode"}
                field={@form[:content]}
                tabindex="0"
                type="text"
                id={"chat--reply-answer-input-" <> @node.id}
                placeholder="Ask question"
              />
            </div>
          </.form>
        <% else %>
          <.form for={@form} phx-submit="answer" id={"chat-comp-form-" <> @node.id}>
            <div class="flex-1">
              <.input
                :if={@node.id != "NewNode"}
                field={@form[:content]}
                tabindex="0"
                type="text"
                id={"chat-comp-input-" <> @node.id}
                placeholder="Add comment"
              />
            </div>
          </.form>
        <% end %>
      </div>
    </div>
    """
  end
end
