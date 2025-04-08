defmodule DialecticWeb.PageHtml.GraphComp do
  use DialecticWeb, :live_component

  def render(assigns) do
    ~H"""
    <.link navigate={@link} class="block transition hover:transform hover:scale-102 group">
      <div class="bg-white text-gray-800 shadow-md rounded-lg p-6 hover:shadow-xl hover:bg-gradient-to-r hover:from-indigo-500 hover:to-purple-600 hover:text-white flex justify-between items-center">
        <div>
          <h3 class="font-bold text-xl mb-2">
            <span :if={!@is_public} class="mr-2 text-amber-500 hover:text-amber-300">
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
              {@title}
              <%= if @count > 1 do %>
                | {@count} notes
              <% end %>
            </span>
          </h3>
        </div>
        <!-- Right arrow icon with fixed dimensions -->
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-6 w-6 min-w-6 min-h-6 transition-transform group-hover:translate-x-1"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M14 5l7 7m0 0l-7 7m7-7H3" />
        </svg>
      </div>
    </.link>
    """
  end
end
