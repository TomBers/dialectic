defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <.link navigate={@link} class="block group h-full">
      <div class="bg-white text-gray-900 rounded-lg p-5 ring-1 ring-gray-200 hover:bg-gray-50 hover:ring-gray-300 transition-colors">
        <h3 class="font-semibold text-lg">
          {@title}
        </h3>
      </div>
    </.link>
    """
  end
end
