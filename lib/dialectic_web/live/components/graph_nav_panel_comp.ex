defmodule DialecticWeb.GraphNavPanelComp do
  use DialecticWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="ViewMode" id="view-mode-container">
      <!-- Graph Navigation Panel Toggle (when hidden) -->
      <%= if !@show do %>
        <button
          type="button"
          phx-click="toggle_graph_nav_panel"
          class={[
            "hidden sm:flex items-center justify-center w-10 h-10 bg-white rounded-lg shadow-lg border border-gray-200 hover:bg-gray-50 transition-colors fixed right-4 z-30 bottom-28 sm:bottom-20 md:bottom-16",
            if(@right_panel_open, do: "right-80 sm:right-96", else: "")
          ]}
          style={
            "bottom: " <>
              if(@bottom_menu_open,
                do: "calc(9rem + env(safe-area-inset-bottom))",
                else: "calc(6rem + env(safe-area-inset-bottom))"
              ) <> ";"
          }
          aria-label="Show navigation panel"
          title="Show navigation panel"
        >
          <.icon name="hero-map" class="w-5 h-5 text-gray-600" />
        </button>
      <% end %>
      
    <!-- Graph Navigation Panel -->
      <%= if @show do %>
        <div
          class={[
            "hidden sm:block sm:fixed right-4 z-30 bottom-28 sm:bottom-20 md:bottom-16",
            if(@right_panel_open, do: "right-80 sm:right-96", else: "")
          ]}
          style={
            "bottom: " <>
              if(@bottom_menu_open,
                do: "calc(9rem + env(safe-area-inset-bottom))",
                else: "calc(6rem + env(safe-area-inset-bottom))"
              ) <> ";"
          }
        >
          <div class="bg-white rounded-lg shadow-lg border border-gray-200 overflow-hidden">
            <!-- Header with close button -->
            <div class="px-3 py-2 bg-gray-50 border-b border-gray-200 flex items-center justify-between">
              <h3 class="text-xs font-semibold text-gray-700 uppercase tracking-wider">
                Graph Navigation
              </h3>
              <button
                type="button"
                phx-click="toggle_graph_nav_panel"
                class="text-gray-400 hover:text-gray-600 transition-colors"
                aria-label="Hide navigation panel"
                title="Hide navigation panel"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            
    <!-- Content -->
            <div class="p-3 space-y-3">
              <!-- View Mode Section -->
              <div>
                <div class="block text-xs font-medium text-gray-600 mb-1.5">View Mode</div>
                <label class="flex items-center cursor-pointer">
                  <span class="mr-2 text-xs font-medium text-gray-700">
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
                  <span class="ml-2 text-xs font-medium text-gray-700">
                    Compact
                  </span>
                </label>
              </div>
              
    <!-- Zoom Controls Section -->
              <div>
                <div class="block text-xs font-medium text-gray-600 mb-1.5">Zoom</div>
                <div class="flex items-center rounded-md border border-gray-200 overflow-hidden">
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
              
    <!-- Keyboard Shortcuts Section -->
              <div class="pt-2 border-t border-gray-200">
                <div class="block text-xs font-medium text-gray-600 mb-2">Shortcuts</div>
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
                    <span>Open node</span>
                    <kbd class="px-1.5 py-0.5 bg-gray-100 border border-gray-300 rounded text-[10px] font-mono">
                      Enter
                    </kbd>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
