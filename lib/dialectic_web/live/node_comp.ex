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
        phx-target={@myself}
      >
        <%= if String.length(@node.content) > 0 do %>
          <div
            class={[
              "flex-grow overflow-auto pb-4 pt-4"
            ]}
            id={"tt-node-" <> @node.id}
            style="max-height: calc(100vh - 320px);"
          >
            <div class="summary-content" id={"tt-summary-content-" <> @node.id}>
              <article class={[
                "prose prose-stone prose-md max-w-none selection-content pl-2 border-l-4 w-full",
                ColUtils.message_border_class(@node.class)
              ]}>
                <h3>
                  {TextUtils.modal_title(@node.content, @node.class || "")}
                </h3>
                <div 
                  class="w-full min-w-full"
                  phx-hook="ListDetection"
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
              
              <!-- List Branching Button -->
              <%= if @has_lists do %>
                <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                  <div class="flex items-center justify-between">
                    <div>
                      <h4 class="text-sm font-medium text-blue-900">List Detected</h4>
                      <p class="text-xs text-blue-700">Found <%= @list_item_count %> list items that can be branched into separate nodes</p>
                    </div>
                    <button
                      class="bg-blue-600 hover:bg-blue-700 text-white text-sm px-3 py-2 rounded-md transition-colors"
                      phx-click="branch_list_items"
                      phx-value-node-id={@node.id}
                      title="Create a new node for each list item"
                    >
                      <div class="flex items-center gap-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"></path>
                        </svg>
                        Branch List
                      </div>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="node mb-2">
            <h2>Loading ...</h2>
          </div>
        <% end %>
      </div>
      <div class="nodeMenuComp sticky bottom-0 bg-white w-full z-10">
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

  def handle_event("lists_detected", %{"items" => items, "count" => count}, socket) do
    {:noreply, 
     socket
     |> assign(:has_lists, true)
     |> assign(:list_items, items)
     |> assign(:list_item_count, count)}
  end

  def handle_event("branch_list_items", %{"node-id" => node_id}, socket) do
    # Send the list items to the parent LiveView to handle node creation
    send(self(), {:branch_list_items, socket.assigns.list_items, node_id})
    {:noreply, socket}
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
       has_lists: false,
       list_items: [],
       list_item_count: 0
     )}
  end
end
