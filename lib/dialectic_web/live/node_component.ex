defmodule DialecticWeb.NodeComponent do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    tabs = %{
      "Answer" => ~H"""
      <div>
        <.form for={@form} phx-submit="answer">
          <div>
            <.input field={@form[:answer]} type="textarea" label="Name" />
          </div>

          <div>
            <.button type="submit">Answer</.button>
          </div>
        </.form>
      </div>
      """,
      "Branch" => ~H"""
      <div>
        <.form for={@form} phx-submit="branch">
          <div>
            <.button type="submit">Branch</.button>
          </div>
        </.form>
      </div>
      """,
      "Combine" => ~H"""
      <div>
        <.form for={@form} phx-submit="combine">
          <div>
            <.input
              type="select"
              name="combine_node"
              label="Nodes"
              options={Enum.map(@vertices, &{&1, &1})}
              value={@selected_vertex}
            />
          </div>

          <div>
            <.button type="submit">Combine</.button>
          </div>
        </.form>
      </div>
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
      <p>
        Parent:
        <%= for parent <- @node.parents do %>
          <a href="#" class="text-blue-600" phx-click="node_clicked" phx-value-id={parent.id}>
            {parent.id}
          </a>
          |
        <% end %>
      </p>

      <div class="w-full text-gray-300 bg-gray-800 rounded-lg p-4">
        {raw(@node.proposition)}
      </div>
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
      <p>
        Children:
        <%= for child <- assigns.node.children do %>
          <a href="#" class="text-blue-600 px-2" phx-click="node_clicked" phx-value-id={child.id}>
            {child.id}
          </a>
        <% end %>
      </p>
    </div>
    """
  end
end
