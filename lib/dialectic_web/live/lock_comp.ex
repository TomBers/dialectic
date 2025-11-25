defmodule DialecticWeb.LockComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-1 space-y-3">
      <!-- Edit Lock Toggle -->
      <div class="flex items-center">
        <label for="toggle_lock_graph" class="flex items-center cursor-pointer">
          <div class="relative">
            <input
              type="checkbox"
              id="toggle_lock_graph"
              class="sr-only"
              checked={@graph_struct.is_locked}
              name="toggle_lock_graph"
              phx-click="toggle_lock_graph"
            />
            <div class={"w-10 h-6 rounded-full transition #{if @graph_struct.is_locked, do: "bg-red-500", else: "bg-gray-300"}"}>
            </div>
            <div class={"absolute left-1 top-1 w-4 h-4 rounded-full transition transform #{if @graph_struct.is_locked, do: "translate-x-4 bg-white", else: "bg-white"}"}>
            </div>
          </div>
          <span class="ml-2 text-xs font-medium text-gray-800">
            {if @graph_struct.is_locked, do: "Locked", else: "Editable"}
          </span>
        </label>
        <.icon
          name="hero-lock-closed"
          class="ml-1 h-4 w-4 text-gray-500"
          tooltip="When locked, no one can edit the graph."
        />
      </div>
      
    <!-- Privacy Toggle -->
      <div class="flex items-center">
        <label for="toggle_public_graph" class="flex items-center cursor-pointer">
          <div class="relative">
            <input
              type="checkbox"
              id="toggle_public_graph"
              class="sr-only"
              checked={!@graph_struct.is_public}
              name="toggle_public_graph"
              phx-click="toggle_public_graph"
            />
            <div class={"w-10 h-6 rounded-full transition #{if !@graph_struct.is_public, do: "bg-green-500", else: "bg-gray-300"}"}>
            </div>
            <div class={"absolute left-1 top-1 w-4 h-4 rounded-full transition transform #{if !@graph_struct.is_public, do: "translate-x-4 bg-white", else: "bg-white"}"}>
            </div>
          </div>
          <span class="ml-2 text-xs font-medium text-gray-800">
            {if @graph_struct.is_public, do: "Public", else: "Private"}
          </span>
        </label>
        <.icon
          name="hero-information-circle"
          class="ml-1 h-4 w-4 text-gray-500"
          tooltip="When private, only you and invited users can access."
        />
      </div>
    </div>
    """
  end
end
