defmodule DialecticWeb.NodeComp do
  use DialecticWeb, :live_component

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
       exploration_stats: Map.get(assigns, :exploration_stats, nil)
     )}
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
            aria-label="Open search overlay"
            class="flex items-center gap-2 w-full px-3 sm:px-4 py-2 bg-gray-50 border-b border-gray-200 text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-colors cursor-pointer group"
          >
            <.icon name="hero-magnifying-glass" class="w-4 h-4 shrink-0" />
            <span class="text-xs">Search topics...</span>
            <kbd class="ml-auto hidden sm:inline-flex items-center gap-0.5 px-1.5 py-0.5 text-[10px] font-medium text-gray-400 group-hover:text-gray-500 bg-white rounded border border-gray-200">
              <span class="text-[11px]">⌘</span>K
            </kbd>
          </button>

          <%!-- Thread View (Ancestor Chain) — hidden for now, revisit when full breadcrumb is implemented --%>

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
            <div class="node mb-2 p-6 sm:p-8">
              <%!-- Animated shimmer skeleton lines --%>
              <div class="space-y-4">
                <div class="h-5 rounded-md w-3/4 bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_infinite]">
                </div>
                <div class="space-y-2.5">
                  <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.1s_infinite]">
                  </div>
                  <div class="h-3.5 rounded-md w-5/6 bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.2s_infinite]">
                  </div>
                  <div class="h-3.5 rounded-md w-4/6 bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.3s_infinite]">
                  </div>
                </div>
                <div class="space-y-2.5 pt-2">
                  <div class="h-3.5 rounded-md w-full bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.4s_infinite]">
                  </div>
                  <div class="h-3.5 rounded-md w-2/3 bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-[length:200%_100%] animate-[shimmer_1.5s_ease-in-out_0.5s_infinite]">
                  </div>
                </div>
              </div>
              <%!-- Typing indicator dots --%>
              <div class="flex items-center gap-1.5 pt-6">
                <span class="text-xs text-gray-400 font-medium">Thinking</span>
                <span class="flex gap-0.5">
                  <span class="w-1 h-1 rounded-full bg-indigo-400 animate-[typing_1.4s_ease-in-out_infinite]">
                  </span>
                  <span class="w-1 h-1 rounded-full bg-indigo-400 animate-[typing_1.4s_ease-in-out_-0.16s_infinite]">
                  </span>
                  <span class="w-1 h-1 rounded-full bg-indigo-400 animate-[typing_1.4s_ease-in-out_-0.32s_infinite]">
                  </span>
                </span>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
