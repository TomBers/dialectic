defmodule DialecticWeb.SettingsMenuComp do
  use DialecticWeb, :live_component

  @moduledoc """
  Settings menu component that consolidates the right panel controls.
  Contains Appearance, Configure, Workspace, Export, and Utilities sections.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <%!-- Appearance Section --%>
      <details class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow">
        <summary class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors">
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-violet-50 text-violet-600">
                <.icon name="hero-eye" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Appearance</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Graph display and reading settings
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <.live_component
            module={DialecticWeb.GraphNavPanelComp}
            id="graph-nav-panel"
            section={:views}
          />
        </div>
      </details>

      <%!-- RightPanelComp contains Configure, Workspace, Export, Utilities --%>
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
    </div>
    """
  end
end
