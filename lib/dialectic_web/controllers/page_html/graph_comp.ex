defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <.link navigate={@link} class="block transition hover:transform hover:scale-102">
      <div class="bg-white text-gray-800 shadow-md rounded-lg p-6 hover:shadow-xl hover:bg-gradient-to-r hover:from-indigo-500 hover:to-purple-600 hover:text-white transition-all">
        <h3 class="font-bold text-xl mb-2">
          <span :if={!@graph.is_public} class="mr-2 text-amber-500 hover:text-amber-300">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 inline"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                clip-rule="evenodd"
              />
            </svg>
          </span>
          <span class="transition-colors">
            {@graph.title}
          </span>
        </h3>

        <div class="mt-3 w-full h-1 bg-gray-100 rounded-full overflow-hidden">
          <div class="h-full bg-indigo-500 rounded-full" style={"width: #{min(@count * 5, 100)}%"}>
          </div>
        </div>

        <p class="mt-3 text-sm text-gray-500 hover:text-white transition-colors">
          {@count} notes
        </p>
      </div>
    </.link>
    """
  end
end
