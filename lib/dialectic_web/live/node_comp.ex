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
                do: "max-height: calc(55vh - 100px); transition: max-height 0.3s ease-in-out;",
                else: "max-height: calc(100vh - 50px); transition: max-height 0.3s ease-in-out;"
            }
          >
            <div
              class="summary-content modal-responsive px-2 sm:px-4 md:px-6"
              id={"tt-summary-content-" <> @node.id}
            >
              <article class={[
                "prose prose-stone prose-lg md:prose-xl max-w-none selection-content pl-2 border-l-4 w-full",
                ColUtils.message_border_class(@node.class)
              ]}>
                <h3 class="text-lg sm:text-xl md:text-2xl mb-2 sm:mb-3">
                  {TextUtils.modal_title(@node.content, @node.class || "")}
                </h3>
                <div
                  class="w-full min-w-full text-base sm:text-lg"
                  phx-hook="ListDetection"
                  data-children={length(@node.children)}
                  id={"list-detector-" <> @node.id}
                >
                  {TextUtils.full_html(@node.content || "")}
                </div>
              </article>
              <div class="selection-actions hidden absolute bg-white shadow-lg rounded-lg p-1 sm:p-2 z-10 border border-gray-200">
                <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 sm:py-1.5 px-2 sm:px-3 rounded-full flex items-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-3 w-3 mr-0.5 sm:mr-1"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
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
          phx-click="toggle_node_menu"
          class="bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-1 px-4 rounded inline-flex items-center"
        >
          <span>{if @menu_visible, do: "Hide Menu", else: "Show Menu"}</span>
          <svg
            class={"ml-2 h-4 w-4 transition-transform duration-300 #{if @menu_visible, do: "rotate-0", else: "rotate-180"}"}
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>
      <div
        class="nodeMenuComp sticky bottom-0 bg-white w-full z-10 overflow-hidden shadow-sm"
        style={"max-height: #{if @menu_visible, do: "1000px", else: "0"}; opacity: #{if @menu_visible, do: "1", else: "0"}; transition: max-height 0.3s ease-in-out, opacity 0.2s ease-in-out;"}
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
       menu_visible: Map.get(assigns, :menu_visible, true)
     )}
  end
end
