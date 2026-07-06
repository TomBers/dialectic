defmodule DialecticWeb.WorkspaceBarComp do
  use DialecticWeb, :html

  attr :id, :string, default: "workspace-bar"
  attr :mode, :atom, required: true
  attr :graph_struct, :map, required: true
  attr :node_id, :string, default: nil
  attr :ask_node_id, :string, default: nil
  attr :nav_params, :list, default: []
  attr :show_search, :boolean, default: false
  attr :search_click, :any, default: nil
  attr :show_highlights, :boolean, default: true
  attr :highlights_click, :any, default: nil
  attr :highlights_count, :integer, default: 0
  attr :highlights_panel_id, :string, default: nil
  attr :show_share, :boolean, default: true
  attr :share_click, :any, default: nil
  attr :mobile_aux_id, :string, default: nil
  attr :mobile_aux_click, :any, default: nil
  attr :mobile_aux_open, :boolean, default: false
  attr :mobile_aux_label, :string, default: nil
  attr :mobile_aux_title, :string, default: nil
  attr :mobile_aux_icon, :string, default: "hero-bars-3-bottom-left"
  attr :mobile_aux_controls, :string, default: nil
  attr :compact, :boolean, default: false

  def workspace_bar(assigns) do
    node_id = normalize_node_id(assigns.node_id)
    ask_node_id = normalize_node_id(assigns.ask_node_id) || node_id

    assigns =
      assigns
      |> assign(:node_id, node_id)
      |> assign(:ask_node_id, ask_node_id)
      |> assign(:reader_path, graph_path(assigns.graph_struct, node_id, assigns.nav_params))
      |> assign(:graph_path, graph_editor_path(assigns.graph_struct, node_id, assigns.nav_params))
      |> assign(
        :ask_path,
        graph_editor_path(
          assigns.graph_struct,
          ask_node_id,
          [{"focus", "ask"} | assigns.nav_params]
        )
      )

    ~H"""
    <div id={@id} class={bar_classes(@compact)}>
      <div class="sr-only">Workspace actions</div>

      <div class={segment_classes(@compact)}>
        <div class="sr-only">Switch between read and edit views</div>
        <div class="sr-only">Current view</div>
        <div class="sr-only">{if @mode == :reader, do: "Read", else: "Edit"}</div>

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
            <span class={mode_label_classes(@compact)}>Read</span>
          </.link>

          <.link
            id={"#{@id}-graph"}
            navigate={@graph_path}
            data-view-transition="mode-switch"
            data-view-transition-direction="graph"
            aria-current={if(@mode == :graph, do: "page", else: nil)}
            class={mode_link_classes(@mode == :graph, @compact)}
            title="Open edit view"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4" />
            <span class={mode_label_classes(@compact)}>Edit</span>
          </.link>
        </div>
      </div>

      <div class={divider_classes(@compact)}></div>

      <div class="ml-auto flex flex-wrap items-center gap-1 sm:ml-0">
        <.link
          :if={@mode == :reader and is_binary(@ask_node_id) and @ask_node_id != ""}
          id={"#{@id}-ask-question"}
          navigate={@ask_path}
          data-view-transition="mode-switch"
          data-view-transition-direction="graph"
          class={ask_question_link_classes(@compact)}
          title="Ask a question from this point"
        >
          <.icon name="hero-question-mark-circle" class="h-4 w-4" />
          <span>Ask a question</span>
        </.link>

        <button
          :if={@mobile_aux_click && @mobile_aux_label}
          id={@mobile_aux_id}
          type="button"
          phx-click={@mobile_aux_click}
          class={[
            action_button_classes(@compact),
            "sm:hidden",
            @mobile_aux_open && "border-slate-300 bg-slate-100 text-slate-950"
          ]}
          title={@mobile_aux_title || @mobile_aux_label}
          aria-label={@mobile_aux_title || @mobile_aux_label}
          aria-controls={@mobile_aux_controls}
          aria-expanded={if(@mobile_aux_controls, do: to_string(@mobile_aux_open), else: nil)}
        >
          <.icon name={@mobile_aux_icon} class="h-4 w-4" />
          <span class="sr-only">{@mobile_aux_label}</span>
        </button>

        <button
          :if={@show_search}
          id={"#{@id}-search"}
          type="button"
          phx-click={@search_click}
          class={action_button_classes(@compact)}
          title={search_button_label(@mode)}
          aria-label={search_button_label(@mode)}
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span class={action_label_classes(@compact)}>Search</span>
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
          <span class={action_label_classes(@compact)}>Highlights</span>
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
          title={share_button_label(@mode)}
          aria-label={share_button_label(@mode)}
        >
          <.icon name="hero-share" class="h-4 w-4" />
          <span class={action_label_classes(@compact)}>Share</span>
        </button>
      </div>
    </div>
    """
  end

  defp normalize_node_id(nil), do: nil
  defp normalize_node_id(value), do: to_string(value)

  defp bar_classes(true) do
    [
      "flex w-full max-w-full items-center gap-1.5 rounded-[0.95rem] border border-indigo-200 bg-indigo-50/80 px-1 py-1 shadow-sm ring-1 ring-white/80 sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:gap-1 sm:rounded-[1.05rem]"
    ]
  end

  defp bar_classes(false) do
    [
      "flex w-full max-w-full items-center gap-2 rounded-[1.2rem] border border-indigo-200 bg-indigo-50/80 px-1.5 py-1.5 shadow-sm ring-1 ring-white/80 sm:inline-flex sm:w-auto sm:flex-wrap sm:justify-start sm:rounded-[1.35rem] sm:px-2 sm:py-2"
    ]
  end

  defp segment_classes(true) do
    "hidden items-center gap-0.5 rounded-[0.8rem] bg-white/90 p-0.5 ring-1 ring-inset ring-indigo-200 sm:inline-flex"
  end

  defp segment_classes(false) do
    "hidden items-center gap-1 rounded-[1rem] bg-white/90 p-1 ring-1 ring-inset ring-indigo-200 sm:inline-flex"
  end

  defp mode_link_classes(true, true) do
    [
      "inline-flex h-7 items-center gap-1.5 rounded-[0.65rem] px-2 text-xs font-semibold shadow-sm transition",
      "bg-indigo-600 text-white ring-1 ring-indigo-600"
    ]
  end

  defp mode_link_classes(true, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold shadow-sm transition",
      "bg-indigo-600 text-white ring-1 ring-indigo-600"
    ]
  end

  defp mode_link_classes(false, true) do
    [
      "inline-flex h-7 items-center gap-1.5 rounded-[0.65rem] px-2 text-xs font-semibold transition",
      "text-indigo-700 hover:bg-indigo-100 hover:text-indigo-900"
    ]
  end

  defp mode_link_classes(false, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-[0.8rem] px-3 text-sm font-semibold transition",
      "text-indigo-700 hover:bg-indigo-100 hover:text-indigo-900"
    ]
  end

  defp ask_question_link_classes(true) do
    [
      "hidden h-8 shrink-0 items-center justify-center gap-1.5 rounded-full bg-slate-950 px-3 text-xs font-semibold text-white shadow-sm transition md:inline-flex",
      "hover:bg-slate-800"
    ]
  end

  defp ask_question_link_classes(false) do
    [
      "hidden h-9 shrink-0 items-center justify-center gap-1.5 rounded-full bg-slate-950 px-3.5 text-sm font-semibold text-white shadow-sm transition md:inline-flex",
      "hover:bg-slate-800"
    ]
  end

  defp mode_label_classes(true), do: "hidden lg:inline"
  defp mode_label_classes(false), do: "inline"

  defp divider_classes(true) do
    "hidden h-4 w-px bg-slate-300 sm:block"
  end

  defp divider_classes(false) do
    "hidden h-6 w-px bg-slate-300 sm:block"
  end

  defp action_button_classes(true) do
    [
      "inline-flex h-8 w-8 shrink-0 items-center justify-center gap-1 rounded-full border border-slate-200 bg-white text-xs font-semibold text-slate-700 transition duration-150 sm:h-7 sm:w-auto sm:justify-start sm:rounded-[0.7rem] sm:border-slate-200 sm:px-2.5",
      "hover:border-slate-300 hover:bg-white hover:text-slate-950"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-full border border-slate-200 bg-white text-sm font-semibold text-slate-700 transition duration-150 sm:w-auto sm:justify-start sm:rounded-[0.95rem] sm:border-slate-200 sm:px-3",
      "hover:border-slate-300 hover:bg-white hover:text-slate-950"
    ]
  end

  defp action_label_classes(true), do: "hidden xl:inline"
  defp action_label_classes(false), do: "hidden sm:inline"

  defp kbd_classes(true) do
    "hidden rounded-md border border-slate-200 bg-slate-100 px-1 py-0.5 text-[9px] font-semibold text-slate-500 2xl:inline-flex"
  end

  defp kbd_classes(false) do
    "hidden rounded-md border border-slate-200 bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-500 sm:inline-flex"
  end

  defp search_button_label(:reader), do: "Search topics"
  defp search_button_label(:graph), do: "Search this grid"
  defp search_button_label(_mode), do: "Search"

  defp share_button_label(:reader), do: "Share this reader view"
  defp share_button_label(:graph), do: "Share this grid view"
  defp share_button_label(_mode), do: "Share this view"
end
