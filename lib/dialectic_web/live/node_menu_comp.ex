defmodule DialecticWeb.NodeMenuComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="bg-white border border-gray-200 rounded-md shadow-sm p-3">
        <h3 class="text-xs font-medium text-gray-600 mb-2 flex items-center">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            >
            </path>
          </svg>
          Node Panel
        </h3>
        <p class="text-xs text-gray-600">
          This panel is text-only for now. The question/comment input has been moved to the central bottom chat box as part of this experiment.
        </p>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
