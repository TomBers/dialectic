defmodule DialecticWeb.NodeComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils

  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"node-menu-" <> @node_id}
        class="flex flex-col relative"
        phx-hook="TextSelectionHook"
        data-node-id={@node.id}
        style="max-height: 100vh; display: flex; flex-direction: column; padding-bottom: env(safe-area-inset-bottom);"
      >
        <%= if @node.id == "start" do %>
          <.live_component module={DialecticWeb.StartTutorialComp} id="start-tutorial" />
        <% else %>
          <%= if String.length(@node.content) > 0 do %>
            <div
              class="flex-grow overflow-auto scroll-smooth pt-2 pb-10 px-3 sm:px-4 md:px-6"
              id={"tt-node-" <> @node.id}
            >
              <div class="summary-content modal-responsive" id={"tt-summary-content-" <> @node.id}>
                <div id={"node-content-#{@node.id}"} phx-update="replace">
                  <div id={"node-content-inner-#{@node.id}-#{:erlang.phash2(@node.content || "")}"}>
                    <article class="prose prose-stone prose-lg md:prose-xl max-w-none w-full prose-headings:mt-0 prose-p:leading-relaxed prose-li:leading-relaxed">
                      <% rendered = TextUtils.render_content(@node.content || "") %>
                      <h3 class="mt-0 text-md mb-2 sm:mb-3 pb-2 border-b border-gray-200">
                        {rendered |> Map.get(:title)}
                      </h3>
                      <div
                        class="selection-content w-full min-w-full text-base p-2"
                        phx-hook="ListDetection"
                        data-children={length(@node.children)}
                        id={"list-detector-" <> @node.id}
                      >
                        {rendered |> Map.get(:body_html)}
                      </div>
                    </article>
                  </div>
                </div>
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
            <div class="node mb-2 p-4">
              <div class="flex flex-col space-y-4 animate-pulse">
                <div class="h-6 bg-gray-200 rounded-md w-3/4"></div>
                <div class="space-y-2">
                  <div class="h-4 bg-gray-200 rounded-md w-full"></div>
                  <div class="h-4 bg-gray-200 rounded-md w-5/6"></div>
                  <div class="h-4 bg-gray-200 rounded-md w-4/6"></div>
                </div>
                <div class="flex items-center space-x-2 mt-2">
                  <div class="h-8 w-8 bg-gray-200 rounded-full"></div>
                  <div class="h-3 bg-gray-200 rounded-md w-24"></div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
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
       graph_owner_id: Map.get(assigns, :graph_owner_id, nil),
       current_user: Map.get(assigns, :current_user, nil),
       menu_visible: Map.get(assigns, :menu_visible, true)
     )}
  end
end
