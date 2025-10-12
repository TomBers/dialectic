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
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:search_results, fn -> [] end)
      |> assign_new(:group_states, fn -> %{} end)
      |> assign_new(:open_sections, fn ->
        %{
          "search" => true,
          "lock" => false,
          "node_info" => false,
          "streams" => false,
          "shortcuts" => false
        }
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    current = socket.assigns[:open_sections] || %{}
    val = Map.get(current, section, false)
    {:noreply, assign(socket, :open_sections, Map.put(current, section, !val))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <details open={@open_sections["search"]} class="bg-white border border-gray-200 rounded-md">
        <summary
          class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none"
          phx-click="toggle_section"
          phx-value-section="search"
          phx-target={@myself}
          onclick="event.preventDefault()"
        >
          Search
        </summary>
        <div class="p-2 space-y-2">
          <div class="flex items-center gap-4">
            <div class="flex-1">
              <form phx-submit="search_nodes" phx-change="search_nodes" class="flex relative">
                <input
                  type="text"
                  name="search_term"
                  id="search_input"
                  value={@search_term || ""}
                  placeholder="Search ..."
                  class="block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-800"
                  autocomplete="off"
                  phx-debounce="300"
                />
                <%= if (@search_term || "") != "" do %>
                  <button
                    type="button"
                    phx-click="clear_search"
                    class="absolute right-0 top-0 bottom-0 flex items-center pr-3 text-gray-500 hover:text-gray-700"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                <% end %>
              </form>
            </div>
          </div>

          <%= if (@search_term || "") != "" and length(@search_results || []) > 0 do %>
            <div class="bg-white p-2 max-h-60 overflow-y-auto border border-gray-200 rounded">
              <h3 class="text-sm font-semibold mb-2 text-gray-700">
                Search Results ({length(@search_results || [])})
              </h3>
              <ul class="space-y-2">
                <%= for node <- @search_results || [] do %>
                  <li
                    class="p-2 bg-gray-50 hover:bg-gray-100 rounded text-sm cursor-pointer"
                    phx-click="node_clicked"
                    phx-value-id={node.id}
                  >
                    <div class="font-semibold text-xs text-gray-500">
                      {node.id} • {node.class}
                    </div>
                    <div class="truncate">
                      {String.replace_prefix(node.content, "Title:", "")
                      |> String.slice(0, 100)}{if String.length(node.content) > 100,
                        do: "...",
                        else: ""}
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <%= if (@search_term || "") != "" and length(@search_results || []) == 0 do %>
            <div class="bg-white p-2 border border-gray-200 rounded">
              <p class="text-sm text-gray-500 text-center">
                No nodes found matching "{@search_term || ""}"
              </p>
            </div>
          <% end %>
        </div>
      </details>

      <details open={@open_sections["lock"]} class="bg-white border border-gray-200 rounded-md">
        <summary
          class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none"
          phx-click="toggle_section"
          phx-value-section="lock"
          phx-target={@myself}
          onclick="event.preventDefault()"
        >
          Lock
        </summary>
        <div class="p-2">
          <DialecticWeb.LockComp.render
            :if={@current_user && @graph_struct && @graph_struct.user_id == @current_user.id}
            id="lock-graph"
            graph_struct={@graph_struct}
          />
        </div>
      </details>
      <details
        open={@open_sections["node_info"]}
        class="group bg-white border border-gray-200 rounded-md"
      >
        <summary
          class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none"
          phx-click="toggle_section"
          phx-value-section="node_info"
          phx-target={@myself}
          onclick="event.preventDefault()"
        >
          Share & Download
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

      <details open={@open_sections["streams"]} class="bg-white border border-gray-200 rounded-md">
        <summary
          class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none"
          phx-click="toggle_section"
          phx-value-section="streams"
          phx-target={@myself}
          onclick="event.preventDefault()"
        >
          Streams
        </summary>
        <div class="p-2 text-xs text-gray-700 space-y-2">
          <div class="flex items-center justify-between">
            <div class="font-semibold text-gray-900">Groups</div>
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

      <details open={@open_sections["shortcuts"]} class="bg-white border border-gray-200 rounded-md">
        <summary
          class="px-3 py-2 text-xs font-semibold text-gray-700 cursor-pointer select-none"
          phx-click="toggle_section"
          phx-value-section="shortcuts"
          phx-target={@myself}
          onclick="event.preventDefault()"
        >
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
