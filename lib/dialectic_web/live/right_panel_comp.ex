defmodule DialecticWeb.RightPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Repo
  alias DialecticWeb.Utils.NodeTitleHelper

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
      |> assign_new(:prompt_mode, fn -> "university" end)
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
        # Preload links before deleting to avoid JSON encoding error during broadcast
        highlight = Repo.preload(highlight, :links)
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

  defp translate_targets do
    [
      {"English (en)", "en"},
      {"Spanish (es)", "es"},
      {"French (fr)", "fr"},
      {"German (de)", "de"},
      {"Portuguese (pt)", "pt"},
      {"Chinese Simplified (zh-CN)", "zh-CN"},
      {"Japanese (ja)", "ja"},
      {"Russian (ru)", "ru"},
      {"Arabic (ar)", "ar"},
      {"Hindi (hi)", "hi"}
    ]
  end

  defp google_translate_url(node, tl) do
    content =
      node
      |> Kernel.||(%{})
      |> Map.get(:content, "")
      |> to_string()

    base_url = "https://translate.google.com/?sl=auto&tl=#{tl}&text="
    suffix = "&op=translate"
    max_url_len = 2000
    max_text_encoded_len = max_url_len - String.length(base_url) - String.length(suffix)

    truncated = truncate_for_encoded_length(content, max_text_encoded_len)

    base_url <> URI.encode_www_form(truncated) <> suffix
  end

  # Truncates content so that URI.encode_www_form(result) fits within max_encoded_len.
  # Uses binary search on grapheme count to find the longest prefix that encodes within budget.
  defp truncate_for_encoded_length(content, max_encoded_len) do
    encoded = URI.encode_www_form(content)

    if String.length(encoded) <= max_encoded_len do
      content
    else
      total_graphemes = String.length(content)
      do_truncate_search(content, 0, total_graphemes, max_encoded_len)
    end
  end

  defp do_truncate_search(_content, low, high, _max_encoded_len) when low >= high do
    ""
  end

  defp do_truncate_search(content, low, high, max_encoded_len) when high - low <= 1 do
    candidate = String.slice(content, 0, low)

    if String.length(URI.encode_www_form(candidate)) <= max_encoded_len do
      candidate
    else
      ""
    end
  end

  defp do_truncate_search(content, low, high, max_encoded_len) do
    mid = div(low + high, 2)
    candidate = String.slice(content, 0, mid)
    encoded_len = String.length(URI.encode_www_form(candidate))

    if encoded_len <= max_encoded_len do
      do_truncate_search(content, mid, high, max_encoded_len)
    else
      do_truncate_search(content, low, mid, max_encoded_len)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="bg-white border border-gray-200 rounded-md">
        <div class="px-2 py-1 text-[11px] font-semibold text-gray-700">
          Translate
        </div>
        <div class="p-1">
          <div class="flex flex-wrap gap-1">
            <%= for {label, code} <- translate_targets() do %>
              <a
                href={google_translate_url(@node, code)}
                target="_blank"
                rel="noopener"
                class="inline-flex items-center px-2 py-1 rounded-md border border-gray-200 bg-gray-50 text-xs text-gray-700 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              >
                {label}
              </a>
            <% end %>
          </div>
          <p class="mt-1.5 text-[10px] text-gray-400">
            Opens Google Translate with the current node's content.
          </p>
        </div>
      </div>

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
                      {NodeTitleHelper.extract_node_title(node, max_length: 100)}
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
          Level
        </div>
        <div class="p-1">
          <div class="inline-flex rounded-lg bg-gray-50 p-1 border border-gray-200">
            <%= for {mode, label} <- [{"simple", "Simple"}, {"high_school", "High School"}, {"university", "University"}, {"expert", "Expert"}] do %>
              <button
                type="button"
                phx-click="set_prompt_mode"
                phx-value-prompt_mode={mode}
                class={[
                  "px-3 py-1.5 text-xs font-medium rounded-md transition-all duration-200",
                  if @prompt_mode == mode do
                    "bg-white text-indigo-700 shadow-sm scale-105"
                  else
                    "text-gray-600 hover:text-gray-900 hover:bg-white"
                  end
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
          <div class="mt-2 text-[11px] text-gray-600 space-y-1">
            <p>
              Adjusts the complexity and tone of AI responses.
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
              navigate={
                graph_linear_path(
                  @graph_struct,
                  if(@node, do: Map.get(@node, :id), else: nil),
                  if(assigns[:token], do: [token: assigns[:token]], else: [])
                )
              }
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
                path =
                  if @graph_struct && @graph_struct.slug,
                    do: "/api/graphs/md/#{@graph_struct.slug}",
                    else: "/api/graphs/md/#{URI.encode(@graph_id)}"

                if assigns[:token], do: "#{path}?token=#{assigns[:token]}", else: path
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
    </div>
    """
  end
end
