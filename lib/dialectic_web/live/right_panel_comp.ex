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
      |> assign_new(:creative_mode, fn -> false end)

    {:ok, socket}
  end

  defp owner?(graph_struct, current_user) do
    current_user && graph_struct && graph_struct.user_id == current_user.id
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Search
        </div>
        <div class="p-1 space-y-1">
          <div class="flex items-center gap-2">
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
            <div class="bg-white p-1 max-h-60 overflow-y-auto border border-gray-200 rounded">
              <h3 class="text-xs font-semibold mb-1 text-gray-700">
                Search Results ({length(@search_results || [])})
              </h3>
              <ul class="space-y-1">
                <%= for node <- @search_results || [] do %>
                  <li
                    class="p-1 bg-gray-50 hover:bg-gray-100 rounded text-xs cursor-pointer"
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
            <div class="bg-white p-1 border border-gray-200 rounded">
              <p class="text-xs text-gray-500 text-center">
                No nodes found matching "{@search_term || ""}"
              </p>
            </div>
          <% end %>
        </div>
      </div>

      <%= if owner?(@graph_struct, @current_user) do %>
        <div class="bg-white border border-gray-200 rounded-md">
          <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
            Lock
          </div>
          <div class="p-1">
            <DialecticWeb.LockComp.render id="lock-graph" graph_struct={@graph_struct} />
          </div>
        </div>
      <% end %>

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Response Style
        </div>
        <div class="p-1 text-[11px] text-gray-700">
          <div class="flex items-center justify-between">
            <div class="text-xs text-gray-700">Creative mode</div>
            <button
              type="button"
              phx-click="toggle_creative_mode"
              class={"px-2 py-0.5 rounded border text-xs " <> if @creative_mode, do: "bg-indigo-50 text-indigo-700 border-indigo-200", else: "text-gray-700 hover:bg-gray-50 border-gray-300"}
            >
              {if @creative_mode, do: "On", else: "Off"}
            </button>
          </div>
          <p class="mt-1 text-[11px] text-gray-500">
            Looser, more voiceful prompts for varied, less repetitive answers.
          </p>
        </div>
      </div>

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Groups ({length(@work_streams)})
        </div>
        <div class="p-1 text-[11px] text-gray-700 space-y-1">
          <div class="flex items-center justify-between">
            <div class="font-semibold text-gray-700 text-xs">Groups</div>
            <button
              type="button"
              phx-click="open_start_stream_modal"
              class="text-indigo-600 hover:text-indigo-800 text-xs"
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
                      class="px-1 py-0.5 rounded border text-gray-700 hover:bg-gray-50 text-xs"
                    >
                      Focus
                    </button>
                    <button
                      type="button"
                      phx-click="toggle_stream"
                      phx-value-id={s.id}
                      class="px-1 py-0.5 rounded border text-gray-700 hover:bg-gray-50 text-xs"
                    >
                      Toggle
                    </button>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
      <div class="group bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Share
        </div>
        <div class="p-1 text-[11px] text-gray-700 space-y-1">
          <div class="flex items-center gap-2">
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

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Keyboard Shortcuts
        </div>
        <div class="p-1 text-[11px] text-gray-700 space-y-1">
          <ul class="space-y-1">
            <li><span class="font-mono">↑/↓</span> — parent/child</li>
            <li><span class="font-mono">←/→</span> — prev/next</li>
            <li><span class="font-mono">Enter</span> — open reader</li>
            <li><span class="font-mono">Ctrl/⌘ + scroll</span> — zoom</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
