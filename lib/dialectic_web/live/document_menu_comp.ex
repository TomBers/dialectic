defmodule DialecticWeb.DocumentMenuComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:layout_target, fn -> "#graph-layout" end)
     |> assign_new(:compact, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={root_classes(@compact)}>
      <button
        id={"document-menu-help-#{@id}"}
        type="button"
        phx-click="open_help_modal"
        class={action_button_classes(@compact)}
        title="Open how-to guide for this page"
      >
        <.icon name="hero-academic-cap" class="h-4 w-4" />
        <span class="hidden sm:inline">How to use</span>
      </button>

      <button
        id={"document-menu-present-#{@id}"}
        type="button"
        phx-click={
          JS.dispatch("toggle-side-drawer",
            to: @layout_target,
            detail: %{force: "close", persist: false}
          )
          |> JS.dispatch("toggle-panel",
            to: @layout_target,
            detail: %{id: "presentation-drawer"}
          )
          |> JS.push("enter_presentation_setup")
        }
        disabled={is_nil(@graph_id)}
        class={[
          action_button_classes(@compact),
          "disabled:cursor-not-allowed disabled:opacity-45"
        ]}
        data-panel-toggle="presentation-drawer"
        aria-label="Start presentation setup"
        title="Present this grid"
      >
        <.icon name="hero-presentation-chart-bar" class="h-4 w-4" />
        <span class="hidden sm:inline">Present</span>
      </button>

      <button
        id={"document-menu-settings-#{@id}"}
        type="button"
        phx-click={
          JS.dispatch("toggle-panel",
            to: @layout_target,
            detail: %{id: "right-panel"}
          )
        }
        class={action_button_classes(@compact)}
        data-panel-toggle="right-panel"
        aria-label="Open workspace settings"
        title="Open workspace settings"
      >
        <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
        <span class="hidden sm:inline">Settings</span>
      </button>

      <%= if @can_edit == false do %>
        <div class="inline-flex items-center gap-1 rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-[11px] font-semibold text-amber-700">
          <.icon name="hero-lock-closed" class="h-3.5 w-3.5" /> Read only
        </div>
      <% end %>
    </div>
    """
  end

  defp root_classes(true) do
    [
      "flex w-full max-w-full items-center gap-1 rounded-[1.1rem] border border-slate-200/90 bg-white/98 px-1.5 py-1.5 shadow-[0_10px_24px_-20px_rgba(15,23,42,0.35)] sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:gap-0.5 sm:rounded-[1.25rem] sm:shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]"
    ]
  end

  defp root_classes(false) do
    [
      "flex w-full max-w-full items-center gap-1 rounded-[1.2rem] border border-slate-200/90 bg-white/98 px-1.5 py-1.5 shadow-[0_10px_24px_-20px_rgba(15,23,42,0.35)] sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:rounded-[1.35rem] sm:px-2 sm:py-2 sm:shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]"
    ]
  end

  defp action_button_classes(true) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 text-sm font-medium text-slate-600 transition duration-150 sm:h-8 sm:w-auto sm:justify-start sm:rounded-[0.85rem] sm:border-transparent sm:bg-transparent sm:px-2.5",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 text-sm font-medium text-slate-600 transition duration-150 sm:w-auto sm:justify-start sm:rounded-[0.95rem] sm:border-transparent sm:bg-transparent sm:px-3",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end
end
