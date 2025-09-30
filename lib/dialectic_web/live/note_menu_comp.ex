defmodule DialecticWeb.NoteMenuComp do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="rounded-md shadow-sm hidden sm:flex items-center text-xs overflow-x-auto whitespace-nowrap w-full">
      <div class="bg-white p-3">
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
            navigate={~p"/#{@graph_id}/linear"}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-red-200 text-red-600 hover:bg-red-50"
            title="Open printable PDF"
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
                d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
          </.link>

          <.link
            href={"/api/graphs/json/#{@graph_id}"}
            download={"#{@graph_id}.json"}
            class="inline-flex items-center justify-center w-8 h-8 rounded-md border border-blue-200 text-blue-600 hover:bg-blue-50"
            title="Download JSON"
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
                d="M7 7h10M7 11h10m-5 4h5m-9 2H9m13 0h-9m-1 4l-3-3H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
          </.link>

          <.link
            href={"/api/graphs/md/#{@graph_id}"}
            download={"#{@graph_id}.md"}
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
        </div>
      </div>
    </div>
    """
  end
end
