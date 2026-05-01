defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="hidden sm:flex items-center text-xs overflow-x-auto whitespace-nowrap w-full">
      <div class="bg-white">
        <div class="text-xs font-semibold text-gray-600 mb-2">Export</div>
        <div class="flex items-center justify-center gap-2">
          <button
            type="button"
            class="download-png inline-flex items-center justify-center w-8 h-8 rounded-md border border-green-200 text-green-600 hover:bg-green-50"
            aria-label="Download PNG"
            title="Download PNG (Alt-click to capture full graph)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 7h4l2-2h6l2 2h4v12H3zM12 17a5 5 0 100-10 5 5 0 000 10z"
              />
            </svg>
          </button>

          <.link
            href={
              path =
                if @graph_struct && @graph_struct.slug,
                  do: "/api/graphs/md/#{@graph_struct.slug}",
                  else: "/api/graphs/md/#{URI.encode(@graph_id)}"

              if assigns[:token],
                do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
                else: path
            }
            download={
              if @graph_struct && @graph_struct.slug,
                do: "#{@graph_struct.slug}.md",
                else: "#{@graph_id}.md"
            }
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-purple-200 text-purple-600 hover:bg-purple-50"
            title="Download Markdown"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
          </.link>

          <.link
            href={
              path =
                if @graph_struct && @graph_struct.slug,
                  do: "/api/graphs/json/#{@graph_struct.slug}",
                  else: "/api/graphs/json/#{URI.encode(@graph_id)}"

              if assigns[:token],
                do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
                else: path
            }
            download={
              if @graph_struct && @graph_struct.slug,
                do: "#{@graph_struct.slug}.json",
                else: "#{@graph_id}.json"
            }
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-blue-200 text-blue-600 hover:bg-blue-50"
            title="Download JSON (for image generation)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
              />
            </svg>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
