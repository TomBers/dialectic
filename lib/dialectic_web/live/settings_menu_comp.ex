defmodule DialecticWeb.SettingsMenuComp do
  use DialecticWeb, :live_component

  @moduledoc """
  Settings menu component that consolidates the right panel controls.
  Contains Appearance, Configure, Workspace, Export, Utilities, and Node Guide sections.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <details class="group rounded-md border border-gray-200 bg-white">
        <summary class="list-none cursor-pointer px-2 py-1.5">
          <div class="flex items-start justify-between gap-2">
            <div class="space-y-0.5">
              <div class="text-[11px] font-semibold text-gray-700">Appearance</div>
              <p class="text-[10px] text-gray-500">
                Change how the graph is displayed and styled.
              </p>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-3.5 h-3.5 text-gray-500 transition-transform group-open:rotate-180 mt-0.5"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 p-1">
          <.live_component
            module={DialecticWeb.GraphNavPanelComp}
            id="graph-nav-panel"
            section={:views}
          />
        </div>
      </details>

      <.live_component
        module={DialecticWeb.RightPanelComp}
        id="right-panel-comp"
        graph_id={@graph_id}
        node={@node}
        work_streams={@work_streams}
        current_user={@current_user}
        graph_struct={@graph_struct}
        search_term={@search_term}
        search_results={@search_results}
        group_states={@group_states}
        highlights={@highlights}
        prompt_mode={@prompt_mode}
        token={@token}
      />

      <details class="group rounded-md border border-gray-200 bg-white">
        <summary class="list-none cursor-pointer px-2 py-1.5">
          <div class="flex items-start justify-between gap-2">
            <div class="space-y-0.5">
              <div class="text-[11px] font-semibold text-gray-700">Node Guide</div>
              <p class="text-[10px] text-gray-500">
                Reference for node types and keyboard shortcuts.
              </p>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-3.5 h-3.5 text-gray-500 transition-transform group-open:rotate-180 mt-0.5"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 p-1">
          <.live_component
            module={DialecticWeb.GraphNavPanelComp}
            id="graph-node-guide-panel"
            section={:reference}
          />
        </div>
      </details>
    </div>
    """
  end
end
