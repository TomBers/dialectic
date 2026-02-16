defmodule DialecticWeb.GraphNavPanelComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="ViewMode" id="view-mode-container" class="h-full">
      <div class="space-y-4 p-1">
        <!-- View Mode Section -->
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
        
    <!-- Graph Direction Section -->
        <div>
          <div class="block text-sm font-semibold text-gray-900 mb-2">Graph Direction</div>
          <label class="flex items-center cursor-pointer">
            <span class="mr-2 text-xs text-gray-600">
              Top-Down
            </span>
            <div class="relative">
              <input
                type="checkbox"
                class="sr-only"
                data-graph-direction-toggle="toggle"
                aria-label="Toggle graph direction"
              />
              <div class="w-10 h-6 bg-gray-300 rounded-full transition"></div>
              <div class="absolute left-1 top-1 w-4 h-4 bg-white rounded-full transition transform">
              </div>
            </div>
            <span class="ml-2 text-xs text-gray-600">
              Bottom-Up
            </span>
          </label>
        </div>
        
    <!-- Zoom Controls Section -->
        <div>
          <div class="block text-sm font-semibold text-gray-900 mb-2">Zoom</div>
          <div class="flex items-center rounded-md border border-gray-200 overflow-hidden bg-white">
            <button
              id="zoom-out"
              type="button"
              class="flex-1 px-3 py-1.5 text-gray-700 hover:bg-gray-50 border-r border-gray-200 font-semibold"
              aria-label="Zoom out"
              title="Zoom out"
            >
              <.icon name="hero-minus" class="w-3.5 h-3.5 inline-block" />
            </button>
            <button
              id="zoom-fit"
              type="button"
              class="flex-1 px-3 py-1.5 text-gray-700 hover:bg-gray-50 text-xs font-medium border-r border-gray-200"
              aria-label="Fit to screen"
              title="Fit to screen"
            >
              <.icon name="hero-arrows-pointing-out" class="w-3.5 h-3.5 inline-block mr-1" />
            </button>
            <button
              id="zoom-in"
              type="button"
              class="flex-1 px-3 py-1.5 text-gray-700 hover:bg-gray-50 font-semibold"
              aria-label="Zoom in"
              title="Zoom in"
            >
              <.icon name="hero-plus" class="w-3.5 h-3.5 inline-block" />
            </button>
          </div>
        </div>
        
    <!-- Node Colors Section -->
        <div class="pt-2 border-t border-gray-200">
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
        
    <!-- Keyboard Shortcuts Section -->
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
      </div>
    </div>
    """
  end
end
