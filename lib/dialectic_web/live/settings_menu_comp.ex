defmodule DialecticWeb.SettingsMenuComp do
  use DialecticWeb, :live_component

  @moduledoc """
  Settings menu component that consolidates the right panel controls.
  Contains Configure, Workspace, Export, and Utilities sections.
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-1.5">
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
