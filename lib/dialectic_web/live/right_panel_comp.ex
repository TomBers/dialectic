defmodule DialecticWeb.RightPanelComp do
  use DialecticWeb, :live_component
  alias Dialectic.Repo

  @moduledoc """
  Accordion-style right panel with:
  - Node Information (shareable link + exports)
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
      |> assign_new(:prompt_mode, fn -> "university" end)
      |> assign_new(:layout_target, fn -> "#graph-layout" end)
      |> assign_new(:mode, fn -> :graph end)
      |> assign_new(:reader_style, fn -> "screen" end)
      |> assign_new(:following_graph?, fn -> false end)
      |> assign_new(:current_user, fn -> nil end)
      |> assign_new(:highlights, fn -> [] end)
      |> assign_new(:highlights_count, fn -> 0 end)
      |> assign_new(:editing_highlight_id, fn -> nil end)
      |> assign_new(:open_sections, fn -> MapSet.new() end)
      |> maybe_open_section(Map.get(assigns, :open_section))

    {:ok, socket}
  end

  defp maybe_open_section(socket, section)
       when section in ["workspace", "answer-level", "visibility"] do
    update(socket, :open_sections, &MapSet.put(&1, section))
  end

  defp maybe_open_section(socket, _section), do: socket

  @valid_sections ~w(workspace activity export utilities answer-level visibility)

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

    socket = assign(socket, :open_sections, new_open_sections)

    {:noreply, socket}
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
      <p class="px-3 pb-2 pt-1 text-xs font-semibold uppercase tracking-wide text-slate-600">
        Your reading
      </p>
      <button
        id="more-saved-highlights"
        type="button"
        phx-click={
          Phoenix.LiveView.JS.dispatch("toggle-panel",
            to: @layout_target,
            detail: %{id: "highlights-drawer", open: true}
          )
        }
        data-panel-toggle="highlights-drawer"
        aria-controls="highlights-drawer"
        aria-expanded="false"
        class="flex min-h-11 w-full items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-stone-100"
      >
        <.icon name="hero-bookmark" class="h-4 w-4 text-slate-600" /> Saved highlights
        <span class="ml-auto text-xs text-slate-600">{@highlights_count}</span>
      </button>
      <section
        id="reading-style-options"
        aria-labelledby="reading-style-heading"
        class="rounded-lg border border-stone-300 bg-white"
      >
        <h3
          id="reading-style-heading"
          tabindex="-1"
          class="px-3 py-2.5 text-xs font-semibold text-gray-800"
        >
          Reading options
        </h3>
        <div class="grid grid-cols-2 gap-1.5 border-t border-stone-300 p-2">
          <button
            :for={
              {label, description, style} <- [
                {"Book", "Serif · comfortable", "book"},
                {"Screen", "Sans · comfortable", "screen"},
                {"Large print", "Sans · larger text", "large_print"},
                {"Compact", "Sans · tighter spacing", "compact"}
              ]
            }
            id={"reader-style-#{style}"}
            type="button"
            phx-click="save_reader_appearance"
            phx-value-style={style}
            aria-pressed={to_string(@reader_style == style)}
            class="min-h-11 rounded-lg border border-stone-300 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-stone-100 aria-pressed:border-teal-700 aria-pressed:bg-teal-800 aria-pressed:text-white"
          >
            <span class="block">{label}</span>
            <span class="mt-0.5 block text-[11px] font-normal">{description}</span>
          </button>
        </div>
      </section>

      <p class="px-3 pb-1 pt-5 text-xs font-semibold uppercase tracking-wide text-slate-600">
        This grid
      </p>
      <button
        :if={@current_user}
        id="reader-tools-follow"
        type="button"
        phx-click={if(@following_graph?, do: "unfollow_graph", else: "follow_graph")}
        aria-pressed={to_string(@following_graph?)}
        class="flex min-h-11 w-full items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-stone-100"
      >
        <.icon name="hero-bell" class="h-4 w-4 text-slate-600" />
        {if(@following_graph?, do: "Following this grid", else: "Follow this grid")}
      </button>
      <.link
        :if={!@current_user}
        id="reader-tools-follow-login"
        navigate={~p"/users/log_in"}
        class="flex min-h-11 items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium text-slate-700 hover:bg-stone-100"
      >
        <.icon name="hero-bell" class="h-4 w-4 text-slate-600" /> Sign in to follow this grid
      </.link>
      <button
        :if={@mode == :graph}
        id="grid-tools-presentation"
        type="button"
        phx-click={
          Phoenix.LiveView.JS.dispatch("toggle-side-drawer",
            to: @layout_target,
            detail: %{force: "close", persist: false}
          )
          |> Phoenix.LiveView.JS.dispatch("toggle-panel",
            to: @layout_target,
            detail: %{id: "presentation-drawer", open: true}
          )
          |> Phoenix.LiveView.JS.push("enter_presentation_setup")
        }
        disabled={is_nil(@graph_id)}
        data-panel-toggle="presentation-drawer"
        class="hidden w-full items-center gap-2.5 rounded-lg border border-stone-300 bg-white px-3 py-2.5 text-left shadow-sm transition hover:bg-stone-100 disabled:cursor-not-allowed disabled:opacity-45 md:flex"
        aria-label="Start presentation setup"
      >
        <span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-violet-50 text-violet-600">
          <.icon name="hero-presentation-chart-bar" class="h-4 w-4" />
        </span>
        <span class="flex-1">
          <span class="block text-xs font-semibold text-gray-800">Presentation</span>
          <span class="block text-[11px] leading-tight text-gray-500">Build and present a slide deck</span>
        </span>
        <.icon name="hero-chevron-right" class="h-4 w-4 text-slate-600" />
      </button>

      <%!-- Export Section --%>
      <details
        id="details-export"
        class="group rounded-lg border border-stone-300 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "export")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-stone-100/50 transition-colors"
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
                <div class="text-xs font-semibold text-gray-800">Download</div>
                <p class="text-[11px] text-gray-500 leading-tight">
                  Download your grid
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-slate-600 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-stone-300 px-3 py-2.5">
          <div class="grid grid-cols-1 gap-2">
            <button
              :if={@mode == :graph}
              type="button"
              class="download-png flex items-center gap-2 px-3 py-2 rounded-lg border border-stone-300 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              aria-label="Download PNG"
              title="Download PNG (Alt-click to capture full graph)"
            >
              <.icon name="hero-photo" class="w-4 h-4 text-emerald-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download PNG</div>
                <div class="text-[11px] text-gray-500">Image snapshot of graph</div>
              </div>
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
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-stone-300 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download Markdown"
            >
              <.icon name="hero-document-text" class="w-4 h-4 text-purple-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download Markdown</div>
                <div class="text-[11px] text-gray-500">Plain text with formatting</div>
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
              class="flex items-center gap-2 px-3 py-2 rounded-lg border border-stone-300 bg-gray-50 hover:bg-gray-100 hover:border-gray-300 transition-colors"
              title="Download JSON (for image generation)"
            >
              <.icon name="hero-code-bracket" class="w-4 h-4 text-blue-600" />
              <div class="flex-1 text-left">
                <div class="text-xs font-medium text-gray-800">Download JSON</div>
                <div class="text-[11px] text-gray-500">Minimal data for visualization</div>
              </div>
            </.link>
          </div>
        </div>
      </details>

      <%!-- Utilities Section --%>
      <details
        id="details-utilities"
        class="group rounded-lg border border-stone-300 bg-white shadow-sm hover:shadow transition-shadow"
        open={MapSet.member?(@open_sections, "utilities")}
      >
        <summary
          class="list-none cursor-pointer select-none px-3 py-2.5 rounded-lg hover:bg-stone-100/50 transition-colors"
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
                <div class="text-xs font-semibold text-gray-800">Translate this idea</div>
                <p class="text-[11px] text-gray-500 leading-tight">
                  Read the selected idea in another language
                </p>
              </div>
            </div>
            <.icon
              name="hero-chevron-down"
              class="w-4 h-4 text-slate-600 transition-transform duration-200 group-open:rotate-180"
            />
          </div>
        </summary>
        <div class="border-t border-stone-300 px-3 py-2.5">
          <% encoded_text = encoded_node_text(@node) %>
          <div class="flex flex-wrap gap-1.5">
            <%= for {label, code} <- translate_targets() do %>
              <a
                href={google_translate_url(encoded_text, code)}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center px-2.5 py-1.5 rounded-lg border border-stone-300 bg-white text-xs font-medium text-gray-700 hover:bg-stone-100 hover:border-gray-300 hover:text-gray-900 transition-colors shadow-sm"
              >
                {label}
              </a>
            <% end %>
          </div>
          <p class="mt-2 text-[11px] text-slate-600">
            Opens Google Translate with the selected idea’s content.
          </p>
        </div>
      </details>
      <button
        :if={@mode == :graph}
        id="graph-help-button"
        type="button"
        phx-click="open_help_modal"
        class="flex min-h-11 w-full items-center gap-2.5 rounded-lg border border-stone-300 px-3 py-2.5 text-xs font-semibold text-gray-800 hover:bg-stone-100"
        aria-label="Open how-to guide for this page"
      >
        <.icon name="hero-question-mark-circle" class="h-4 w-4 text-gray-500" /> How to use
      </button>
    </div>
    """
  end
end
