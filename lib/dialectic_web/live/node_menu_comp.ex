defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.NoteMenuComp

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      
    <!-- Question & Comment Section -->
      <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3">
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

        <div class="relative">
          <div class="flex rounded-t-md border border-b-0 border-gray-300 overflow-hidden">
            <button
              type="button"
              class={"flex-1 py-2.5 px-3 transition-colors font-medium text-sm " <> if @ask_question, do: "bg-white text-blue-600 border-b-2 border-blue-500", else: "text-gray-600 bg-gray-50 hover:bg-gray-100"}
              phx-click="toggle_ask_question"
              phx-value-id={@node_id}
              id={"tab-question-" <> @node_id}
              data-type="answer"
              style=""
            >
              <div class="flex items-center justify-center gap-1.5">
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
                  <path d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 0 1-.825-.242m9.345-8.334a2.126 2.126 0 0 0-.476-.095 48.64 48.64 0 0 0-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0 0 11.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />
                </svg>
                <span>Ask a Question</span>
              </div>
            </button>
            <button
              type="button"
              class={"flex-1 py-2.5 px-3 transition-colors font-medium text-sm " <> if !@ask_question, do: "bg-white text-emerald-600 border-b-2 border-emerald-500", else: "text-gray-600 bg-gray-50 hover:bg-gray-100"}
              phx-click="toggle_ask_question"
              phx-value-id={@node_id}
              id={"tab-comment-" <> @node_id}
              data-type="thesis"
              style=""
            >
              <div class="flex items-center justify-center gap-1.5">
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
              class="bg-white border border-gray-300 rounded-b-md p-3"
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
              class="bg-white border border-gray-300 rounded-b-md p-3"
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
        <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3 mt-4">
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
          <div class="flex items-center justify-between gap-2 mb-2">
            <span
              class="flex-1 truncate text-xs text-gray-600 bg-gray-50 border border-gray-200 rounded px-2 py-1 font-mono select-all cursor-pointer"
              title="Shareable URL path"
              onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node.id}")}').then(() => alert('Link copied to clipboard!'))"}
            >
              /{@graph_id}?node={@node.id}
            </span>
            <button
              class="inline-flex items-center gap-1 text-gray-600 hover:text-gray-800 transition-colors p-1.5 border border-gray-300 rounded"
              title="Copy shareable link"
              onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node.id}")}').then(() => alert('Link copied to clipboard!'))"}
            >
              <svg
                width="14"
                height="14"
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
              <span class="sr-only">Copy link</span>
            </button>
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
