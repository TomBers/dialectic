defmodule DialecticWeb.NodeComp do
  alias DialecticWeb.NodeMenuComp
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils
  alias DialecticWeb.ColUtils

  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"node-menu-" <> @node_id}
        class="flex flex-col relative"
        phx-hook="TextSelectionHook"
        data-node-id={@node.id}
        style="max-height: 100vh; display: flex; flex-direction: column;"
      >
        <%= if String.length(@node.content) > 0 do %>
          <div
            class={[
              "flex-grow overflow-auto pb-4 pt-4"
            ]}
            id={"tt-node-" <> @node.id}
            style={
              if @menu_visible,
                do: "max-height: calc(50vh - 100px);",
                else: "max-height: calc(100vh - 100px);"
            }
          >
            <div class="summary-content" id={"tt-summary-content-" <> @node.id}>
              <article class={[
                "prose prose-stone prose-xl max-w-none selection-content pl-2 border-l-4 w-full",
                ColUtils.message_border_class(@node.class)
              ]}>
                <h3>
                  {TextUtils.modal_title(@node.content, @node.class || "")}
                </h3>
                <div
                  class="w-full min-w-full"
                  phx-hook="ListDetection"
                  data-children={length(@node.children)}
                  id={"list-detector-" <> @node.id}
                >
                  {TextUtils.full_html(@node.content || "")}
                </div>
              </article>
              <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
                <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded">
                  Ask about selection
                </button>
              </div>
            </div>
          </div>
        <% else %>
          <div class="node mb-2">
            <h2>Loading ...</h2>
          </div>
        <% end %>
      </div>
      <div class="flex justify-center mb-2">
        <button
          phx-click="toggle_menu"
          phx-target={@myself}
          class="bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-1 px-4 rounded inline-flex items-center"
        >
          <span>{if @menu_visible, do: "Hide Menu", else: "Show Menu"}</span>
          <svg
            class="ml-2 h-4 w-4"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <%= if @menu_visible do %>
              <path
                fill-rule="evenodd"
                d="M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z"
                clip-rule="evenodd"
              />
            <% else %>
              <path
                fill-rule="evenodd"
                d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                clip-rule="evenodd"
              />
            <% end %>
          </svg>
        </button>
      </div>
      <div
        class={["nodeMenuComp sticky bottom-0 bg-white w-full z-10", if(!@menu_visible, do: "hidden")]}
        style="transition: height 0.3s ease-in-out;"
      >
        <.live_component
          module={NodeMenuComp}
          id="node-menu-comp"
          node={@node}
          user={@user}
          form={@form}
          graph_id={@graph_id}
          ask_question={@ask_question}
        />
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    node = Map.get(assigns, :node, %{})
    node_id = Map.get(node, :id)

    {:ok,
     assign(socket,
       node_id: node_id,
       node: node,
       user: Map.get(assigns, :user, nil),
       form: Map.get(assigns, :form, nil),
       cut_off: Map.get(assigns, :cut_off, 500),
       ask_question: Map.get(assigns, :ask_question, true),
       graph_id: Map.get(assigns, :graph_id, ""),
       menu_visible: true
     )}
  end

  def handle_event("toggle_menu", _, socket) do
    {:noreply, assign(socket, menu_visible: !socket.assigns.menu_visible)}
  end
end
