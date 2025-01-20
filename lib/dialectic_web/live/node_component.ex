defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    tabs = %{
      "Answer" => ~H"""
      <div>Content for Answer</div>
      """,
      "Branch" => ~H"""
      <div>Content for Branch</div>
      """,
      "Combine" => ~H"""
      <div>Content for Combine</div>
      """
    }

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:tabs, tabs)
     |> assign(:active_tab, "Answer")}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="node">
      <p><strong>ID:</strong> {@node.id}</p>
      <p>
        Parent:
        <%= if Map.has_key?(@node.parent, :id) do %>
          <a href="#" class="text-blue-600" phx-click="node_clicked" phx-value-id={@node.parent.id}>
            {@node.parent.id}
          </a>
        <% else %>
          None
        <% end %>
      </p>
      <p>
        Children:
        <%= for child <- assigns.node.children do %>
          <a href="#" class="text-blue-600 px-2" phx-click="node_clicked" phx-value-id={child.id}>
            {child.id}
          </a>
        <% end %>
      </p>
      <nav class="flex -mb-px" role="tablist">
        <%= for tab <- Map.keys(@tabs) do %>
          <button
            phx-click="change_tab"
            phx-value-tab={tab}
            phx-target={@myself}
            type="button"
            class={[
              "py-2 px-4 border-b-2 font-medium text-sm",
              @active_tab == tab && "border-blue-500 text-blue-600",
              @active_tab != tab &&
                "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
            ]}
          >
            {tab}
          </button>
        <% end %>
      </nav>
      <div class="mt-4">
        {Map.get(@tabs, @active_tab)}
      </div>
      <.form for={@form} phx-submit="save">
        <div>
          <.input field={@form[:description]} type="textarea" label="Name" />
        </div>

        <div>
          <.button type="submit">Save</.button>
        </div>
      </.form>
      <br />
      <btn
        phx-click="generate_thesis"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Generate Theis
      </btn>
    </div>
    """
  end
end
