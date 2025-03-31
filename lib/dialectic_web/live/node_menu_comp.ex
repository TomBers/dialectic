defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils
  alias DialecticWeb.ColUtils
  alias DialecticWeb.NoteMenuComp

  def render(assigns) do
    ~H"""
    <div
      id={"node-menu-" <> @node_id}
      class="graph-tooltip overflow-auto"
      style={get_styles(@visible, @position)}
      data-position={Jason.encode!(@position)}
      phx-hook="NodeMenuHook"
    >
      <%= if String.length(@node.content) > 0 do %>
        <div
          class={[
            "p-2 rounded-lg shadow-sm",
            "flex items-start gap-3 bg-white border-4",
            ColUtils.message_border_class(@node.class)
          ]}
          id={"tt-node-" <> @node.id}
        >
          <div
            class="summary-content"
            id={"tt-summary-content-" <> @node.id}
            phx-hook="TextSelectionHook"
            data-node-id={@node.id}
          >
            <article class="prose prose-stone prose-sm selection-content">
              {TextUtils.truncated_html(@node.content || "", @cut_off)}
            </article>
            <div class="selection-actions hidden absolute bg-white shadow-md rounded-md p-1 z-10">
              <button class="bg-blue-500 hover:bg-blue-600 text-white text-xs py-1 px-2 rounded">
                Ask about selection
              </button>
            </div>

            <div class="flex justify-end">
              <button
                phx-click={show_modal("modal-#{@node.id}")}
                class="mt-2 text-blue-600 hover:text-blue-800 p-1.5 rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-300"
                aria-label="Open in modal"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="feather feather-maximize-2"
                >
                  <polyline points="15 3 21 3 21 9"></polyline>
                  <polyline points="9 21 3 21 3 15"></polyline>
                  <line x1="21" y1="3" x2="14" y2="10"></line>
                  <line x1="3" y1="21" x2="10" y2="14"></line>
                </svg>
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <div class="node mb-2">
          <h2>Loading ...</h2>
        </div>
      <% end %>
      <.live_component module={NoteMenuComp} node={@node} user={@user} id={"note-menu-" <> @node.id} />
      <%= if @ask_question do %>
        <.form for={@form} phx-submit="reply-and-answer" id={"tt-reply-form-" <> @node.id}>
          <div class="flex-1 mb-4">
            <.input
              :if={@node_id != "NewNode"}
              field={@form[:content]}
              tabindex="0"
              type="text"
              id={"tt-input-" <> @node.id}
              placeholder="Ask question"
            />
          </div>
        </.form>
      <% else %>
        <.form for={@form} phx-submit="answer" id={"tt-form-" <> @node.id}>
          <div class="flex-1 mb-4">
            <.input
              :if={@node_id != "NewNode"}
              field={@form[:content]}
              tabindex="0"
              type="text"
              id={"tt-input-" <> @node.id}
              placeholder="Add comment"
            />
          </div>
        </.form>
      <% end %>

      <div class="menu-buttons">
        <button
          class="menu-button"
          title="Ask a question about this topic.  You will get a response to your question."
          phx-click="reply_mode"
          phx-value-id={@node_id}
          id={"reply-button-" <> @node_id}
          phx-target={@myself}
        >
          <span class="icon">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke={if @ask_question, do: "blue", else: "currentColor"}
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 0 1-.825-.242m9.345-8.334a2.126 2.126 0 0 0-.476-.095 48.64 48.64 0 0 0-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0 0 11.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
              />
            </svg>
          </span>
          <span class={if @ask_question, do: "label text-blue-400", else: "label"}>Ask Question</span>
        </button>

        <button
          class="menu-button"
          phx-click="reply_mode"
          title="Add a comment about this topic. You will not get an answer"
          phx-value-id={@node_id}
          id={"comment-button-" <> @node_id}
          phx-target={@myself}
        >
          <span class="icon">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke={if !@ask_question, do: "blue", else: "currentColor"}
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M2.25 12.76c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 0 1 1.037-.443 48.282 48.282 0 0 0 5.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z"
              />
            </svg>
          </span>
          <span class={if !@ask_question, do: "label text-blue-400", else: "label"}>Add Comment</span>
        </button>

        <button
          class="menu-button"
          phx-click="node_branch"
          title="Generate arguments for and against the above point."
          phx-value-id={@node_id}
          id={"branch-button-" <> @node_id}
        >
          <span class="icon">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
              />
            </svg>
          </span>
          <span class="label">Pros and Cons</span>
        </button>

        <button
          class="menu-button"
          phx-click="node_combine"
          title="Combine this with another point; trying to find a compromise between the two."
          phx-value-id={@node_id}
          id={"combine-button-" <> @node_id}
        >
          <span class="icon">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
              />
            </svg>
          </span>
          <span class="label">Combine</span>
        </button>
        <.link navigate={~p"/#{@graph_id}/linear##{@node_id}"}>
          <button class="menu-button" title="Read as text" id={"text-button-" <> @node_id}>
            <span class="icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <line x1="8" y1="6" x2="21" y2="6"></line>
                <line x1="8" y1="12" x2="21" y2="12"></line>
                <line x1="8" y1="18" x2="21" y2="18"></line>
                <line x1="3" y1="6" x2="3.01" y2="6"></line>
                <line x1="3" y1="12" x2="3.01" y2="12"></line>
                <line x1="3" y1="18" x2="3.01" y2="18"></line>
              </svg>
            </span>
            <span class="label">Read as text</span>
          </button>
        </.link>
      </div>
    </div>
    """
  end

  defp get_styles(visible, position) do
    base_styles = """
    position: fixed;
    z-index: 10;
    background-color: white;
    border-radius: 4px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
    padding: 5px;
    transition: opacity 0.2s;
    max-width: 400px;
    max-height: 80vh;
    """

    visibility = if visible, do: "display: block;", else: "display: none;"

    position_style =
      case position do
        %{x: x, y: y} when is_number(x) and is_number(y) ->
          # Get estimated dimensions
          estimated_width = position[:estimated_width] || position["estimated_width"] || 300
          estimated_height = position[:estimated_height] || position["estimated_height"] || 300

          # Get viewport dimensions from JS or use sensible defaults
          viewport_width = position[:viewport_width] || position["viewport_width"] || 1920
          viewport_height = position[:viewport_height] || position["viewport_height"] || 1080

          # Calculate initial position (centered on node)
          node_width = position[:width] || position["width"] || 0
          initial_x = x - node_width / 2
          initial_y = y

          # Adjust if the tooltip would go off-screen
          adjusted_x =
            cond do
              initial_x + estimated_width > viewport_width ->
                viewport_width - estimated_width - 20

              initial_x < 20 ->
                20

              true ->
                initial_x
            end

          adjusted_y =
            cond do
              initial_y + estimated_height > viewport_height ->
                viewport_height - estimated_height - 20

              initial_y < 20 ->
                20

              true ->
                initial_y
            end

          "left: #{adjusted_x}px; top: #{adjusted_y}px;"

        _ ->
          "left: 50%; top: 50%; transform: translate(-50%, -50%);"
      end

    base_styles <> visibility <> position_style
  end

  def handle_event("reply_mode", _, socket) do
    {:noreply, assign(socket, ask_question: !socket.assigns.ask_question)}
  end

  def update(assigns, socket) do
    node = Map.get(assigns, :node, %{})
    node_id = Map.get(node, :id)

    {:ok,
     assign(socket,
       visible: Map.get(assigns, :visible, false),
       position: Map.get(assigns, :position, %{x: 0, y: 0}),
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
