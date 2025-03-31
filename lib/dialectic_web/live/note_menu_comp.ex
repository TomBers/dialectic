defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="prose prose-stone prose-sm tiny-text">
      <%= if @node.class == "user"  do %>
        By:{@node.user}
      <% else %>
        Generated
      <% end %>
      | {length(@node.noted_by)} ⭐ |
      <%= if Enum.any?(@node.noted_by, fn u -> u == @user end) do %>
        <button
          phx-click="unnote"
          phx-value-node={@node.id}
          tabindex="-1"
          class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
        >
          Unnote
        </button>
      <% else %>
        <button
          phx-click="note"
          phx-value-node={@node.id}
          tabindex="-1"
          class="text-green-600 hover:text-green-800 font-medium focus:outline-none"
        >
          Note
        </button>
      <% end %>
      |
      <.link navigate={"?node=" <> @node.id} tabindex="-1" class="text-blue-600 hover:text-blue-400">
        Link
      </.link>
      |
      <button
        phx-click="delete"
        data-confirm="Are you sure?"
        phx-value-node={@node.id}
        tabindex="-1"
        class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
      >
        Delete
      </button>
      |
      <button
        phx-click="edit"
        phx-confirm="Are you sure?"
        phx-value-node={@node.id}
        tabindex="-1"
        class="text-red-600 hover:text-red-800 font-medium focus:outline-none"
      >
        Edit
      </button>
    </div>
    """
  end
end
