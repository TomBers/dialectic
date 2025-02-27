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
            <h2>Waiting ...</h2>
          </div>
        <% end %>
      </div>
      <div class="bg-white shadow-lg border-t border-gray-200 p-2">
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
      </div>
    </div>
    """
  end
end
