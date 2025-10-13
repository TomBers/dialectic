defmodule DialecticWeb.ExportMenuComp do
  use DialecticWeb, :live_component

  @moduledoc """
  Reusable export dropdown menu for graph exports.

  Provides:
  - PNG screenshot (integrates with the existing `.download-png` hook)
  - PDF (navigates to the linear print view)

  - Markdown download

  Assigns:
  - `graph_id` (required): The current graph identifier.
  - `label` (optional): Custom label for the dropdown trigger (default: "Export").
  - `class` (optional): Extra classes added to the wrapper container.
  - `align` (optional): "left" or "right" alignment of the dropdown (default: "right").
  """

  @impl true
  def update(assigns, socket) do
    assigns =
      assigns
      |> Map.put_new(:label, "Export")
      |> Map.put_new(:class, "")
      |> Map.put_new(:align, "right")

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"relative inline-block " <> @class}>
      <details class="group">
        <summary
          class="inline-flex items-center gap-1.5 text-xs font-semibold px-2.5 py-1.5 rounded-md border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 hover:text-gray-900 transition-colors shadow-sm cursor-pointer list-none"
          role="button"
          aria-haspopup="true"
          aria-expanded="false"
          title="Export options"
        >
          <span>{@label}</span>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3.5 w-3.5 opacity-80"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 10.939l3.71-3.71a.75.75 0 1 1 1.06 1.062l-4.24 4.24a.75.75 0 0 1-1.06 0L5.21 8.29a.75.75 0 0 1 .02-1.08Z"
              clip-rule="evenodd"
            />
          </svg>
        </summary>

        <div class={[
          "absolute z-20 mt-2 w-56 bg-white rounded-md shadow-lg border border-gray-200 p-2 space-y-1",
          @align == "right" && "right-0",
          @align == "left" && "left-0"
        ]}>
          <!-- PNG -->
          <button
            type="button"
            class="download-png w-full text-left inline-flex items-center gap-2 text-xs font-medium px-2.5 py-2 rounded-md hover:bg-gray-50 transition-colors"
            aria-label="Download PNG"
            title="Download PNG (Alt-click to capture full graph)"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 text-green-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 7h4l2-2h6l2 2h4v12H3zM12 17a5 5 0 100-10 5 5 0 000 10z"
              />
            </svg>
            <span>PNG</span>
          </button>
          
    <!-- PDF -->
          <.link
            navigate={~p"/#{@graph_id}/linear"}
            target="_blank"
            rel="noopener noreferrer"
            class="w-full inline-flex items-center gap-2 text-xs font-medium px-2.5 py-2 rounded-md hover:bg-gray-50 transition-colors"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 text-red-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <span>PDF</span>
          </.link>
          
    <!-- Markdown -->
          <.link
            href={"/api/graphs/md/#{@graph_id}"}
            download={"#{@graph_id}.md"}
            class="w-full inline-flex items-center gap-2 text-xs font-medium px-2.5 py-2 rounded-md hover:bg-gray-50 transition-colors"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-4 w-4 text-purple-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
              />
            </svg>
            <span>Markdown</span>
          </.link>
        </div>
      </details>
    </div>
    """
  end
end
