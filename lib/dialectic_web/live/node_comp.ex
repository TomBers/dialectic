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
       exploration_stats: Map.get(assigns, :exploration_stats, nil),
       presentation_mode: Map.get(assigns, :presentation_mode, :off)
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
          <%!-- Thread View (Ancestor Chain) — hidden for now, revisit when full breadcrumb is implemented --%>

          <div
            class={"flex-grow overflow-auto scroll-smooth pt-3 pb-12 px-3 sm:px-5 lg:px-6 " <> if(String.length(@node.content) == 0, do: "hidden", else: "")}
            id={"tt-node-" <> @node.id}
          >
            <div
              class="summary-content modal-responsive mx-auto w-full max-w-3xl"
              id={"tt-summary-content-" <> @node.id}
            >
              <div id={"node-content-#{@node.id}"}>
                <div id={"node-content-inner-#{@node.id}"}>
                  <article
                    class="prose prose-stone prose-base sm:prose-lg lg:prose-xl max-w-none w-full prose-headings:mt-0 prose-headings:tracking-tight prose-headings:text-gray-900 prose-p:text-gray-800 prose-li:text-gray-800 prose-p:leading-relaxed prose-li:leading-relaxed"
                    data-role="node-content"
                  >
                    <%!-- Client-side Markdown rendering via Markdown hook --%>
                    <h3 class="mt-0 text-lg sm:text-xl md:text-[1.65rem] mb-3 pb-3 border-b border-gray-200/90 flex items-start justify-between gap-4 leading-tight tracking-tight text-gray-900">
                      <span
                        class="flex-1"
                        phx-hook="Markdown"
                        id={"markdown-title-#{@node.id}"}
                        data-md={@node.content || ""}
                        data-title-only="true"
                      >
                      </span>
                      <span class="flex items-center gap-2">
                        <% noted? =
                          Enum.any?(Map.get(@node || %{}, :noted_by, []), fn u -> u == @user end) %>
                        <button
                          type="button"
                          class={[
                            "flex-none inline-flex items-center justify-center p-1.5 rounded-full transition-all",
                            if(noted?,
                              do: "bg-yellow-400 text-gray-900 hover:bg-yellow-500",
                              else:
                                "bg-gray-100 text-gray-600 hover:bg-yellow-400 hover:text-gray-900"
                            )
                          ]}
                          phx-click={if noted?, do: "unnote", else: "note"}
                          phx-value-node={@node.id}
                          title={if noted?, do: "Remove from your notes", else: "Add to your notes"}
                        >
                          <%= if noted? do %>
                            <svg
                              xmlns="http://www.w3.org/2000/svg"
                              class="h-4 w-4"
                              viewBox="0 0 24 24"
                              fill="currentColor"
                            >
                              <path
                                fill-rule="evenodd"
                                d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z"
                                clip-rule="evenodd"
                              />
                            </svg>
                          <% else %>
                            <svg
                              xmlns="http://www.w3.org/2000/svg"
                              class="h-4 w-4"
                              fill="none"
                              viewBox="0 0 24 24"
                              stroke="currentColor"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                              />
                            </svg>
                          <% end %>
                        </button>
                        <%= if @exploration_stats do %>
                          <span class="flex-none text-xs font-medium text-gray-500 bg-gray-100 rounded-full px-2 py-1 whitespace-nowrap mt-1">
                            {@exploration_stats["explored"]} / {@exploration_stats["total"]} explored
                          </span>
                        <% end %>
                      </span>
                    </h3>
                    <div
                      class="selection-content w-full px-1 sm:px-2 pb-4"
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
