defmodule DialecticWeb.RightPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Repo

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
      |> assign_new(:open_sections, fn -> MapSet.new() end)

    {:ok, socket}
  end

  @valid_sections ~w(configure workspace export utilities)

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket)
      when section in @valid_sections do
    open_sections = socket.assigns.open_sections

    new_open_sections =
      if MapSet.member?(open_sections, section) do
        MapSet.delete(open_sections, section)
      else
        MapSet.put(open_sections, section)
      end

    {:noreply, assign(socket, :open_sections, new_open_sections)}
  end

  def handle_event("toggle_section", _params, socket) do
    # Ignore unknown section keys to prevent memory growth
    {:noreply, socket}
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

  defp encoded_node_text(node) do
    content =
      node
      |> Kernel.||(%{})
      |> Map.get(:content, "")
      |> to_string()

    # Use the longest target language code ("zh-CN", 5 chars) to compute a conservative max
    base_url = "https://translate.google.com/?sl=auto&tl=zh-CN&text="
    suffix = "&op=translate"
    max_url_len = 2000
    max_text_encoded_len = max_url_len - String.length(base_url) - String.length(suffix)

    truncated = truncate_for_encoded_length(content, max_text_encoded_len)
    URI.encode_www_form(truncated)
  end

  defp google_translate_url(encoded_text, tl) do
    "https://translate.google.com/?sl=auto&tl=#{tl}&text=#{encoded_text}&op=translate"
  end

  # Truncates content so that URI.encode_www_form(result) fits within max_encoded_len.
  # Uses binary search on grapheme count to find the longest prefix that encodes within budget.
  defp truncate_for_encoded_length(content, max_encoded_len) do
    encoded = URI.encode_www_form(content)

    if String.length(encoded) <= max_encoded_len do
      content
    else
      total_graphemes = String.length(content)
      # Start with an empty best candidate and search for the longest valid prefix.
      do_truncate_search(content, 0, total_graphemes, "", max_encoded_len)
    end
  end

  # Binary search helper that carries the best (longest valid) prefix found so far.
  defp do_truncate_search(_content, low, high, best, _max_encoded_len) when low >= high do
    best
  end

  defp do_truncate_search(content, low, high, best, max_encoded_len) do
    mid = div(low + high, 2)
    candidate = String.slice(content, 0, mid)
    encoded_len = String.length(URI.encode_www_form(candidate))

    if encoded_len <= max_encoded_len do
      # Candidate fits: it becomes the new best, and we try a longer prefix.
      do_truncate_search(content, mid + 1, high, candidate, max_encoded_len)
    else
      # Candidate too long: search the lower half without changing best.
      do_truncate_search(content, low, mid, best, max_encoded_len)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <%!-- Configure Section --%>
      <details
        id="details-configure"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "configure")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="configure"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-indigo-50 text-indigo-600">
                <.icon name="hero-adjustments-horizontal" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Language Level</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  AI response complexity level
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <div class="space-y-2">
            <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
              Explanation Level
            </div>
            <div class="flex flex-wrap gap-1.5">
              <%= for {mode, label} <- [{"simple", "Simple"}, {"high_school", "High School"}, {"university", "University"}, {"expert", "Expert"}] do %>
                <button
                  type="button"
                  phx-click="set_prompt_mode"
                  phx-value-prompt_mode={mode}
                  class={[
                    "px-3 py-1.5 text-xs font-medium rounded-lg transition-all duration-200 border",
                    if @prompt_mode == mode do
                      "bg-indigo-600 text-white border-indigo-600 shadow-sm"
                    else
                      "bg-white text-gray-600 border-gray-200 hover:border-gray-300 hover:bg-gray-50"
                    end
                  ]}
                >
                  {label}
                </button>
              <% end %>
            </div>
            <p class="text-[10px] text-gray-500">
              Adjusts the complexity and tone of AI responses.
            </p>
          </div>
        </div>
      </details>

      <%!-- Workspace Section --%>
      <details
        id="details-workspace"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "workspace")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="workspace"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-emerald-50 text-emerald-600">
                <.icon name="hero-folder" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Public/Private</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Groups and access settings
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5 space-y-3">
          <%!-- Groups subsection --%>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
                Groups ({length(@work_streams)})
              </div>
              <button
                type="button"
                phx-click="open_start_stream_modal"
                class="inline-flex items-center gap-1 text-[11px] font-medium text-indigo-600 hover:text-indigo-800 transition-colors"
              >
                <.icon name="hero-plus" class="w-3 h-3" /> New
              </button>
            </div>
            <div class="max-h-40 overflow-y-auto">
              <%= if @work_streams && length(@work_streams) > 0 do %>
                <ul class="space-y-1">
                  <%= for s <- @work_streams do %>
                    <li class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-md bg-gray-50 hover:bg-gray-100 transition-colors">
                      <span class="text-xs text-gray-700 truncate flex-1">{s.id}</span>
                      <div class="flex items-center gap-1">
                        <button
                          type="button"
                          phx-click="focus_stream"
                          phx-value-id={s.id}
                          class="px-2 py-1 rounded-md text-[10px] font-medium text-gray-600 hover:bg-white hover:text-gray-800 transition-colors"
                        >
                          Focus
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_stream"
                          phx-value-id={s.id}
                          class="px-2 py-1 rounded-md text-[10px] font-medium text-gray-600 hover:bg-white hover:text-gray-800 transition-colors"
                        >
                          Toggle
                        </button>
                        <%= if s.id != "Main" do %>
                          <button
                            type="button"
                            phx-click="delete_stream"
                            phx-value-id={s.id}
                            class="px-2 py-1 rounded-md text-[10px] font-medium text-red-600 hover:bg-red-50 hover:text-red-700 transition-colors"
                            title="Delete group (must be empty)"
                          >
                            <.icon name="hero-trash" class="w-3 h-3" />
                          </button>
                        <% end %>
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% else %>
                <p class="text-[11px] text-gray-400 text-center py-2">No groups yet</p>
              <% end %>
            </div>
          </div>

          <%!-- Access subsection (owner only) --%>
          <%= if owner?(@graph_struct, @current_user) do %>
            <div class="pt-2 border-t border-gray-100 space-y-2">
              <div class="text-[11px] font-medium text-gray-600 uppercase tracking-wide">
                Access
              </div>
              <DialecticWeb.LockComp.render id="lock-graph" graph_struct={@graph_struct} />
              <button
                phx-click="open_share_modal"
                class="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium border border-indigo-200 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition-colors"
              >
                <%= if @graph_struct.is_public do %>
                  <.icon name="hero-share" class="w-3.5 h-3.5" />
                  <span>Share Map</span>
                <% else %>
                  <.icon name="hero-user-plus" class="w-3.5 h-3.5" />
                  <span>Manage Collaborators</span>
                <% end %>
              </button>
            </div>
          <% end %>
        </div>
      </details>

      <%!-- Export Section --%>
      <details
        id="details-export"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "export")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="export"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-sky-50 text-sky-600">
                <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Export</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Download or print your graph
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <div class="grid grid-cols-1 gap-2">
            <button
              type="button"
              class="download-png flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              aria-label="Download PNG"
              title="Download PNG (Alt-click to capture full graph)"
            >
              <.icon name="hero-photo" class="w-4 h-4 text-emerald-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download PNG</div>
                <div class="text-[10px] text-gray-500">Image snapshot of graph</div>
              </div>
            </button>

            <.link
              navigate={
                graph_path(
                  @graph_struct,
                  if(@node, do: Map.get(@node, :id), else: nil),
                  if(assigns[:token], do: [token: assigns[:token]], else: [])
                )
              }
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Open printable PDF"
            >
              <.icon name="hero-printer" class="w-4 h-4 text-rose-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Print to PDF</div>
                <div class="text-[10px] text-gray-500">Printable reader view</div>
              </div>
            </.link>

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
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download Markdown"
            >
              <.icon name="hero-document-text" class="w-4 h-4 text-purple-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download Markdown</div>
                <div class="text-[10px] text-gray-500">Plain text with formatting</div>
              </div>
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
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download JSON (for image generation)"
            >
              <.icon name="hero-code-bracket" class="w-4 h-4 text-blue-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download JSON</div>
                <div class="text-[10px] text-gray-500">Minimal data for visualization</div>
              </div>
            </.link>
          </div>
        </div>
      </details>

      <%!-- Utilities Section --%>
      <details
        id="details-utilities"
        class="group rounded-lg border border-gray-200 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "utilities")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-gray-50/50 transition-colors"
          phx-click="toggle_section"
          phx-value-section="utilities"
          phx-target={@myself}
        >
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <div class="flex items-center justify-center w-7 h-7 rounded-md bg-orange-50 text-orange-600">
                <.icon name="hero-language" class="w-4 h-4" />
              </div>
              <div>
                <div class="text-xs font-semibold text-gray-800">Translate</div>
                <p class="text-[10px] text-gray-500 leading-tight">
                  Read this node in other languages
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-gray-400 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-gray-100 px-3 py-2.5">
          <% encoded_text = encoded_node_text(@node) %>
          <div class="flex flex-wrap gap-1.5">
            <%= for {label, code} <- translate_targets() do %>
              <a
                href={google_translate_url(encoded_text, code)}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center px-2.5 py-1.5 rounded-lg border border-gray-200 bg-white text-xs font-medium text-gray-700 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-900 transition-colors shadow-sm"
              >
                {label}
              </a>
            <% end %>
          </div>
          <p class="mt-2 text-[10px] text-gray-400">
            Opens Google Translate with the current node's content.
          </p>
        </div>
      </details>
    </div>
    """
  end
end
