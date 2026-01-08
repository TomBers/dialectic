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
    node_id =
      case Map.get(assigns, :node) do
        %{} = n ->
          Map.get(n, :id)

        _ ->
          case Map.get(socket.assigns, :node) do
            %{} = n -> Map.get(n, :id)
            _ -> nil
          end
      end

    graph_id =
      case Map.get(assigns, :graph_id) do
        id when is_binary(id) and id != "" ->
          id

        _ ->
          case Map.get(assigns, :graph_struct) do
            %{} = gs ->
              Map.get(gs, :title) || Map.get(socket.assigns, :graph_id, "")

            _ ->
              Map.get(socket.assigns, :graph_id, "")
          end
      end

    share_path =
      if not is_nil(node_id) and node_id != "" and (is_binary(graph_id) and graph_id != "") do
        "/#{graph_id}?node=#{node_id}"
      else
        "/#{graph_id}"
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:share_path, share_path)
      |> assign_new(:search_term, fn -> "" end)
      |> assign_new(:search_results, fn -> [] end)
      |> assign_new(:group_states, fn -> %{} end)
      |> assign_new(:prompt_mode, fn -> "structured" end)
      |> assign_new(:highlights, fn -> [] end)
      |> assign_new(:editing_highlight_id, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def handle_event("delete_highlight", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         highlight when not is_nil(highlight) <- Dialectic.Highlights.get_highlight(int_id) do
      if current_user && current_user.id == highlight.created_by_user_id do
        Dialectic.Highlights.delete_highlight(highlight)
      end
    end

    {:noreply, socket}
  end

  def handle_event("edit_highlight", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {int_id, ""} -> {:noreply, assign(socket, editing_highlight_id: int_id)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, editing_highlight_id: nil)}
  end

  def handle_event("save_note", %{"highlight_id" => id, "note" => note}, socket) do
    current_user = socket.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         highlight when not is_nil(highlight) <- Dialectic.Highlights.get_highlight(int_id) do
      if current_user && current_user.id == highlight.created_by_user_id do
        Dialectic.Highlights.update_highlight(highlight, %{note: note})
      end
    end

    {:noreply, assign(socket, editing_highlight_id: nil)}
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

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Mode
        </div>
        <div class="p-1">
          <form phx-change="set_prompt_mode" class="flex items-center gap-2">
            <label for="prompt_mode" class="text-xs text-gray-700">LLM Mode</label>
            <select
              id="prompt_mode"
              name="prompt_mode"
              class="block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border-zinc-300 focus:border-zinc-800"
            >
              <option value="structured" selected={@prompt_mode == "structured"}>Structured</option>
              <option value="creative" selected={@prompt_mode == "creative"}>Creative</option>
            </select>
          </form>
          <div class="mt-2 text-[11px] text-gray-600 space-y-1">
            <p>
              <span class="font-semibold">Structured:</span>
              organized sections, concise bullets, and clear constraints.
            </p>
            <p>
              <span class="font-semibold">Creative:</span>
              freer narrative, analogies, and playful exploration.
            </p>
          </div>
        </div>
      </div>

      <%= if owner?(@graph_struct, @current_user) do %>
        <div class="bg-white border border-gray-200 rounded-md">
          <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
            Access
          </div>
          <div class="p-1 space-y-2">
            <DialecticWeb.LockComp.render id="lock-graph" graph_struct={@graph_struct} />
            <button
              phx-click="open_share_modal"
              class="w-full flex items-center justify-center px-2 py-1 border border-indigo-200 rounded bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors text-xs"
            >
              <%= if @graph_struct.is_public do %>
                <.icon name="hero-share" class="w-3 h-3 mr-1" />
                <span>Share Map</span>
              <% else %>
                <.icon name="hero-user-plus" class="w-3 h-3 mr-1" />
                <span>Manage Collaborators</span>
              <% end %>
            </button>
          </div>
        </div>
      <% end %>
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

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Highlights ({length(@highlights)})
        </div>
        <div class="p-1 text-[11px] text-gray-700 space-y-1">
          <div class="max-h-56 overflow-y-auto">
            <%= if length(@highlights) > 0 do %>
              <ul class="space-y-1">
                <%= for highlight <- @highlights do %>
                  <li class="group p-1 bg-gray-50 hover:bg-gray-100 rounded text-xs relative">
                    <%= if @editing_highlight_id == highlight.id do %>
                      <form
                        phx-submit="save_note"
                        phx-target={@myself}
                        class="flex flex-col gap-2 p-1"
                      >
                        <input type="hidden" name="highlight_id" value={highlight.id} />
                        <textarea
                          name="note"
                          class="w-full text-xs border-gray-300 rounded focus:ring-indigo-500 focus:border-indigo-500"
                          rows="3"
                          placeholder="Add a note..."
                        ><%= highlight.note %></textarea>
                        <div class="flex justify-end gap-2">
                          <button
                            type="button"
                            phx-click="cancel_edit"
                            phx-target={@myself}
                            class="text-gray-500 hover:text-gray-700"
                          >
                            Cancel
                          </button>
                          <button
                            type="submit"
                            class="bg-indigo-600 text-white px-2 py-1 rounded hover:bg-indigo-700"
                          >
                            Save
                          </button>
                        </div>
                      </form>
                    <% else %>
                      <div
                        class="flex flex-col gap-1 cursor-pointer"
                        phx-click="highlight_clicked"
                        phx-value-id={highlight.id}
                        phx-value-node-id={highlight.node_id}
                      >
                        <div class="font-medium text-gray-600 truncate pr-12">
                          "{highlight.selected_text_snapshot}"
                        </div>
                        <%= if highlight.note && highlight.note != "" do %>
                          <div class="text-gray-500 italic truncate">
                            {highlight.note}
                          </div>
                        <% end %>
                        <div class="text-[10px] text-gray-400">
                          Node: {highlight.node_id}
                        </div>
                      </div>
                      <div class="absolute top-1 right-1 hidden group-hover:flex gap-1 bg-white/80 rounded">
                        <button
                          type="button"
                          data-copy-url={
                            DialecticWeb.Endpoint.url() <>
                              "/g/" <>
                              @graph_struct.slug <>
                              "?highlight=" <> to_string(highlight.id)
                          }
                          onclick="navigator.clipboard.writeText(this.dataset.copyUrl).then(() => alert('Link copied to clipboard!'))"
                          class="text-gray-400 hover:text-indigo-500 p-0.5 rounded"
                          title="Copy link to highlight"
                        >
                          <.icon name="hero-link" class="w-3 h-3" />
                        </button>
                        <%= if @current_user && @current_user.id == highlight.created_by_user_id do %>
                          <button
                            phx-click="edit_highlight"
                            phx-target={@myself}
                            phx-value-id={highlight.id}
                            class="text-gray-400 hover:text-indigo-500 p-0.5 rounded"
                            title="Edit note"
                          >
                            <.icon name="hero-pencil" class="w-3 h-3" />
                          </button>
                          <button
                            phx-click="delete_highlight"
                            phx-target={@myself}
                            phx-value-id={highlight.id}
                            class="text-gray-400 hover:text-red-500 p-0.5 rounded"
                            title="Delete highlight"
                          >
                            <.icon name="hero-trash" class="w-3 h-3" />
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </li>
                <% end %>
              </ul>
            <% else %>
              <p class="text-gray-400 italic px-1">No highlights yet.</p>
            <% end %>
          </div>
        </div>
      </div>

      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Download
        </div>
        <div class="p-1 space-y-2">
          <div class="flex flex-col gap-1.5">
            <button
              type="button"
              class="download-png w-full flex items-center justify-center px-2 py-1 rounded-md border border-green-200 bg-green-50 text-green-700 hover:bg-green-100 transition-colors text-xs"
              aria-label="Download PNG"
              title="Download PNG (Alt-click to capture full graph)"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3.5 w-3.5 mr-1"
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
              <span>Download PNG</span>
            </button>

            <.link
              navigate={graph_linear_path(@graph_struct)}
              target="_blank"
              rel="noopener noreferrer"
              class="w-full flex items-center justify-center px-2 py-1 rounded-md border border-red-200 bg-red-50 text-red-700 hover:bg-red-100 transition-colors text-xs"
              title="Open printable PDF"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3.5 w-3.5 mr-1"
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
              <span>Print to PDF</span>
            </.link>

            <.link
              href={
                if @graph_struct && @graph_struct.slug,
                  do: "/api/graphs/md/#{@graph_struct.slug}",
                  else: "/api/graphs/md/#{URI.encode(@graph_id)}"
              }
              download={
                if @graph_struct && @graph_struct.slug,
                  do: "#{@graph_struct.slug}.md",
                  else: "#{@graph_id}.md"
              }
              class="w-full flex items-center justify-center px-2 py-1 rounded-md border border-purple-200 bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors text-xs"
              title="Download Markdown"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3.5 w-3.5 mr-1"
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
              <span>Download Markdown</span>
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
