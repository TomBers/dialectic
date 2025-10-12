defmodule DialecticWeb.RightPanelComp do
  use DialecticWeb, :live_component

  @moduledoc """
  Accordion-style right panel with:
  - Node Information (shareable link + exports)
  - Streams (list, focus/toggle, and start)
  - Keyboard Shortcuts
  """

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <details open class="bg-white border border-gray-200 rounded-md">
        <summary class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none">
          Node Information
        </summary>
        <div class="p-2 text-xs text-gray-700 space-y-2">
          <div class="flex items-center justify-between gap-2">
            <span
              class="flex-1 truncate bg-gray-50 border border-gray-200 rounded px-2 py-1 font-mono select-all cursor-pointer"
              title="Shareable URL path"
              onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node && @node.id}")}').then(() => alert('Link copied to clipboard!'))"}
            >
              /{@graph_id}?node={@node && @node.id}
            </span>
            <button
              class="inline-flex items-center gap-1 text-gray-600 hover:text-gray-800 transition-colors p-1.5 border border-gray-300 rounded"
              title="Copy shareable link"
              onclick={"navigator.clipboard.writeText('#{url(~p"/#{@graph_id}?node=#{@node && @node.id}")}').then(() => alert('Link copied to clipboard!'))"}
            >
              <svg
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
              </svg>
              <span class="sr-only">Copy link</span>
            </button>
          </div>

          <div>
            <div class="text-xs font-semibold text-gray-600 mb-1">Export</div>
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
      </details>

      <details class="bg-white border border-gray-200 rounded-md">
        <summary class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none">
          Streams
        </summary>
        <div class="p-2 text-xs text-gray-700 space-y-2">
          <div class="flex items-center justify-between">
            <div class="font-semibold text-gray-900">Streams</div>
            <button
              type="button"
              phx-click="open_start_stream_modal"
              class="text-indigo-600 hover:text-indigo-800"
            >
              + Start
            </button>
          </div>
          <div class="max-h-56 overflow-y-auto">
            <ul class="space-y-1">
              <%= for s <- @work_streams || [] do %>
                <li class="flex items-center justify-between gap-2">
                  <span class="truncate">{s.id}</span>
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      phx-click="focus_stream"
                      phx-value-id={s.id}
                      class="px-2 py-0.5 rounded border text-gray-700 hover:bg-gray-50"
                    >
                      Focus
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_stream"
                      phx-value-id={s.id}
                      class="px-2 py-0.5 rounded border text-gray-700 hover:bg-gray-50"
                    >
                      Toggle
                    </button>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </details>

      <details class="bg-white border border-gray-200 rounded-md">
        <summary class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none">
          Keyboard Shortcuts
        </summary>
        <div class="p-2 text-xs text-gray-700 space-y-2">
          <div class="font-semibold text-gray-900">Keyboard Shortcuts</div>
          <ul class="space-y-1">
            <li>
              <span class="font-mono">↑</span>/<span class="font-mono">↓</span>
              <span class="text-gray-500">—</span>
              <span>Move to parent / child</span>
            </li>
            <li>
              <span class="font-mono">←</span>/<span class="font-mono">→</span>
              <span class="text-gray-500">—</span>
              <span>Move to previous / next sibling</span>
            </li>
            <li>
              <span class="font-mono">Enter</span>
              <span class="text-gray-500">—</span>
              <span>Open Reader</span>
            </li>
            <li>
              <span class="font-mono">Ctrl</span> or <span class="font-mono">⌘</span>
              <span class="text-gray-500"> + </span>
              <span>Scroll to zoom</span>
            </li>
          </ul>
        </div>
      </details>
    </div>
    """
  end
end
