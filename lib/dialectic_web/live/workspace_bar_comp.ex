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
    <div
      id={@id}
      class="inline-flex max-w-full flex-wrap items-center gap-2 rounded-[1.35rem] border border-slate-200/90 bg-white/98 px-2 py-2 shadow-[0_14px_30px_-22px_rgba(15,23,42,0.45)]"
    >
      <div class="sr-only">Switch between reader and graph views</div>

      <div class="inline-flex items-center gap-1 rounded-[1rem] bg-slate-100 p-1 ring-1 ring-inset ring-slate-200/80">
        <div class="sr-only">Current view</div>
        <div class="sr-only">{if @mode == :reader, do: "Reader", else: "Graph"}</div>

        <div class="inline-flex items-center gap-1">
          <.link
            id={"#{@id}-reader"}
            navigate={@reader_path}
            data-view-transition="mode-switch"
            aria-current={if(@mode == :reader, do: "page", else: nil)}
            class={mode_link_classes(@mode == :reader)}
            title="Open reader view"
          >
            <.icon name="hero-document-text" class="h-4 w-4" />
            <span>Reader</span>
          </.link>

          <.link
            id={"#{@id}-graph"}
            navigate={@graph_path}
            data-view-transition="mode-switch"
            aria-current={if(@mode == :graph, do: "page", else: nil)}
            class={mode_link_classes(@mode == :graph)}
            title="Open graph view"
          >
            <.icon name="hero-squares-2x2" class="h-4 w-4" />
            <span>Graph</span>
          </.link>
        </div>
      </div>

      <div class="hidden h-6 w-px bg-slate-200 sm:block"></div>

      <div class="flex flex-wrap items-center gap-1">
        <button
          :if={@show_search}
          id={"#{@id}-search"}
          type="button"
          phx-click={@search_click}
          class={action_button_classes()}
          title="Search this graph"
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span>Search</span>
          <kbd class="hidden rounded-md border border-slate-200 bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-500 sm:inline-flex">
            ⌘K
          </kbd>
        </button>

        <button
          :if={@show_highlights}
          id={"#{@id}-highlights"}
          type="button"
          phx-click={@highlights_click}
          class={action_button_classes()}
          data-panel-toggle={@highlights_panel_id}
          title="Open highlights"
        >
          <.icon name="hero-bookmark" class="h-4 w-4" />
          <span>Highlights</span>
          <span
            :if={@highlights_count > 0}
            class="rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-semibold text-slate-600 ring-1 ring-inset ring-slate-200"
          >
            {@highlights_count}
          </span>
        </button>

        <button
          :if={@show_share}
          id={"#{@id}-share"}
          type="button"
          phx-click={@share_click}
          class={action_button_classes()}
          title="Share this graph"
        >
          <.icon name="hero-share" class="h-4 w-4" />
          <span>Share</span>
        </button>
      </div>
    </div>
    """
  end

  defp mode_link_classes(true) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold shadow-sm transition",
      "bg-white text-slate-950 ring-1 ring-slate-200/90"
    ]
  end

  defp mode_link_classes(false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold transition",
      "text-slate-500 hover:bg-white/90 hover:text-slate-900"
    ]
  end

  defp action_button_classes do
    [
      "inline-flex h-9 items-center gap-2 rounded-[0.95rem] border border-transparent px-3 text-sm font-medium text-slate-600 transition duration-150",
      "hover:border-slate-200 hover:bg-slate-50 hover:text-slate-900"
    ]
  end
end
