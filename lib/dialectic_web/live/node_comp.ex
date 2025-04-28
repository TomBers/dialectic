defmodule DialecticWeb.NodeComp do
  alias DialecticWeb.NodeMenuComp
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils
  alias DialecticWeb.ColUtils

  def render(assigns) do
    ~H"""
    <div
      id={"node-menu-" <> @node_id}
      class="flex flex-col relative"
      phx-hook="TextSelectionHook"
      style="max-height: 100vh; display: flex; flex-direction: column;"
    >
      <%= if String.length(@node.content) > 0 do %>
        <div
          class={[
            "flex-grow overflow-auto pb-4"
          ]}
          id={"tt-node-" <> @node.id}
          style="max-height: calc(100vh - 250px);"
        >
          <div class="summary-content" id={"tt-summary-content-" <> @node.id} data-node-id={@node.id}>
            <article class={[
              "prose prose-stone prose-xl max-w-none selection-content pl-2 border-l-4 w-full",
              ColUtils.message_border_class(@node.class)
            ]}>
              <h3>
                {TextUtils.modal_title(@node.content, @node.class || "")}
              </h3>
              <div class="w-full min-w-full">
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
       graph_id: Map.get(assigns, :graph_id, "")
     )}
  end
end
