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
      <div class="space-y-4 p-1">
        <%= if @section == :views do %>
          <div>
            <div class="block text-sm font-semibold text-gray-900 mb-2">Reading</div>
            <div class="space-y-2">
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs text-gray-600">
                  Density
                </span>
                <div
                  class="inline-flex items-center rounded-lg border border-gray-200 bg-gray-50 p-0.5"
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
                      class="reading-density-btn inline-flex items-center justify-center rounded-md border border-transparent px-2.5 py-1 text-[11px] font-medium text-gray-600 hover:text-gray-800"
                      aria-label={"Set reading density to #{label}"}
                      aria-pressed={if value == "comfortable", do: "true", else: "false"}
                    >
                      {label}
                    </button>
                  <% end %>
                </div>
              </div>
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs text-gray-600">
                  Font
                </span>
                <div
                  class="inline-flex items-center rounded-lg border border-gray-200 bg-gray-50 p-0.5"
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
                      class="reading-font-btn inline-flex items-center justify-center rounded-md border border-transparent px-2.5 py-1 text-[11px] font-medium text-gray-600 hover:text-gray-800"
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

          <div>
            <div class="block text-sm font-semibold text-gray-900 mb-2">View Mode</div>
            <label class="flex items-center cursor-pointer">
              <span class="mr-2 text-xs text-gray-600">
                Spaced
              </span>
              <div class="relative">
                <input
                  type="checkbox"
                  class="sr-only"
                  data-view-mode-toggle="toggle"
                  aria-label="Toggle view mode"
                />
                <div class="w-10 h-6 bg-gray-300 rounded-full transition"></div>
                <div class="absolute left-1 top-1 w-4 h-4 bg-white rounded-full transition transform">
                </div>
              </div>
              <span class="ml-2 text-xs text-gray-600">
                Compact
              </span>
            </label>
          </div>

          <div>
            <div class="block text-sm font-semibold text-gray-900 mb-2">Graph Direction</div>
            <div class="grid grid-cols-2 gap-1.5" role="group" aria-label="Graph direction options">
              <button
                type="button"
                data-graph-direction-option="TB"
                class="direction-btn inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-2 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Top ↓ Bottom
              </button>
              <button
                type="button"
                data-graph-direction-option="BT"
                class="direction-btn inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-2 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Bottom ↑ Top
              </button>
              <button
                type="button"
                data-graph-direction-option="LR"
                class="direction-btn inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-2 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Left → Right
              </button>
              <button
                type="button"
                data-graph-direction-option="RL"
                class="direction-btn inline-flex items-center justify-center rounded-md border border-gray-300 bg-white px-2 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Right ← Left
              </button>
            </div>
            <p class="mt-1 text-[11px] text-gray-500">
              Also updates arrow-key navigation semantics.
            </p>
          </div>
        <% else %>
          <div>
            <div class="block text-sm font-semibold text-gray-900 mb-2.5">Node Colors</div>
            <div class="grid grid-cols-2 gap-2">
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("user")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("user")}
                  </div>
                  <div class="text-[10px] text-gray-500">Your questions and comments</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("answer")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("answer")}
                  </div>
                  <div class="text-[10px] text-gray-500">AI-generated responses</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("thesis")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("thesis")}
                  </div>
                  <div class="text-[10px] text-gray-500">Supporting arguments</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("antithesis")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("antithesis")}
                  </div>
                  <div class="text-[10px] text-gray-500">Counterarguments</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("synthesis")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("synthesis")}
                  </div>
                  <div class="text-[10px] text-gray-500">Balanced perspectives</div>
                </div>
              </div>
              <div class="flex items-start gap-2">
                <div class={"w-3 h-3 rounded-full flex-shrink-0 mt-0.5 " <> DialecticWeb.ColUtils.dot_class("ideas")}>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-gray-900">
                    {DialecticWeb.ColUtils.node_type_label("ideas")}
                  </div>
                  <div class="text-[10px] text-gray-500">Related concepts</div>
                </div>
              </div>
            </div>
          </div>

          <div class="pt-2 border-t border-gray-200">
            <div class="block text-sm font-semibold text-gray-900 mb-2.5">Shortcuts</div>
            <div class="space-y-1.5 text-xs text-gray-600">
              <div class="flex items-center justify-between">
                <span>Pan graph</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  Space + Drag
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Zoom</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  ⌘/Ctrl + Scroll
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Scroll pan</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  Scroll
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Parent/child</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  ↑ / ↓
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Prev/next</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  ← / →
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Expand children</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  E
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Collapse children</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                  C
                </kbd>
              </div>
              <div class="flex items-center justify-between">
                <span>Open node</span>
                <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
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
