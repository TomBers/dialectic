defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.NoteMenuComp

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-2">
        <button
          class="text-gray-400 hover:text-gray-600 transition-colors p-1"
          title="Copy shareable link"
          onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node.id}")}').then(() => alert('Link copied to clipboard!'))"}
        >
          <svg
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
          </svg>
        </button>
        <span
          class="text-xs text-gray-400 font-mono select-all cursor-pointer ml-1"
          title="Shareable URL path"
        >
          /{@graph_id}?node={@node.id}
        </span>
      </div>

      <.live_component
        module={NoteMenuComp}
        graph_id={@graph_id}
        node={@node}
        user={@user}
        id={"note-menu-" <> @node.id}
      />

      <div class="mx-auto w-3/4">
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
      </div>

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
          phx-click={
            JS.push("reply-and-answer", value: %{vertex: %{content: "Give Examples"}, prefix: ""})
          }
          title="Generate examples for this topic."
          id={"examples-button-" <> @node_id}
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
                d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"
              />
            </svg>
          </span>
          <span class="label">Examples</span>
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
      </div>
    </div>
    """
  end

  def handle_event("reply_mode", _, socket) do
    {:noreply, assign(socket, ask_question: !socket.assigns.ask_question)}
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
