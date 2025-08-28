defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.NoteMenuComp

  def render(assigns) do
    ~H"""
    <div class="space-y-3">
      
    <!-- Graph Actions Section -->
      <div class="border-b border-gray-200 pb-2">
        <h3 class="text-xs font-medium text-gray-600 mb-1 flex items-center">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 10V3L4 14h7v7l9-11h-7z"
            >
            </path>
          </svg>
          Actions <span class="text-xs font-normal ml-1 opacity-70">(click buttons below)</span>
        </h3>
        <div
          class="menu-buttons grid grid-cols-3 md:grid-cols-6 gap-2 action-grid"
          aria-label="Action buttons"
        >
          <button
            class="menu-button"
            phx-click={show_modal("modal-#{@node.id}")}
            title="Click to open in full screen reader mode"
            id={"reader-button-" <> @node_id}
            data-type="user"
            style="border-color: #d1d5db;"
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
                  d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15"
                />
              </svg>
            </span>
            <span class="label">Read</span>
          </button>
          <button
            class="menu-button"
            phx-click={
              JS.push("reply-and-answer",
                value: %{
                  vertex: %{
                    content:
                      "Can you go into more depth on this topic.  I would like a greater understanding and more specifc information. Return a longer response."
                  },
                  prefix: "details"
                }
              )
            }
            title="Click for more detailed information on this topic"
            id={"more-depth-button-" <> @node_id}
            data-type="details"
            style="border-color: #84cc16;"
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
                  d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342M6.75 15a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm0 0v-3.675A55.378 55.378 0 0 1 12 8.443m-7.007 11.55A5.981 5.981 0 0 0 6.75 15.75v-1.5"
                />
              </svg>
            </span>
            <span class="label">Details</span>
          </button>
          <button
            class="menu-button"
            phx-click={
              JS.push("reply-and-answer",
                value: %{vertex: %{content: "Give Examples"}, prefix: "examples"}
              )
            }
            title="Click to generate examples for this topic"
            id={"examples-button-" <> @node_id}
            data-type="examples"
            style="border-color: #f97316;"
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
                  d="M8.242 5.992h12m-12 6.003H20.24m-12 5.999h12M4.117 7.495v-3.75H2.99m1.125 3.75H2.99m1.125 0H5.24m-1.92 2.577a1.125 1.125 0 1 1 1.591 1.59l-1.83 1.83h2.16M2.99 15.745h1.125a1.125 1.125 0 0 1 0 2.25H3.74m0-.002h.375a1.125 1.125 0 0 1 0 2.25H2.99"
                />
              </svg>
            </span>
            <span class="label">Examples</span>
          </button>

          <button
            class="menu-button"
            phx-click={
              JS.push("reply-and-answer",
                value: %{
                  vertex: %{
                    content:
                      "Can you suggest ideas associated with this one or other people who have written about the topic."
                  },
                  prefix: "ideas"
                }
              )
            }
            title="Click to find related ideas and references"
            phx-value-id={@node_id}
            id={"associated-button-" <> @node_id}
            data-type="ideas"
            style="border-color: #0ea5e9;"
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
                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
            </span>
            <span class="label">Related</span>
          </button>

          <button
            class="menu-button"
            phx-click="node_branch"
            title="Click to generate pros and cons for this topic"
            phx-value-id={@node_id}
            id={"branch-button-" <> @node_id}
            data-type="antithesis"
            style="border-image: linear-gradient(to right, #10b981 50%, #ef4444 50%) 1; border-width: 1px; border-style: solid;"
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
            <span class="label">
              <span class="pros-text">Pros</span> / <span class="cons-text">Cons</span>
            </span>
          </button>

          <button
            class="menu-button"
            phx-click="node_combine"
            title="Click to combine this with another point and find a compromise"
            phx-value-id={@node_id}
            id={"combine-button-" <> @node_id}
            data-type="synthesis"
            style="border-color: #8b5cf6;"
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
      
    <!-- Question & Comment Section -->
      <div>
        <h3 class="text-xs font-medium text-gray-600 mb-2 flex items-center">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
            >
            </path>
          </svg>
          Ask a Question or Add a Comment
        </h3>

        <div class="mx-auto w-full mb-2 relative">
          <div class="flex rounded-t-md border border-b-0 border-gray-300 overflow-hidden">
            <button
              type="button"
              class={"flex-1 py-2 px-3 transition-colors font-medium text-sm " <> if @ask_question, do: "bg-white text-blue-600 border-b-2 border-blue-500", else: "text-gray-600 bg-gray-50 hover:bg-gray-100"}
              phx-click="toggle_ask_question"
              phx-value-id={@node_id}
              id={"tab-question-" <> @node_id}
              data-type="answer"
              style={if @ask_question, do: "border-color: #3b82f6;", else: ""}
            >
              <div class="flex items-center justify-center gap-1.5">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 0 1-.825-.242m9.345-8.334a2.126 2.126 0 0 0-.476-.095 48.64 48.64 0 0 0-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0 0 11.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />
                </svg>
                <span>Ask a Question</span>
              </div>
            </button>
            <button
              type="button"
              class={"flex-1 py-2 px-3 transition-colors font-medium text-sm " <> if !@ask_question, do: "bg-white text-blue-600 border-b-2 border-blue-500", else: "text-gray-600 bg-gray-50 hover:bg-gray-100"}
              phx-click="toggle_ask_question"
              phx-value-id={@node_id}
              id={"tab-comment-" <> @node_id}
              data-type="thesis"
              style={if !@ask_question, do: "border-color: #10b981;", else: ""}
            >
              <div class="flex items-center justify-center gap-1.5">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M2.25 12.76c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 0 1 1.037-.443 48.282 48.282 0 0 0 5.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0 0 12 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018Z" />
                </svg>
                <span>Add a Comment</span>
              </div>
            </button>
          </div>

          <%= if @ask_question do %>
            <.form
              for={@form}
              phx-submit="reply-and-answer"
              id={"tt-reply-form-" <> @node.id}
              class="bg-white border border-gray-300 rounded-b-md p-3 shadow-sm"
            >
              <div class="relative">
                <div class="absolute left-3 top-3 text-blue-500">
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
                    <circle cx="12" cy="12" r="10" />
                    <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
                    <path d="M12 17h.01" />
                  </svg>
                </div>
                <.input
                  :if={@node_id != "NewNode"}
                  field={@form[:content]}
                  tabindex="0"
                  type="text"
                  id={"tt-input-" <> @node.id}
                  placeholder="What would you like to know about this topic?"
                  class="pl-10 pr-16 py-2 rounded-md border-gray-300 w-full focus:border-blue-400 focus:ring focus:ring-blue-200 focus:ring-opacity-50"
                />
                <button
                  type="submit"
                  class="absolute right-2 top-2 bg-blue-500 hover:bg-blue-600 text-white rounded-md px-3 py-1 text-sm font-medium transition-colors"
                >
                  Ask →
                </button>
              </div>
            </.form>
          <% else %>
            <.form
              for={@form}
              phx-submit="answer"
              id={"tt-form-" <> @node.id}
              class="bg-white border border-gray-300 rounded-b-md p-3 shadow-sm"
            >
              <div class="relative">
                <div class="absolute left-3 top-3 text-gray-500">
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
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
                  </svg>
                </div>
                <.input
                  :if={@node_id != "NewNode"}
                  field={@form[:content]}
                  tabindex="0"
                  type="text"
                  id={"tt-input-" <> @node.id}
                  placeholder="Add your thoughts or notes about this content"
                  class="pl-10 pr-16 py-2 rounded-md border-gray-300 w-full focus:border-gray-400 focus:ring focus:ring-gray-200 focus:ring-opacity-50"
                />
                <button
                  type="submit"
                  class="absolute right-2 top-2 bg-gray-500 hover:bg-gray-600 text-white rounded-md px-3 py-1 text-sm font-medium transition-colors"
                >
                  Post
                </button>
              </div>
            </.form>
          <% end %>
        </div>
        
    <!-- Node Information Section -->
        <div class="border-b border-gray-200 pb-2">
          <h3 class="text-xs font-medium text-gray-600 mb-1 flex items-center">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
            Node Information
          </h3>
          <div class="flex items-center gap-2 mb-2">
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
              onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node.id}")}').then(() => alert('Link copied to clipboard!'))"}
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
        </div>
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
