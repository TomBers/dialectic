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
        aria-controls="right-panel"
        aria-expanded="false"
        aria-label="Open grid tools"
        title="Open grid tools"
      >
        <.icon name="hero-wrench-screwdriver" class="h-4 w-4" />
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
      "flex max-w-full flex-nowrap items-center gap-0.5"
    ]
  end

  defp root_classes(false) do
    [
      "flex max-w-full flex-nowrap items-center gap-1"
    ]
  end

  defp action_button_classes(true) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white text-xs font-semibold text-slate-600 transition duration-150 md:w-20",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-xl border border-transparent bg-slate-50 text-sm font-semibold text-slate-600 transition duration-150 sm:w-auto sm:justify-start sm:bg-transparent sm:px-3",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp action_label_classes(true), do: "hidden md:inline"
  defp action_label_classes(false), do: "hidden sm:inline"
end
