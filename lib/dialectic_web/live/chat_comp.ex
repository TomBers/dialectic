defmodule DialecticWeb.ChatComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <div class="flex-1 overflow-y-auto">
        <%= for parent <- @node.parents do %>
          <div class={"node mb-2 " <> parent.class}>
            <h2>{parent.id}</h2>
            <div class="proposition">{raw(parent.content)}</div>
          </div>
        <% end %>
      </div>
      <div class="bg-white shadow-lg border-t border-gray-200 p-2">
        <.form for={@form} phx-submit="answer">
          <div class="flex-1">
            <.input field={@form[:content]} type="text" />
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
