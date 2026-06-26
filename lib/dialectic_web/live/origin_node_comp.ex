defmodule DialecticWeb.OriginNodeComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    base_node =
      case Map.get(assigns, :node) do
        %{} = node -> node
        _ -> %{}
      end

    node =
      base_node
      |> Map.put_new(:id, "")
      |> Map.put_new(:content, "")
      |> Map.put_new(:children, [])
      |> Map.put_new(:parents, [])
      |> Map.put_new(:noted_by, [])

    {:ok,
     assign(socket,
       node: node,
       user: Map.get(assigns, :user),
       exploration_stats: Map.get(assigns, :exploration_stats)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={"origin-node-menu-#{@node.id}"}
      class="relative flex h-full min-h-0 flex-col"
      data-node-id={@node.id}
      data-role="origin-node"
      style="height: 100%; padding-bottom: env(safe-area-inset-bottom);"
    >
      <div
        class="min-h-0 flex-1 overflow-y-auto scroll-smooth px-3 pb-12 pt-3 sm:px-5 lg:px-6"
        id={"tt-node-#{@node.id}"}
      >
        <div
          class="summary-content modal-responsive mx-auto w-full max-w-3xl"
          id={"tt-summary-content-#{@node.id}"}
        >
          <div id={"node-content-#{@node.id}"}>
            <div id={"node-content-inner-#{@node.id}"}>
              <article
                class="prose prose-stone prose-base sm:prose-lg lg:prose-xl max-w-none w-full prose-headings:mt-0 prose-headings:tracking-tight prose-headings:text-gray-900 prose-p:text-gray-800 prose-li:text-gray-800 prose-p:leading-relaxed prose-li:leading-relaxed"
                data-role="node-content"
              >
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
                    <% noted? = Enum.any?(Map.get(@node, :noted_by, []), fn u -> u == @user end) %>
                    <button
                      type="button"
                      class={[
                        "flex-none inline-flex items-center justify-center p-1.5 rounded-full transition-all",
                        if(noted?,
                          do: "bg-yellow-400 text-gray-900 hover:bg-yellow-500",
                          else: "bg-gray-100 text-gray-600 hover:bg-yellow-400 hover:text-gray-900"
                        )
                      ]}
                      phx-click={if noted?, do: "unnote", else: "note"}
                      phx-value-node={@node.id}
                      title={if noted?, do: "Remove from your notes", else: "Add to your notes"}
                    >
                      <.icon name="hero-star" class="h-4 w-4" />
                    </button>
                    <%= if @exploration_stats do %>
                      <span class="flex-none text-xs font-medium text-gray-500 bg-gray-100 rounded-full px-2 py-1 whitespace-nowrap mt-1">
                        {@exploration_stats["explored"]} / {@exploration_stats["total"]} explored
                      </span>
                    <% end %>
                  </span>
                </h3>

                <div
                  class="selection-content w-full px-1 pb-2 sm:px-2"
                  data-children={length(@node.children)}
                  id={"list-detector-#{@node.id}"}
                >
                  <div
                    phx-hook="Markdown"
                    class="cursor-text selection:bg-amber-200/80 selection:text-slate-900"
                    id={"markdown-body-#{@node.id}"}
                    data-md={@node.content || ""}
                    data-body-only="true"
                  >
                  </div>
                </div>
              </article>

              <.origin_intro node={@node} />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp origin_intro(assigns) do
    ~H"""
    <div
      id={"origin-intro-#{@node.id}"}
      class="mt-3 overflow-hidden rounded-[1.7rem] border border-slate-200 bg-white shadow-[0_18px_40px_rgba(15,23,42,0.06)] sm:mt-4"
      data-external="true"
      data-role="origin-intro"
    >
      <div class="border-b border-slate-200 bg-slate-50/80 px-4 py-4 sm:px-5">
        <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
          Start here
        </p>
        <h4 class="mt-1 text-base font-semibold tracking-tight text-slate-950">
          This is the shared starting point for the grid.
        </h4>
      </div>

      <div class="space-y-4 px-4 py-4 sm:px-5">
        <p class="text-sm leading-6 text-slate-600">
          To keep the Reader clear, continue from an existing response rather than branching again from the origin.
        </p>

        <.live_component
          module={DialecticWeb.OriginOnboardingComp}
          id={"origin-onboarding-#{@node.id}"}
        />
      </div>
    </div>
    """
  end
end
