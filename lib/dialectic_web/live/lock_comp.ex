defmodule DialecticWeb.LockComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <!-- Edit Lock Toggle -->
      <div class="rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
        <label for="toggle_lock_graph" class="flex cursor-pointer items-center justify-between gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-1.5">
              <span class="text-xs font-semibold text-gray-800">Editing</span>
              <.icon
                name="hero-lock-closed"
                class="h-3.5 w-3.5 text-gray-400"
                tooltip="When locked, no one can edit the graph."
              />
            </div>
            <p class="mt-0.5 text-[11px] leading-4 text-gray-500">
              Turn on to keep the map editable.
            </p>
          </div>

          <div class="flex items-center gap-2">
            <span class={[
              "inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold",
              if(!@graph_struct.is_locked,
                do: "bg-emerald-50 text-emerald-700",
                else: "bg-gray-100 text-gray-600"
              )
            ]}>
              {if !@graph_struct.is_locked, do: "Editable", else: "Locked"}
            </span>

            <div class="relative shrink-0">
              <input
                type="checkbox"
                id="toggle_lock_graph"
                class="sr-only"
                checked={!@graph_struct.is_locked}
                name="toggle_lock_graph"
                phx-click="toggle_lock_graph"
              />
              <div class={[
                "h-6 w-11 rounded-full transition",
                if(!@graph_struct.is_locked, do: "bg-emerald-500", else: "bg-gray-300")
              ]}>
              </div>
              <div class={[
                "absolute left-1 top-1 h-4 w-4 rounded-full bg-white shadow-sm transition-transform",
                if(!@graph_struct.is_locked, do: "translate-x-5", else: "translate-x-0")
              ]}>
              </div>
            </div>
          </div>
        </label>
      </div>
      
    <!-- Privacy Toggle -->
      <div class="rounded-xl border border-gray-200 bg-white px-3 py-2.5 shadow-sm">
        <label
          for="toggle_public_graph"
          class="flex cursor-pointer items-center justify-between gap-3"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-1.5">
              <span class="text-xs font-semibold text-gray-800">Visibility</span>
              <.icon
                name="hero-information-circle"
                class="h-3.5 w-3.5 text-gray-400"
                tooltip="When private, only you and invited users can access."
              />
            </div>
            <p class="mt-0.5 text-[11px] leading-4 text-gray-500">
              Turn on to make the map public.
            </p>
          </div>

          <div class="flex items-center gap-2">
            <span class={[
              "inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold",
              if(@graph_struct.is_public,
                do: "bg-sky-50 text-sky-700",
                else: "bg-gray-100 text-gray-600"
              )
            ]}>
              {if @graph_struct.is_public, do: "Public", else: "Private"}
            </span>

            <div class="relative shrink-0">
              <input
                type="checkbox"
                id="toggle_public_graph"
                class="sr-only"
                checked={@graph_struct.is_public}
                name="toggle_public_graph"
                phx-click="toggle_public_graph"
              />
              <div class={[
                "h-6 w-11 rounded-full transition",
                if(@graph_struct.is_public, do: "bg-sky-500", else: "bg-gray-300")
              ]}>
              </div>
              <div class={[
                "absolute left-1 top-1 h-4 w-4 rounded-full bg-white shadow-sm transition-transform",
                if(@graph_struct.is_public, do: "translate-x-5", else: "translate-x-0")
              ]}>
              </div>
            </div>
          </div>
        </label>
      </div>
    </div>
    """
  end
end
