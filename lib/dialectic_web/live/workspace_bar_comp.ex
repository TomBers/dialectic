defmodule DialecticWeb.WorkspaceBarComp do
  use DialecticWeb, :html

  attr :id, :string, default: "workspace-bar"
  attr :mode, :atom, required: true
  attr :graph_struct, :map, required: true
  attr :node_id, :string, default: nil
  attr :nav_params, :list, default: []
  attr :show_search, :boolean, default: false
  attr :search_click, :any, default: nil
  attr :show_highlights, :boolean, default: true
  attr :highlights_click, :any, default: nil
  attr :highlights_count, :integer, default: 0
  attr :highlights_panel_id, :string, default: nil
  attr :show_share, :boolean, default: true
  attr :share_click, :any, default: nil
  attr :compact, :boolean, default: false

  def workspace_bar(assigns) do
    node_id =
      case assigns.node_id do
        nil -> nil
        value -> to_string(value)
      end

    assigns =
      assigns
      |> assign(:node_id, node_id)
      |> assign(:reader_path, graph_path(assigns.graph_struct, node_id, assigns.nav_params))
      |> assign(:graph_path, graph_editor_path(assigns.graph_struct, node_id, assigns.nav_params))

    ~H"""
    <div id={@id} class={bar_classes(@compact)}>
      <div class="sr-only">Workspace actions</div>

      <div class={segment_classes(@compact)}>
        <div class="sr-only">Switch between reader and grid views</div>
        <div class="sr-only">Current view</div>
        <div class="sr-only">{if @mode == :reader, do: "Reader", else: "Grid"}</div>

        <div class="inline-flex items-center gap-1">
          <.link
            id={"#{@id}-reader"}
            navigate={@reader_path}
            data-view-transition="mode-switch"
            data-view-transition-direction="reader"
            aria-current={if(@mode == :reader, do: "page", else: nil)}
            class={mode_link_classes(@mode == :reader, @compact)}
            title="Open reader view"
          >
            <.icon name="hero-document-text" class="h-4 w-4" />
            <span>Reader</span>
          </.link>

          <.link
            id={"#{@id}-graph"}
            navigate={@graph_path}
            data-view-transition="mode-switch"
            data-view-transition-direction="graph"
            aria-current={if(@mode == :graph, do: "page", else: nil)}
            class={mode_link_classes(@mode == :graph, @compact)}
            title="Open grid view"
          >
            <.icon name="hero-squares-2x2" class="h-4 w-4" />
            <span>Grid</span>
          </.link>
        </div>
      </div>

      <div class={divider_classes(@compact)}></div>

      <div class="ml-auto flex flex-wrap items-center gap-1 sm:ml-0">
        <button
          :if={@show_search}
          id={"#{@id}-search"}
          type="button"
          phx-click={@search_click}
          class={action_button_classes(@compact)}
          title="Search this grid"
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span class="hidden sm:inline">Search</span>
          <kbd class={kbd_classes(@compact)}>
            ⌘K
          </kbd>
        </button>

        <button
          :if={@show_highlights}
          id={"#{@id}-highlights"}
          type="button"
          phx-click={@highlights_click}
          class={[action_button_classes(@compact), "relative overflow-visible"]}
          data-panel-toggle={@highlights_panel_id}
          title="Open highlights"
          aria-label={
            if @highlights_count > 0 do
              "Open highlights. #{@highlights_count} saved highlights"
            else
              "Open highlights"
            end
          }
        >
          <.icon name="hero-bookmark" class="h-4 w-4" />
          <span class="hidden sm:inline">Highlights</span>
          <span
            :if={@highlights_count > 0}
            aria-hidden="true"
            class="absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-slate-900 px-1 text-[10px] font-semibold leading-none text-white ring-2 ring-white sm:static sm:ml-1 sm:h-auto sm:min-w-[1.25rem] sm:bg-slate-100 sm:px-2 sm:py-0.5 sm:text-[11px] sm:leading-none sm:text-slate-600 sm:ring-1 sm:ring-inset sm:ring-slate-200"
          >
            {@highlights_count}
          </span>
        </button>

        <button
          :if={@show_share}
          id={"#{@id}-share"}
          type="button"
          phx-click={@share_click}
          class={action_button_classes(@compact)}
          title="Share this grid"
        >
          <.icon name="hero-share" class="h-4 w-4" />
          <span class="hidden sm:inline">Share</span>
        </button>
      </div>
    </div>
    """
  end

  defp bar_classes(true) do
    [
      "flex w-full max-w-full items-center gap-2 rounded-[1.1rem] border border-slate-200/90 bg-white/98 px-1.5 py-1.5 shadow-[0_10px_24px_-20px_rgba(15,23,42,0.35)] sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:gap-1.5 sm:rounded-[1.25rem] sm:shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]"
    ]
  end

  defp bar_classes(false) do
    [
      "flex w-full max-w-full items-center gap-2 rounded-[1.2rem] border border-slate-200/90 bg-white/98 px-1.5 py-1.5 shadow-[0_10px_24px_-20px_rgba(15,23,42,0.35)] sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:rounded-[1.35rem] sm:px-2 sm:py-2 sm:shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]"
    ]
  end

  defp segment_classes(true) do
    "hidden items-center gap-1 rounded-[0.95rem] bg-slate-100 p-0.5 ring-1 ring-inset ring-slate-200/80 sm:inline-flex"
  end

  defp segment_classes(false) do
    "hidden items-center gap-1 rounded-[1rem] bg-slate-100 p-1 ring-1 ring-inset ring-slate-200/80 sm:inline-flex"
  end

  defp mode_link_classes(true, true) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.75rem] px-2.5 text-sm font-semibold shadow-sm transition",
      "bg-white text-slate-950 ring-1 ring-slate-200/90"
    ]
  end

  defp mode_link_classes(true, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold shadow-sm transition",
      "bg-white text-slate-950 ring-1 ring-slate-200/90"
    ]
  end

  defp mode_link_classes(false, true) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.75rem] px-2.5 text-sm font-semibold transition",
      "text-slate-500 hover:bg-white/90 hover:text-slate-900"
    ]
  end

  defp mode_link_classes(false, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold transition",
      "text-slate-500 hover:bg-white/90 hover:text-slate-900"
    ]
  end

  defp divider_classes(true) do
    "hidden h-5 w-px bg-slate-200 sm:block"
  end

  defp divider_classes(false) do
    "hidden h-6 w-px bg-slate-200 sm:block"
  end

  defp action_button_classes(true) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 text-sm font-medium text-slate-600 transition duration-150 sm:h-8 sm:w-auto sm:justify-start sm:rounded-[0.85rem] sm:border-transparent sm:bg-transparent sm:px-2.5",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 text-sm font-medium text-slate-600 transition duration-150 sm:w-auto sm:justify-start sm:rounded-[0.95rem] sm:border-transparent sm:bg-transparent sm:px-3",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end

  defp kbd_classes(true) do
    "hidden rounded-md border border-slate-200 bg-slate-100 px-1 py-0.5 text-[10px] font-semibold text-slate-500 sm:inline-flex"
  end

  defp kbd_classes(false) do
    "hidden rounded-md border border-slate-200 bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-500 sm:inline-flex"
  end
end
