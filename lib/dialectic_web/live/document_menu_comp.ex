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
    <div id={"document-menu-actions-#{@id}"} class={root_classes(@compact)}>
      <button
        id={"document-menu-help-#{@id}"}
        type="button"
        phx-click="open_help_modal"
        class={action_button_classes(@compact)}
        aria-label="Open how-to guide for this page"
        title="Open how-to guide for this page"
      >
        <.icon name="hero-academic-cap" class="h-4 w-4" />
        <span class={action_label_classes(@compact)}>How to use</span>
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
        <span class={action_label_classes(@compact)}>Present</span>
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
        aria-label="Open grid tools"
        title="Open grid tools"
      >
        <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
        <span class={action_label_classes(@compact)}>Tools</span>
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
      "flex max-w-full items-center gap-0.5 sm:inline-flex sm:flex-wrap sm:justify-start"
    ]
  end

  defp root_classes(false) do
    [
      "flex max-w-full items-center gap-1 sm:inline-flex sm:flex-wrap sm:justify-start"
    ]
  end

  defp action_button_classes(true) do
    [
      "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-transparent bg-slate-50 text-xs font-semibold text-slate-600 transition duration-150 sm:h-7 sm:w-7 sm:bg-transparent",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-xl border border-transparent bg-slate-50 text-sm font-semibold text-slate-600 transition duration-150 sm:w-auto sm:justify-start sm:bg-transparent sm:px-3",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp action_label_classes(true), do: "hidden"
  defp action_label_classes(false), do: "hidden sm:inline"
end
