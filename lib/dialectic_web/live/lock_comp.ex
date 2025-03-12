defmodule DialecticWeb.LockComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <div class="flex items-center">
        <label for="toggle_lock_graph" class="flex items-center cursor-pointer">
          <div class="relative">
            <input
              type="checkbox"
              id="toggle_lock_graph"
              class="sr-only"
              checked={!@graph_struct.is_public}
              name="toggle_lock_graph"
              phx-click="toggle_lock_graph"
            />
            <div class={"w-10 h-6 rounded-full transition #{if !@graph_struct.is_public, do: "bg-green-500", else: "bg-gray-300"}"}>
            </div>
            <div class={"absolute left-1 top-1 w-4 h-4 rounded-full transition transform #{if !@graph_struct.is_public, do: "translate-x-4 bg-white", else: "bg-white"}"}>
            </div>
          </div>
          <span class="ml-3 text-sm font-medium text-gray-900">
            {if @graph_struct.is_public, do: "Public", else: "Locked"}
          </span>
        </label>
        <.icon
          name="hero-information-circle"
          class="ml-2 h-5 w-5 text-gray-500"
          tooltip="When enabled, the graph is locked and cannot be edited by others."
        />
      </div>
    </div>
    """
  end
end
