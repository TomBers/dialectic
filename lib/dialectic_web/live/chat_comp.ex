defmodule DialecticWeb.ChatComp do
  use DialecticWeb, :live_component

  alias DialecticWeb.ChatMsgComp

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex-1 overflow-y-auto">
        <%= for parent <- @node.parents do %>
          <.live_component
            module={ChatMsgComp}
            node={parent}
            user={@user}
            show_user_controls={false}
            id={parent.id <>"_chatMsg" }
          />
        <% end %>
        <%= if @node.content != "" do %>
          <.live_component
            module={ChatMsgComp}
            node={@node}
            user={@user}
            show_user_controls={true}
            id={@node.id <>"_chatMsg" }
          />
        <% else %>
          <div class="node mb-2">
            <h2>Loading ...</h2>
          </div>
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
          >
          </.icon>
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
