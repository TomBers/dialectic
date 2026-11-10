defmodule DialecticWeb.WorkspaceBarComp do
  use DialecticWeb, :html
  alias DialecticWeb.ColUtils

  attr :id, :string, required: true

  def contribution_sign_in(assigns) do
    ~H"""
    <section id={@id} class="rounded-xl border border-stone-300 bg-[#f4f1e9] p-4">
      <h3 class="text-sm font-semibold text-slate-950">Continue your thinking</h3>
      <p class="mt-1 text-sm leading-6 text-slate-700">
        Anyone can read this grid. Sign in to ask questions, post thoughts and use the thinking tools.
      </p>
      <div class="mt-3 flex flex-wrap items-center gap-4">
        <.link
          id={@id <> "-register"}
          href={~p"/users/register"}
          class="inline-flex min-h-11 items-center justify-center rounded-lg bg-teal-800 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-800"
        >Create a free account</.link>
        <.link
          id={@id <> "-login"}
          href={~p"/users/log_in"}
          class="inline-flex min-h-11 items-center text-sm font-semibold text-teal-800 underline underline-offset-4"
        >Sign in</.link>
      </div>
    </section>
    """
  end

  attr :mode, :atom, required: true, values: [:reader, :graph]
  attr :graph_struct, :map, required: true
  attr :node_id, :string, default: nil
  attr :nav_params, :list, default: []
  attr :layout_target, :string, required: true
  attr :current_user, :any, required: true
  attr :following_graph?, :boolean, required: true
  attr :highlights_count, :integer, default: 0
  attr :prompt_mode, :string, default: nil
  attr :return_context, :map, default: nil

  def workspace_header(assigns) do
    assigns =
      assigns
      |> assign(:prefix, if(assigns.mode == :reader, do: "reader", else: "graph"))
      |> assign(
        :return_context,
        assigns.return_context || %{path: "/community", label: "Community"}
      )

    ~H"""
    <header id={@prefix <> "-header"} class="workspace-header">
      <h1 id={@prefix <> "-title"} class="sr-only">{@graph_struct.title}</h1>
      <nav id={@prefix <> "-top-menu"} aria-label="Grid actions" class="workspace-menu">
        <.workspace_bar
          id={@prefix <> "-workspace-bar"}
          mode={@mode}
          graph_struct={@graph_struct}
          node_id={@node_id}
          nav_params={@nav_params}
          show_search
          search_click="open_search_overlay_click"
          show_highlights={false}
          show_share={false}
          compact
        />
        <div class="workspace-context-actions">
          <.grid_history_button id={@prefix <> "-grid-history"} layout_target={@layout_target} />
          <button
            id={@prefix <> "-workspace-bar-share"}
            type="button"
            phx-click="open_share_modal"
            data-analytics-event="grid_share_opened"
            data-analytics-location="workspace_bar"
            aria-label="Share grid"
            title="Share grid"
            class="workspace-action workspace-icon-action workspace-share"
          >
            <.icon name="hero-share" class="h-4 w-4" />
          </button>
          <button
            id={@prefix <> "-more"}
            type="button"
            phx-click={JS.dispatch("toggle-panel", to: @layout_target, detail: %{id: "right-panel"})}
            data-panel-toggle="right-panel"
            aria-controls="right-panel"
            aria-expanded="false"
            class="workspace-action hidden sm:inline-flex"
          >
            <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" /><span>More</span>
          </button>
        </div>
        <.link
          id={@prefix <> "-header-close-link"}
          navigate={@return_context.path}
          title={"Close grid and return to #{@return_context.label}"}
          aria-label={"Close grid and return to #{@return_context.label}"}
          class="workspace-action workspace-icon-action"
        >
          <.icon name="hero-x-mark" class="h-5 w-5" />
          <span class="sr-only">Close grid and return to {@return_context.label}</span>
        </.link>
      </nav>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :layout_target, :string, required: true
  attr :class, :string, default: nil

  defp grid_history_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-click={
        JS.dispatch("toggle-panel",
          to: @layout_target,
          detail: %{id: "grid-history-panel"}
        )
        |> JS.push("open_grid_history")
      }
      data-panel-toggle="grid-history-panel"
      aria-controls="grid-history-panel"
      aria-expanded="false"
      aria-label="Grid history: see how this grid was built"
      title="See how this grid was built and who contributed"
      class={[
        "workspace-action workspace-icon-action workspace-history",
        @class
      ]}
    >
      <.icon name="hero-clock" class="h-4 w-4" />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :layout_target, :string, required: true
  attr :mode, :atom, default: :graph, values: [:reader, :graph]
  attr :title, :string, default: "More"
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def tools_drawer(assigns) do
    ~H"""
    <div
      id={@id}
      data-right-drawer
      role="region"
      aria-labelledby={@id <> "-title"}
      tabindex="-1"
      class={[
        "tools-drawer right-0 z-50 flex w-0 flex-col overflow-hidden border-l border-stone-400 bg-white opacity-0 transform translate-x-full transition-all duration-300 ease-in-out",
        if(@mode == :reader,
          do: "fixed bottom-0 top-10 lg:absolute lg:top-0",
          else: "absolute inset-y-0"
        )
      ]}
    >
      <div class="tools-drawer-header flex shrink-0 items-center justify-between gap-2 border-b border-slate-950 bg-slate-950 px-3 py-2">
        <div>
          <h2 id={@id <> "-title"} class="text-base font-semibold text-white">{@title}</h2>
          <p :if={@subtitle} class="mt-1 text-xs leading-5 text-stone-300">{@subtitle}</p>
        </div>
        <button
          id={@id <> "-close"}
          data-panel-close
          type="button"
          phx-click={JS.dispatch("toggle-panel", to: @layout_target, detail: %{id: @id})}
          class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-slate-600 text-white hover:bg-slate-800"
          aria-label={"Close #{@title}"}
        >
          <.icon name="hero-x-mark" class="h-4 w-4" />
        </button>
      </div>
      <div class="tools-drawer-content min-h-0 flex-1 overflow-y-auto p-2">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

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

    assigns =
      assigns
      |> assign(:node_id, node_id)
      |> assign(:reader_path, graph_path(assigns.graph_struct, node_id, assigns.nav_params))
      |> assign(:graph_path, graph_editor_path(assigns.graph_struct, node_id, assigns.nav_params))

    ~H"""
    <div id={@id} class={bar_classes(@compact)}>
      <div class="sr-only">Workspace actions</div>

      <div class={segment_classes(@compact)} role="group" aria-label="Choose grid view">
        <div class="sr-only">Switch between read and grid views</div>
        <div class="sr-only">Current view</div>
        <div class="sr-only">{if @mode == :reader, do: "Read", else: "Grid"}</div>

        <div class="inline-flex items-center gap-1">
          <.link
            id={"#{@id}-reader"}
            navigate={@reader_path}
            data-view-transition="mode-switch"
            data-view-transition-direction="reader"
            aria-current={if(@mode == :reader, do: "page", else: nil)}
            class={mode_link_classes(@mode == :reader, @compact)}
            title="Open reader view"
            aria-label="Read view"
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
            title="Explore the grid"
            aria-label="Grid view"
          >
            <img src={~p"/images/favicon-32.png"} alt="" class="h-4 w-4" />
            <span class={mode_label_classes(@compact)}>Grid</span>
          </.link>
        </div>
      </div>

      <div class={divider_classes(@compact)}></div>

      <div class="ml-auto flex shrink-0 flex-nowrap items-center gap-1 sm:ml-0">
        <button
          :if={@mobile_aux_click && @mobile_aux_label}
          id={@mobile_aux_id}
          type="button"
          phx-click={@mobile_aux_click}
          class={[
            action_button_classes(@compact),
            "lg:hidden",
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
          class={search_button_classes(@compact)}
          title={search_button_label(@mode) <> " (⌘K / Ctrl+K)"}
          aria-keyshortcuts="Meta+K Control+K"
          aria-label={search_button_label(@mode)}
        >
          <.icon name="hero-magnifying-glass" class="h-4 w-4" />
          <span class={if(@compact, do: "hidden sm:inline", else: "hidden sm:inline")}>
            Search
          </span>
          <kbd class={kbd_classes(@compact)}>
            ⌘K
          </kbd>
        </button>

        <button
          :if={@show_highlights}
          id={"#{@id}-highlights"}
          type="button"
          phx-click={@highlights_click}
          class={highlights_button_classes(@compact)}
          data-panel-toggle={@highlights_panel_id}
          aria-controls={@highlights_panel_id}
          aria-expanded={if(@highlights_panel_id, do: "false")}
          title="Open highlights"
          aria-label={
            if @highlights_count > 0 do
              "Open highlights. #{@highlights_count} saved highlights"
            else
              "Open highlights"
            end
          }
        >
          <.icon name="hero-pencil" class="h-4 w-4" />
          <span class={highlights_label_classes(@compact)}>Highlights</span>
          <span
            :if={@highlights_count > 0}
            aria-hidden="true"
            class={highlight_count_classes(@compact)}
          >
            {if(@compact && @highlights_count > 99, do: "99+", else: @highlights_count)}
          </span>
        </button>

        <.share_button
          :if={@show_share}
          id={@id <> "-share"}
          mode={@mode}
          click={@share_click}
          compact={@compact}
        />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :mode, :atom, required: true
  attr :click, :any, required: true
  attr :compact, :boolean, default: false

  defp share_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      phx-click={@click}
      data-analytics-event="grid_share_opened"
      data-analytics-location="workspace_bar"
      class={action_button_classes(@compact)}
      title={share_button_label(@mode)}
      aria-label={share_button_label(@mode)}
    >
      <.icon name="hero-share" class="h-4 w-4" />
      <span class={action_label_classes(@compact)}>Share</span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :prompt_mode, :string, required: true
  attr :current_user, :any, required: true
  attr :field, :any, default: nil
  attr :heading, :string, default: "Next AI answer"

  attr :hint, :string,
    default: "Applies to new AI answers. Existing answers keep their original level."

  def answer_level_dropdown(assigns) do
    level =
      case assigns.prompt_mode do
        mode when mode in ["simple", "high_school"] -> "high_school"
        "expert" -> "expert"
        _ -> "university"
      end

    assigns =
      assign(assigns,
        level: level,
        levels: [
          %{
            mode: "high_school",
            label: "Simple",
            icon: "hero-light-bulb",
            description: "Plain language and examples"
          },
          %{
            mode: "university",
            label: "Expanded",
            icon: "hero-book-open",
            description: "Context and evidence"
          },
          %{
            mode: "expert",
            label: "In-depth",
            icon: "hero-academic-cap",
            description: "Detailed analysis"
          }
        ]
      )

    ~H"""
    <div
      id={@id}
      phx-hook="AnswerLevelDropdown"
      phx-update="ignore"
      data-answer-level-dropdown
      data-prompt-mode={@level}
      class="contents"
    >
      <input
        :if={@field}
        id={@id <> "-input"}
        name={@field.name}
        type="hidden"
        value={@level}
        data-answer-level-input
      />
      <button
        id={@id <> "-toggle"}
        type="button"
        data-answer-level-toggle
        aria-controls={@id <> "-options"}
        aria-expanded="false"
        aria-label={"Change AI answer level. Current level: #{answer_level_label(@level)}"}
        class="inline-flex min-h-11 items-center gap-1 rounded-md px-2 text-[11px] font-normal text-slate-600 hover:bg-stone-100 hover:text-slate-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-800"
      >
        <span
          :for={level <- @levels}
          data-answer-level-icon={level.mode}
          hidden={level.mode != @level}
          class="shrink-0"
          aria-hidden="true"
        ><.icon name={level.icon} class="h-3.5 w-3.5" /></span>
        <span data-answer-level-label>{answer_level_label(@level)}</span>
        <.icon name="hero-chevron-down" class="h-3 w-3" />
      </button>
      <div
        id={@id <> "-options"}
        data-answer-level-options
        hidden
        class="order-last min-w-0 basis-full rounded-xl border border-stone-300 bg-stone-50 p-1.5 text-slate-950"
      >
        <p id={@id <> "-heading"} class="px-2.5 py-1.5 text-xs font-semibold text-slate-500">
          {@heading}
        </p>
        <div
          role="listbox"
          aria-labelledby={@id <> "-heading"}
          aria-describedby={@id <> "-hint"}
          class="grid grid-cols-[repeat(auto-fit,minmax(min(100%,12rem),1fr))] gap-1"
        >
          <button
            :for={level <- @levels}
            id={@id <> "-" <> level.mode}
            type="button"
            role="option"
            tabindex={if(level.mode == @level, do: "0", else: "-1")}
            aria-selected={to_string(level.mode == @level)}
            aria-label={level.label}
            phx-click={if(is_nil(@field), do: "set_prompt_mode")}
            phx-value-prompt_mode={if(is_nil(@field), do: level.mode)}
            data-answer-level-choice={level.mode}
            class="flex min-h-14 w-full items-center gap-3 rounded-lg px-2.5 py-2 text-left hover:bg-stone-100 focus-visible:outline-2 focus-visible:outline-teal-800 aria-selected:bg-slate-950 aria-selected:text-white"
          >
            <span class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-teal-800 text-white"><.icon
              name={level.icon}
              class="h-4 w-4"
            /></span>
            <span class="min-w-0 flex-1">
              <span class="block text-sm font-semibold">{level.label}</span>
              <span class="answer-level-description mt-0.5 block text-xs leading-4 text-slate-600">{level.description}</span>
              <span
                :if={!@current_user && level.mode != "high_school"}
                class="answer-level-description block text-xs text-slate-600"
              >Sign in to use</span>
            </span>
            <span data-answer-level-check hidden={level.mode != @level} aria-hidden="true"><.icon
              name="hero-check"
              class="h-4 w-4 shrink-0 text-teal-200"
            /></span>
          </button>
        </div>
        <p
          id={@id <> "-hint"}
          class="mt-1 border-t border-slate-100 px-2.5 pt-2 pb-1 text-xs leading-5 text-slate-500"
        >
          {@hint}
        </p>
      </div>
    </div>
    """
  end

  def answer_level_label(mode) when mode in ["simple", "high_school"], do: "Simple"
  def answer_level_label("expert"), do: "In-depth"
  def answer_level_label(_mode), do: "Expanded"

  attr :id, :string, required: true
  attr :graph_struct, :map, required: true
  attr :current_user, :any, required: true
  attr :compact, :boolean, default: false
  attr :inline, :boolean, default: false
  attr :hide_heading, :boolean, default: false

  def visibility_dropdown(assigns) do
    assigns =
      assign(
        assigns,
        :owner?,
        assigns.current_user && assigns.graph_struct.user_id == assigns.current_user.id
      )

    ~H"""
    <div
      id={@id <> "-dropdown"}
      phx-hook={if(!@inline, do: "WorkspaceDropdown")}
      class="workspace-dropdown"
    >
      <button
        :if={!@inline}
        id={@id}
        type="button"
        popovertarget={@id <> "-options"}
        aria-controls={@id <> "-options"}
        aria-expanded="false"
        aria-haspopup="dialog"
        aria-label={"Grid visibility: #{if(@graph_struct.is_public, do: "Public", else: "Private")}"}
        title="View visibility settings"
        class={dropdown_trigger_classes(@compact, :visibility)}
      >
        <.icon
          name={if(@graph_struct.is_public, do: "hero-globe-alt", else: "hero-lock-closed")}
          class="h-4 w-4 shrink-0"
        />
        <span class={if(@compact, do: "hidden md:inline", else: "flex-1 text-left")}>
          {if(@graph_struct.is_public, do: "Public", else: "Private")}
        </span>
        <.icon name="hero-chevron-down" class="h-3 w-3 shrink-0" />
      </button>
      <div
        id={if(@inline, do: @id, else: @id <> "-options")}
        popover={if(!@inline, do: "auto")}
        tabindex="-1"
        role={if(@inline, do: "group", else: "dialog")}
        aria-labelledby={@id <> "-heading"}
        class={if(@inline, do: "workspace-settings-section", else: "workspace-dropdown-panel")}
      >
        <h2
          id={@id <> "-heading"}
          class={if(@hide_heading, do: "sr-only", else: "workspace-dropdown-heading")}
        >
          <span class="workspace-dropdown-heading-icon">
            <.icon
              name={if(@graph_struct.is_public, do: "hero-globe-alt", else: "hero-lock-closed")}
              class="h-4 w-4"
            />
          </span>
          Visibility
        </h2>
        <%= if @owner? do %>
          <button
            :for={
              {value, label, description} <- [
                {"public", "Public", "Anyone can find and view this grid."},
                {"private", "Private",
                 "Only you, invited collaborators, and people with a shared access link can view it."}
              ]
            }
            id={@id <> "-" <> value}
            type="button"
            phx-click="set_graph_visibility"
            phx-value-visibility={value}
            data-dropdown-choice={if(!@inline, do: "")}
            aria-pressed={to_string(@graph_struct.is_public == (value == "public"))}
            class="workspace-dropdown-choice"
          >
            <span class="workspace-dropdown-option-icon">
              <.icon
                name={if(value == "public", do: "hero-globe-alt", else: "hero-lock-closed")}
                class="h-4 w-4"
              />
            </span>
            <span class="min-w-0 flex-1">
              <span class="workspace-dropdown-option-title">{label}</span>
              <span class="mt-1 block text-xs leading-5 text-slate-500">{description}</span>
            </span>
            <span class="workspace-dropdown-check">
              <.icon
                :if={@graph_struct.is_public == (value == "public")}
                name="hero-check"
                class="h-4 w-4"
              />
            </span>
          </button>
        <% else %>
          <p class="px-3 py-2 text-xs leading-5 text-slate-600">
            {if(@graph_struct.is_public,
              do: "Anyone can find and view this grid.",
              else: "You have access to this private grid."
            )} Only the owner can change visibility.
          </p>
        <% end %>
        <p class="workspace-dropdown-footer">
          <.icon name="hero-information-circle" class="mt-0.5 h-3.5 w-3.5 shrink-0" />
          <span>Controls who can find and view this grid.</span>
        </p>
      </div>
    </div>
    """
  end

  defp dropdown_trigger_classes(compact, kind) do
    [
      "inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white text-xs font-semibold text-slate-700 hover:bg-slate-50",
      if(compact, do: "h-9 w-11", else: "min-h-11 w-full px-3 py-2"),
      compact && if(kind == :level, do: "md:w-[7.5rem]", else: "md:w-[6.25rem]")
    ]
  end

  defp normalize_node_id(nil), do: nil
  defp normalize_node_id(value), do: to_string(value)

  defp bar_classes(true) do
    [
      "flex w-full max-w-full flex-nowrap items-center gap-2 whitespace-nowrap sm:w-auto sm:shrink-0"
    ]
  end

  defp bar_classes(false) do
    [
      "flex w-full max-w-full flex-nowrap items-center gap-1.5 whitespace-nowrap rounded-[0.95rem] border border-slate-200 bg-white/85 px-1.5 py-1.5 sm:w-auto sm:shrink-0"
    ]
  end

  defp segment_classes(true) do
    "inline-flex items-center rounded-lg border border-stone-300 bg-stone-200 p-0.5"
  end

  defp segment_classes(false) do
    "inline-flex items-center rounded-lg border border-stone-300 bg-stone-200 p-0.5"
  end

  defp mode_link_classes(true, true) do
    [
      "inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-xs font-semibold transition",
      "bg-slate-950 text-white shadow-sm ring-1 ring-slate-950"
    ]
  end

  defp mode_link_classes(true, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
      "bg-slate-950 text-white shadow-sm ring-1 ring-slate-950"
    ]
  end

  defp mode_link_classes(false, true) do
    [
      "inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-xs font-semibold transition",
      "text-slate-600 hover:bg-white/70 hover:text-slate-950"
    ]
  end

  defp mode_link_classes(false, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
      "text-slate-600 hover:bg-white/70 hover:text-slate-950"
    ]
  end

  defp mode_label_classes(true), do: "inline"
  defp mode_label_classes(false), do: "inline"

  defp divider_classes(true) do
    "hidden h-4 w-px bg-slate-300 sm:block"
  end

  defp divider_classes(false) do
    "hidden h-6 w-px bg-slate-300 sm:block"
  end

  defp search_button_classes(true) do
    "inline-flex h-8 w-8 shrink-0 items-center justify-center gap-1.5 rounded-lg border border-transparent bg-slate-50 text-xs font-semibold text-slate-600 transition duration-150 hover:bg-slate-100 hover:text-slate-950 sm:h-7 sm:w-auto sm:bg-transparent sm:px-2"
  end

  defp search_button_classes(false), do: action_button_classes(false)

  defp action_button_classes(true) do
    [
      "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-transparent bg-slate-50 text-xs font-semibold text-slate-600 transition duration-150 sm:h-7 sm:w-7 sm:bg-transparent",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp action_button_classes(false) do
    [
      "inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 rounded-xl border border-transparent bg-slate-50 text-sm font-semibold text-slate-600 transition duration-150 sm:w-auto sm:justify-start sm:bg-transparent sm:px-3",
      "hover:bg-slate-100 hover:text-slate-950"
    ]
  end

  defp highlights_button_classes(true) do
    [
      "relative inline-flex h-8 w-8 shrink-0 items-center justify-center gap-1.5 overflow-visible rounded-lg border border-transparent text-xs font-semibold transition duration-150 sm:h-7 sm:w-auto sm:px-2",
      ColUtils.tool_color_class("highlight"),
      "hover:bg-amber-100 hover:text-amber-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600"
    ]
  end

  defp highlights_button_classes(false) do
    [
      "relative inline-flex h-9 w-9 shrink-0 items-center justify-center gap-1.5 overflow-visible rounded-xl border border-transparent text-sm font-semibold transition duration-150 sm:w-auto sm:justify-start sm:px-3",
      ColUtils.tool_color_class("highlight"),
      "hover:bg-amber-100 hover:text-amber-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600"
    ]
  end

  defp action_label_classes(true), do: "hidden"
  defp action_label_classes(false), do: "hidden sm:inline"
  defp highlights_label_classes(true), do: "hidden xl:inline"
  defp highlights_label_classes(false), do: "hidden sm:inline"

  defp highlight_count_classes(true) do
    "absolute -right-1 -top-1 inline-flex h-4 min-w-4 shrink-0 items-center justify-center rounded-full bg-amber-700 px-1 text-[10px] font-semibold leading-none text-white ring-2 ring-white sm:static sm:ml-0.5 sm:h-auto sm:w-7 sm:bg-amber-100 sm:px-1 sm:py-0.5 sm:text-[11px] sm:text-amber-800 sm:ring-1 sm:ring-inset sm:ring-amber-200"
  end

  defp highlight_count_classes(false) do
    "absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-amber-700 px-1 text-[10px] font-semibold leading-none text-white ring-2 ring-white sm:static sm:ml-1 sm:h-auto sm:min-w-[1.25rem] sm:bg-amber-100 sm:px-2 sm:py-0.5 sm:text-[11px] sm:text-amber-800 sm:ring-1 sm:ring-inset sm:ring-amber-200"
  end

  defp kbd_classes(true) do
    "hidden"
  end

  defp kbd_classes(false) do
    "hidden rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-semibold text-slate-500 sm:inline-flex"
  end

  defp search_button_label(:reader), do: "Search topics"
  defp search_button_label(:graph), do: "Search this grid"
  defp search_button_label(_mode), do: "Search"

  defp share_button_label(:reader), do: "Share this reader view"
  defp share_button_label(:graph), do: "Share this grid view"
  defp share_button_label(_mode), do: "Share this view"
end
