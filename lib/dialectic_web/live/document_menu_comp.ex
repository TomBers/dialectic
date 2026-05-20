defmodule DialecticWeb.DocumentMenuComp do
  use DialecticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show_help_modal, fn -> false end)
     |> assign_new(:layout_target, fn -> "#graph-layout" end)}
  end

  @impl true
  def handle_event("open_help_modal", _params, socket) do
    {:noreply, assign(socket, :show_help_modal, true)}
  end

  @impl true
  def handle_event("close_help_modal", _params, socket) do
    {:noreply, assign(socket, :show_help_modal, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inline-flex max-w-full flex-wrap items-center gap-1 rounded-[1.35rem] border border-slate-200/90 bg-white/98 px-2 py-2 shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]">
      <button
        id={"document-menu-help-#{@id}"}
        type="button"
        phx-click={JS.push("open_help_modal", target: @myself)}
        class={action_button_classes()}
        title="Open how-to guide for this page"
      >
        <.icon name="hero-academic-cap" class="h-4 w-4" />
        <span>How to use</span>
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
          action_button_classes(),
          "disabled:cursor-not-allowed disabled:opacity-45"
        ]}
        data-panel-toggle="presentation-drawer"
        aria-label="Start presentation setup"
        title="Present this graph"
      >
        <.icon name="hero-presentation-chart-bar" class="h-4 w-4" />
        <span>Present</span>
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
        class={action_button_classes()}
        data-panel-toggle="right-panel"
        aria-label="Open workspace settings"
        title="Open workspace settings"
      >
        <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
        <span>Settings</span>
      </button>

      <%= if @can_edit == false do %>
        <div class="inline-flex items-center gap-1 rounded-full border border-amber-200 bg-amber-50 px-2.5 py-1 text-[11px] font-semibold text-amber-700">
          <.icon name="hero-lock-closed" class="h-3.5 w-3.5" /> Read only
        </div>
      <% end %>

      <%= if @show_help_modal do %>
        <div class="fixed inset-0 z-[120] flex items-center justify-center p-3 sm:p-5">
          <button
            type="button"
            phx-click="close_help_modal"
            phx-target={@myself}
            class="absolute inset-0 bg-gray-900/55 backdrop-blur-[1px]"
            aria-label="Close how-to guide"
          >
          </button>
          <div class="relative z-10 w-full max-w-3xl rounded-2xl bg-white shadow-2xl ring-1 ring-gray-200">
            <div class="flex items-center justify-between border-b border-gray-200 px-4 py-3">
              <h2 class="text-sm font-semibold text-gray-900 sm:text-base">How to use this grid</h2>
              <button
                type="button"
                phx-click="close_help_modal"
                phx-target={@myself}
                class="inline-flex h-8 w-8 items-center justify-center rounded-md border border-gray-200 text-gray-600 transition hover:bg-gray-50"
                aria-label="Close how-to guide"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
            <div class="max-h-[78vh] overflow-y-auto p-3 sm:p-4">
              <.live_component
                module={DialecticWeb.OriginOnboardingComp}
                id="origin-onboarding-modal"
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp action_button_classes do
    [
      "inline-flex h-9 items-center gap-2 rounded-[0.95rem] border border-transparent px-3 text-sm font-medium text-slate-600 transition duration-150",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end
end
