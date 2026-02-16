defmodule DialecticWeb.NodeComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Utils.NodeTitleHelper

  @impl true
  def update(assigns, socket) do
    base_node =
      case Map.get(assigns, :node) do
        %{} = n -> n
        _ -> %{}
      end

    # Normalize required fields so template can use @node.id/content/children/parents directly
    node =
      base_node
      |> Map.put_new(:id, "")
      |> Map.put_new(:content, "")
      |> Map.put_new(:children, [])
      |> Map.put_new(:parents, [])

    node_id = Map.get(node, :id, "")

    # Check if we should show the thread view (default open if there are parents)
    # has_parents = length(Map.get(node, :parents, [])) > 0
    show_thread = Map.get(assigns, :show_thread, false)

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
       menu_visible: Map.get(assigns, :menu_visible, true),
       streaming: Map.get(assigns, :streaming, false),
       exploration_stats: Map.get(assigns, :exploration_stats, nil),
       show_thread: show_thread
     )}
  end

  @impl true
  def handle_event("toggle_thread", _params, socket) do
    {:noreply, assign(socket, show_thread: !socket.assigns.show_thread)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"node-menu-" <> @node_id}
        class="flex flex-col relative"
        phx-hook="TextSelectionHook"
        data-node-id={@node.id}
        data-mudg-id={@graph_id}
        data-streaming={to_string(@streaming)}
        style="max-height: 100vh; display: flex; flex-direction: column; padding-bottom: env(safe-area-inset-bottom);"
      >
        <%= if @node.id == "start" do %>
          <.live_component module={DialecticWeb.StartTutorialComp} id="start-tutorial" />
        <% else %>
          <%!-- Search hint bar --%>
          <button
            type="button"
            phx-click="open_search_overlay_click"
            id="search-hint-bar"
            class="flex items-center gap-2 w-full px-3 sm:px-4 py-2 bg-gray-50 border-b border-gray-200 text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors cursor-pointer group"
          >
            <.icon name="hero-magnifying-glass" class="w-4 h-4 shrink-0" />
            <span class="text-xs">Search topics...</span>
            <kbd class="ml-auto hidden sm:inline-flex items-center gap-0.5 px-1.5 py-0.5 text-[10px] font-medium text-gray-400 group-hover:text-gray-500 bg-white rounded border border-gray-200">
              <span class="text-[11px]">⌘</span>K
            </kbd>
          </button>

          <%!-- Thread View (Ancestor Chain) --%>
          <%= if length(@node.parents || []) > 0 do %>
            <div class="border-b border-gray-200 bg-gray-50 px-3 sm:px-4 py-2">
              <button
                type="button"
                phx-click="toggle_thread"
                phx-target={@myself}
                class="flex items-center gap-2 text-sm font-medium text-gray-700 hover:text-gray-900 w-full"
              >
                <svg
                  class={"w-4 h-4 transition-transform " <> if(@show_thread, do: "rotate-90", else: "")}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
                <span>
                  Thread ({length(@node.parents || [])} ancestor{if length(@node.parents || []) != 1,
                    do: "s",
                    else: ""})
                </span>
              </button>

              <%= if @show_thread do %>
                <div class="mt-3 space-y-2">
                  <%= for {parent, index} <- Enum.with_index(@node.parents || []) do %>
                    <div class="bg-white rounded-lg border border-gray-200 p-2 hover:border-indigo-300 transition-colors">
                      <div class="flex items-start gap-2">
                        <div class="flex-none text-xs font-mono text-gray-500 pt-0.5">
                          {index + 1}.
                        </div>
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2 mb-1">
                            <span class={"inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium " <> DialecticWeb.ColUtils.badge_class(parent.class || "")}>
                              {DialecticWeb.ColUtils.node_type_label(parent.class || "")}
                            </span>
                          </div>
                          <div class="text-sm font-medium text-gray-900 mb-1">
                            {NodeTitleHelper.extract_node_title(parent)}
                          </div>
                          <button
                            type="button"
                            phx-click="navigate_to_node"
                            phx-value-node_id={parent.id}
                            class="text-xs text-indigo-600 hover:text-indigo-800 hover:underline"
                          >
                            View this node →
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <div
            class={"flex-grow overflow-auto scroll-smooth pt-2 pb-10 px-3 sm:px-4 " <> if(String.length(@node.content) == 0, do: "hidden", else: "")}
            id={"tt-node-" <> @node.id}
          >
            <div class="summary-content modal-responsive" id={"tt-summary-content-" <> @node.id}>
              <div id={"node-content-#{@node.id}"}>
                <div id={"node-content-inner-#{@node.id}"}>
                  <article
                    class="prose prose-stone prose-lg md:prose-xl max-w-none w-full prose-headings:mt-0 prose-p:leading-relaxed prose-li:leading-relaxed"
                    data-role="node-content"
                  >
                    <%!-- Client-side Markdown rendering via Markdown hook --%>
                    <h3 class="mt-0 text-lg sm:text-xl md:text-2xl mb-2 sm:mb-3 pb-2 border-b border-gray-200 flex items-start justify-between gap-4">
                      <span
                        class="flex-1"
                        phx-hook="Markdown"
                        id={"markdown-title-#{@node.id}"}
                        data-md={@node.content || ""}
                        data-title-only="true"
                      >
                      </span>
                      <%= if @exploration_stats do %>
                        <span class="flex-none text-xs font-medium text-gray-500 bg-gray-100 rounded-full px-2 py-1 whitespace-nowrap mt-1">
                          {@exploration_stats["explored"]} / {@exploration_stats["total"]} explored
                        </span>
                      <% end %>
                    </h3>
                    <div
                      class="selection-content w-full min-w-full text-base sm:text-lg p-2"
                      data-children={length(@node.children)}
                      id={"list-detector-" <> @node.id}
                    >
                      <div
                        phx-hook="Markdown"
                        id={"markdown-body-#{@node.id}"}
                        data-md={@node.content || ""}
                        data-body-only="true"
                      >
                      </div>
                    </div>
                  </article>
                </div>
              </div>
            </div>
          </div>

          <%= if String.length(@node.content) == 0 do %>
            <div class="node mb-2 p-4 relative">
              <div class="flex flex-col space-y-4 animate-pulse opacity-40">
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
              <div class="absolute inset-0 flex items-center justify-center z-10">
                <button
                  phx-click="node_regenerate"
                  phx-value-id={@node.id}
                  phx-disable-with="Regenerating..."
                  disabled={@streaming}
                  class="bg-white shadow-sm border border-gray-300 px-3 py-1.5 rounded-full text-xs font-medium text-gray-700 hover:bg-gray-50 hover:text-indigo-600 flex items-center gap-1.5 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  title="Regenerate response"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                    class="w-3.5 h-3.5"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.992 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"
                    />
                  </svg>
                  {if @streaming, do: "Generating...", else: "Regenerate"}
                </button>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
