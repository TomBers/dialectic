defmodule DialecticWeb.GraphNavPanelComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :section, fn -> :views end)

    ~H"""
    <div
      phx-hook={if @section == :views, do: "ViewMode", else: nil}
      id={"view-panel-#{@id}"}
      class="h-full"
    >
      <div class="space-y-4">
        <%= if @section == :views do %>
          <%!-- Reading Settings --%>
          <div class="space-y-3">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              Reading
            </div>
            <div class="space-y-2.5">
              <div class="flex items-center justify-between gap-3">
                <span class="text-xs text-gray-700">Density</span>
                <div
                  class="inline-flex items-center rounded-lg bg-gray-100 p-0.5"
                  role="group"
                  aria-label="Reading density"
                >
                  <%= for {value, label} <- [{"compact", "Compact"}, {"comfortable", "Comfortable"}, {"large", "Large"}] do %>
                    <button
                      type="button"
                      phx-click={
                        JS.dispatch("set-reading-density",
                          to: "#graph-layout",
                          detail: %{value: value}
                        )
                      }
                      data-reading-density-option={value}
                      class="reading-density-btn inline-flex items-center justify-center rounded-md px-2.5 py-1.5 text-[11px] font-medium text-gray-600 hover:text-gray-800 transition-colors"
                      aria-label={"Set reading density to #{label}"}
                      aria-pressed={if value == "comfortable", do: "true", else: "false"}
                    >
                      {label}
                    </button>
                  <% end %>
                </div>
              </div>
              <div class="flex items-center justify-between gap-3">
                <span class="text-xs text-gray-700">Font</span>
                <div
                  class="inline-flex items-center rounded-lg bg-gray-100 p-0.5"
                  role="group"
                  aria-label="Reading font"
                >
                  <%= for {value, label} <- [{"sans", "Sans"}, {"serif", "Serif"}] do %>
                    <button
                      type="button"
                      phx-click={
                        JS.dispatch("set-reading-font",
                          to: "#graph-layout",
                          detail: %{value: value}
                        )
                      }
                      data-reading-font-option={value}
                      class="reading-font-btn inline-flex items-center justify-center rounded-md px-2.5 py-1.5 text-[11px] font-medium text-gray-600 hover:text-gray-800 transition-colors"
                      aria-label={"Set reading font to #{label}"}
                      aria-pressed={if value == "sans", do: "true", else: "false"}
                    >
                      {label}
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%!-- View Mode --%>
          <div class="space-y-3 pt-3 border-t border-gray-100">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              View Mode
            </div>
            <label class="flex items-center justify-between cursor-pointer">
              <span class="text-xs text-gray-700">Layout</span>
              <div class="flex items-center gap-2">
                <span class="text-[11px] text-gray-500">Spaced</span>
                <div class="relative">
                  <input
                    type="checkbox"
                    class="sr-only"
                    data-view-mode-toggle="toggle"
                    aria-label="Toggle view mode"
                  />
                  <div class="w-9 h-5 bg-gray-200 rounded-full transition"></div>
                  <div class="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full shadow transition transform">
                  </div>
                </div>
                <span class="text-[11px] text-gray-500">Compact</span>
              </div>
            </label>
          </div>

          <%!-- Graph Direction --%>
          <div class="space-y-3 pt-3 border-t border-gray-100">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              Graph Direction
            </div>
            <div class="grid grid-cols-2 gap-1.5" role="group" aria-label="Graph direction options">
              <button
                type="button"
                data-graph-direction-option="TB"
                class="direction-btn inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white px-2 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 transition-colors"
              >
                Top ↓ Bottom
              </button>
              <button
                type="button"
                data-graph-direction-option="BT"
                class="direction-btn inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white px-2 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 transition-colors"
              >
                Bottom ↑ Top
              </button>
              <button
                type="button"
                data-graph-direction-option="LR"
                class="direction-btn inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white px-2 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 transition-colors"
              >
                Left → Right
              </button>
              <button
                type="button"
                data-graph-direction-option="RL"
                class="direction-btn inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white px-2 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 transition-colors"
              >
                Right ← Left
              </button>
            </div>
            <p class="text-[10px] text-gray-400">
              Also updates arrow-key navigation semantics.
            </p>
          </div>
        <% else %>
          <%!-- Node Colors Reference --%>
          <div class="space-y-3">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              Node Colors
            </div>
            <div class="grid grid-cols-2 gap-2.5">
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("user") <> " ring-blue-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("user")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">Your questions</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("answer") <> " ring-gray-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("answer")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">AI responses</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("thesis") <> " ring-green-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("thesis")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">Supporting points</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("antithesis") <> " ring-red-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("antithesis")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">Counterpoints</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("synthesis") <> " ring-purple-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("synthesis")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">Balanced views</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 ring-2 ring-offset-1 ring-opacity-30 " <> DialecticWeb.ColUtils.dot_class("ideas") <> " ring-amber-400"}>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-gray-800">
                    {DialecticWeb.ColUtils.node_type_label("ideas")}
                  </div>
                  <div class="text-[10px] text-gray-500 leading-tight">Related concepts</div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Keyboard Shortcuts --%>
          <div class="pt-3 border-t border-gray-100 space-y-3">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              Keyboard Shortcuts
            </div>
            <div class="space-y-1.5">
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Pan graph</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  Space + Drag
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Zoom</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  ⌘/Ctrl + Scroll
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Scroll pan</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  Scroll
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Parent/child</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  ↑ / ↓
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Prev/next</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  ← / →
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Expand children</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  E
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Collapse children</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  C
                </kbd>
              </div>
              <div class="flex items-center justify-between py-1">
                <span class="text-xs text-gray-600">Open node</span>
                <kbd class="px-2 py-1 bg-gray-100 border border-gray-200 rounded-md text-[10px] font-mono text-gray-600">
                  Enter
                </kbd>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
