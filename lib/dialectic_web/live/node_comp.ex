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
                    <%= if @node.id == "1" do %>
                      <div class="mb-6 rounded-xl bg-gradient-to-br from-indigo-50 via-white to-amber-50 border border-indigo-100 p-5 shadow-sm">
                        <h4 class="font-bold text-gray-900 text-sm uppercase tracking-wider mb-3 flex items-center gap-2">
                          <span class="text-lg">👋</span> Welcome to RationalGrid
                        </h4>
                        <p class="text-sm text-gray-700 mb-3">
                          You're looking at the <strong>origin node</strong>
                          of this grid — the starting point for exploring an idea. Unlike traditional chat, RationalGrid turns every response into a
                          <strong>node</strong>
                          in a visual knowledge map that you can branch, connect, and explore in any direction.
                        </p>
                        <p class="text-sm text-gray-600 mb-4">
                          <strong>How it works:</strong>
                          Read this node, then use the <strong>Grid Tools</strong>
                          below to expand the conversation. You can also type a follow-up question in the input box, or click any node on the graph (right side) to focus it.
                        </p>

                        <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2 pt-3 border-t border-gray-200">
                          <span class="text-base">🛠️</span> Grid Tools
                        </h5>
                        <p class="text-xs text-gray-500 mb-3">
                          These tools help you grow your grid in different ways:
                        </p>
                        <ul class="space-y-3 text-sm text-gray-700">
                          <li class="flex gap-3 items-start">
                            <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-gradient-to-r from-emerald-500 to-rose-500 text-white">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-3.5 w-3.5"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                                />
                              </svg>
                            </span>
                            <span>
                              <strong class="text-gray-900">Pro | Con</strong>
                              — Generates two child nodes: one arguing <em>for</em>
                              the current idea and one arguing <em>against</em>. Great for exploring both sides of any claim.
                            </span>
                          </li>
                          <li class="flex gap-3 items-start">
                            <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-violet-500 text-white">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-3.5 w-3.5"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0 0 12 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.988 5.988 0 0 1-2.031.352 5.988 5.988 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L18.75 4.971Zm-16.5.52c.99-.203 1.99-.377 3-.52m0 0 2.62 10.726c.122.499-.106 1.028-.589 1.202a5.989 5.989 0 0 1-2.031.352 5.989 5.989 0 0 1-2.031-.352c-.483-.174-.711-.703-.59-1.202L5.25 4.971Z"
                                />
                              </svg>
                            </span>
                            <span>
                              <strong class="text-gray-900">Blend</strong>
                              — Select two nodes to synthesize into one. The AI finds common ground, contrasts, or creates a unified perspective from both ideas.
                            </span>
                          </li>
                          <li class="flex gap-3 items-start">
                            <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-orange-500 text-white">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-3.5 w-3.5"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                                />
                              </svg>
                            </span>
                            <span>
                              <strong class="text-gray-900">Related</strong>
                              — Spawns new nodes with related concepts, questions, or angles you might not have considered. Expands your thinking in unexpected directions.
                            </span>
                          </li>
                          <li class="flex gap-3 items-start">
                            <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-gradient-to-r from-fuchsia-500 via-rose-500 to-amber-500 text-white">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-3.5 w-3.5"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                                />
                              </svg>
                            </span>
                            <span>
                              <strong class="text-gray-900">Explore</strong>
                              — Takes every bullet point or key idea in the current node and creates a child node for each, letting you dive deep on multiple fronts at once.
                            </span>
                          </li>
                          <li class="flex gap-3 items-start">
                            <span class="flex-none w-6 h-6 flex items-center justify-center rounded-md bg-red-500/80 text-white">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-3.5 w-3.5"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6M9 7h6m-7 0a1 1 0 01-1-1V5a1 1 0 011-1h2a2 2 0 012-2h0a2 2 0 012 2h2a1 1 0 011 1v1" />
                              </svg>
                            </span>
                            <span>
                              <strong class="text-gray-900">Delete</strong>
                              — Removes a node you created (only works on leaf nodes with no children).
                            </span>
                          </li>
                        </ul>
                        <div class="mt-4 pt-3 border-t border-gray-200">
                          <h5 class="font-bold text-gray-900 text-xs uppercase tracking-wider mb-3 flex items-center gap-2">
                            <span class="text-base">✨</span> Pro Tip: Select Text for Precision
                          </h5>
                          <p class="text-xs text-gray-600 mb-3">
                            Want to dive deeper into a specific phrase or concept? Simply
                            <strong>select any text</strong>
                            in a node and a menu appears with options to explore just that selection:
                          </p>
                          <%!-- Visual demonstration of text selection --%>
                          <div class="rounded-lg bg-white border border-gray-200 p-3 mb-3 shadow-inner">
                            <p class="text-sm text-gray-700 leading-relaxed">
                              The theory of
                              <span class="bg-blue-200 text-blue-900 px-0.5 rounded">
                                cognitive dissonance
                              </span>
                              suggests that people experience discomfort when holding conflicting beliefs...
                            </p>
                            <%!-- Mock selection tooltip --%>
                            <div class="mt-2 inline-flex items-center gap-1 bg-gray-800 text-white text-xs rounded-lg px-2 py-1.5 shadow-lg">
                              <button
                                type="button"
                                class="flex items-center gap-1 px-2 py-0.5 rounded hover:bg-gray-700 transition"
                              >
                                <svg
                                  xmlns="http://www.w3.org/2000/svg"
                                  class="h-3 w-3"
                                  fill="none"
                                  viewBox="0 0 24 24"
                                  stroke="currentColor"
                                  stroke-width="2"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M8.625 12a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H8.25m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0H12m4.125 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 0 1-2.555-.337A5.972 5.972 0 0 1 5.41 20.97a5.969 5.969 0 0 1-.474-.065 4.48 4.48 0 0 0 .978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25Z"
                                  />
                                </svg>
                                Ask
                              </button>
                              <span class="text-gray-500">|</span>
                              <button
                                type="button"
                                class="flex items-center gap-1 px-2 py-0.5 rounded hover:bg-gray-700 transition"
                              >
                                <svg
                                  xmlns="http://www.w3.org/2000/svg"
                                  class="h-3 w-3"
                                  fill="none"
                                  viewBox="0 0 24 24"
                                  stroke="currentColor"
                                  stroke-width="2"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z"
                                  />
                                </svg>
                                Pro/Con
                              </button>
                              <span class="text-gray-500">|</span>
                              <button
                                type="button"
                                class="flex items-center gap-1 px-2 py-0.5 rounded hover:bg-gray-700 transition"
                              >
                                <svg
                                  xmlns="http://www.w3.org/2000/svg"
                                  class="h-3 w-3"
                                  fill="none"
                                  viewBox="0 0 24 24"
                                  stroke="currentColor"
                                  stroke-width="2"
                                >
                                  <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                                  />
                                </svg>
                                Related
                              </button>
                            </div>
                          </div>
                          <p class="text-xs text-gray-500">
                            This lets you get <strong>precise, focused answers</strong>
                            about specific terms, claims, or ideas without losing context from the original node.
                          </p>
                        </div>

                        <div class="mt-4 pt-3 border-t border-gray-200 space-y-2">
                          <p class="text-xs text-gray-500">
                            💡 <strong>Quick Tips:</strong>
                          </p>
                          <ul class="text-xs text-gray-500 space-y-1 pl-4 list-disc">
                            <li>
                              <strong>Navigate:</strong>
                              Drag to pan, scroll to zoom. Click any node on the graph to focus it.
                            </li>
                            <li>
                              <strong>Star nodes</strong>
                              you want to revisit — find them later in your profile.
                            </li>
                            <li>
                              <strong>Share your grid</strong>
                              with others — they can explore and add their own thoughts.
                            </li>
                          </ul>
                        </div>
                      </div>
                    <% end %>
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
