defmodule DialecticWeb.WorkspaceBarComp do
  use DialecticWeb, :html
  alias DialecticWeb.ColUtils

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
        :answer_level_label,
        answer_level_label(assigns.prompt_mode || Map.get(assigns.graph_struct, :prompt_mode))
      )
      |> assign(:answer_level_click, settings_click(assigns, "configure"))
      |> assign(
        :visibility_click,
        if(assigns.current_user && assigns.graph_struct.user_id == assigns.current_user.id,
          do: settings_click(assigns, "workspace"),
          else: "open_share_modal"
        )
      )
      |> assign(
        :return_context,
        assigns.return_context || %{path: "/community", label: "Community"}
      )

    ~H"""
    <header id={@prefix <> "-header"} class="workspace-header">
      <div id={@prefix <> "-heading"} class="workspace-heading">
        <.link
          id={@prefix <> "-header-back-link"}
          href={@return_context.path}
          title={"Back to #{@return_context.label}"}
          class="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-slate-600 transition hover:border-slate-300 hover:bg-slate-100 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700 active:bg-slate-200"
        >
          <.icon name="hero-arrow-left" class="h-5 w-5" />
          <span class="sr-only">Back to {@return_context.label}</span>
        </.link>
        <div class="flex min-w-0 flex-1 flex-col justify-center gap-0.5">
          <h1
            id={@prefix <> "-title"}
            class="min-w-0 truncate text-base font-semibold leading-snug text-slate-900"
            title={@graph_struct.title}
          >
            {@graph_struct.title}
          </h1>
          <p class="truncate text-xs leading-4 text-slate-500" title={@return_context.label}>
            {@return_context.label}
          </p>
        </div>
      </div>
      <div id={@prefix <> "-top-menu"} class="workspace-menu hidden sm:flex">
        <.workspace_bar
          id={@prefix <> "-workspace-bar"}
          mode={@mode}
          graph_struct={@graph_struct}
          node_id={@node_id}
          nav_params={@nav_params}
          show_search
          search_click="open_search_overlay_click"
          highlights_click={
            JS.dispatch("toggle-panel", to: @layout_target, detail: %{id: "highlights-drawer"})
          }
          highlights_count={@highlights_count}
          highlights_panel_id="highlights-drawer"
          show_share={false}
          compact
        />
        <div class="workspace-context-actions">
          <div
            id={@prefix <> "-settings-actions"}
            class="workspace-menu-group"
            role="group"
            aria-label="Answer and access settings"
          >
            <button
              id={@prefix <> "-workspace-bar-level"}
              type="button"
              phx-click={@answer_level_click}
              data-panel-toggle={if(@mode == :graph, do: "right-panel")}
              data-panel-section={if(@mode == :graph, do: "configure")}
              aria-controls={if(@mode == :graph, do: "right-panel")}
              aria-expanded={if(@mode == :graph, do: "false")}
              aria-label={"Explanation level: #{@answer_level_label}. Change explanation level"}
              title={"Explanation level: #{@answer_level_label}. Change explanation level"}
              class="inline-flex h-7 w-8 shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white text-xs font-semibold text-slate-700 transition hover:border-indigo-300 hover:bg-indigo-50 hover:text-indigo-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 md:w-[6.75rem]"
            >
              <.icon name="hero-square-3-stack-3d" class="h-3.5 w-3.5" />
              <span class="hidden md:inline">{@answer_level_label}</span>
            </button>
            <button
              id={@prefix <> "-access-settings"}
              type="button"
              phx-click={@visibility_click}
              data-panel-toggle={
                if(@mode == :graph && @current_user && @graph_struct.user_id == @current_user.id,
                  do: "right-panel"
                )
              }
              data-panel-section={
                if(@mode == :graph && @current_user && @graph_struct.user_id == @current_user.id,
                  do: "workspace"
                )
              }
              aria-label={"Grid visibility: #{if(@graph_struct.is_public, do: "Public", else: "Private")}"}
              title={"Access controls: #{if(@graph_struct.is_public, do: "Public", else: "Private")} · #{if(@graph_struct.is_locked, do: "Protected", else: "Editable")}"}
              class="inline-flex h-7 w-8 shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white text-xs font-medium text-slate-600 transition hover:bg-slate-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-600 md:w-[5.5rem]"
            >
              <.icon
                name={if(@graph_struct.is_public, do: "hero-globe-alt", else: "hero-lock-closed")}
                class="h-3.5 w-3.5"
              />
              <span class="hidden md:inline">{if(@graph_struct.is_public,
                do: "Public",
                else: "Private"
              )}</span>
            </button>
            <.live_component
              module={DialecticWeb.DocumentMenuComp}
              id="document-menu"
              can_edit={!@graph_struct.is_locked}
              layout_target={@layout_target}
              compact={true}
            />
          </div>
          <div
            id={@prefix <> "-sharing-actions"}
            class="workspace-menu-group"
            role="group"
            aria-label="Sharing and updates"
          >
            <.share_button
              id={@prefix <> "-workspace-bar-share"}
              mode={@mode}
              click="open_share_modal"
              compact
            />
            <%= if @current_user do %>
              <button
                id={"#{@prefix}-follow-grid-button"}
                type="button"
                phx-click={if(@following_graph?, do: "unfollow_graph", else: "follow_graph")}
                aria-label={
                  if(@following_graph?,
                    do: "Stop receiving grid updates in Activity",
                    else: "Get notified about grid changes in Activity"
                  )
                }
                aria-pressed={to_string(@following_graph?)}
                title={
                  if(@following_graph?,
                    do: "Updates from this grid appear in Activity. Click to turn them off.",
                    else: "Get notified when this grid changes and see updates in Activity."
                  )
                }
                class={[
                  "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border text-slate-600 transition duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-600 sm:h-7 sm:w-7",
                  if(@following_graph?,
                    do: "border-sky-200 bg-sky-100 text-sky-700 hover:bg-sky-200",
                    else:
                      "border-transparent bg-slate-50 hover:bg-slate-100 hover:text-slate-950 sm:bg-transparent"
                  )
                ]}
              >
                <.icon
                  name={if(@following_graph?, do: "hero-bell-solid", else: "hero-bell-alert")}
                  class="h-4 w-4"
                />
              </button>
            <% else %>
              <.link
                navigate={~p"/users/log_in"}
                id={"#{@prefix}-follow-grid-login-link"}
                aria-label="Sign in to get notified about grid changes in Activity"
                title="Sign in to get notified when this grid changes and see updates in Activity."
                class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border border-transparent bg-slate-50 text-slate-600 transition duration-150 hover:bg-slate-100 hover:text-slate-950 sm:h-7 sm:w-7 sm:bg-transparent"
              >
                <.icon name="hero-bell-alert" class="h-4 w-4" />
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :layout_target, :string, required: true
  slot :inner_block, required: true

  def tools_drawer(assigns) do
    ~H"""
    <div
      id={@id}
      data-right-drawer
      role="region"
      aria-labelledby="grid-tools-title"
      tabindex="-1"
      class="absolute inset-y-0 right-0 z-50 w-0 overflow-hidden border-l border-gray-200 bg-white opacity-0 transform translate-x-full transition-all duration-300 ease-in-out"
    >
      <div class="p-2">
        <div class="mb-2 flex items-start justify-between gap-2 px-1">
          <div>
            <h2 id="grid-tools-title" class="text-sm font-semibold text-gray-900">Grid tools</h2>
            <p class="text-[11px] text-gray-500">
              Settings, presentation, history, export, and translation.
            </p>
          </div>
          <button
            id="grid-tools-close"
            data-panel-close
            type="button"
            phx-click={JS.dispatch("toggle-panel", to: @layout_target, detail: %{id: @id})}
            class="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-gray-200 text-gray-600 hover:bg-gray-50"
            aria-label="Close grid tools"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>
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
            title="Open grid view"
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
          <span class={if(@compact, do: "hidden xl:inline", else: "hidden sm:inline")}>
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
            :if={@compact || @highlights_count > 0}
            aria-hidden="true"
            class={[
              highlight_count_classes(@compact),
              @compact && @highlights_count == 0 && "invisible"
            ]}
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

  defp normalize_node_id(nil), do: nil
  defp normalize_node_id(value), do: to_string(value)

  def answer_level_label("simple"), do: "Simple"
  def answer_level_label("high_school"), do: "Simple"
  def answer_level_label("expert"), do: "In-depth"
  def answer_level_label(_mode), do: "Expanded"

  defp settings_click(%{mode: :graph} = assigns, section) do
    JS.dispatch("toggle-panel",
      to: assigns.layout_target,
      detail: %{id: "right-panel", section: section}
    )
    |> JS.push(
      if(section == "configure", do: "open_prompt_settings", else: "open_access_settings")
    )
  end

  defp settings_click(assigns, section) do
    JS.navigate(
      graph_editor_path(
        assigns.graph_struct,
        assigns.node_id,
        Keyword.put(assigns.nav_params, :tools, section)
      )
    )
  end

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
    "hidden items-center rounded-full border border-slate-300 bg-slate-200/80 p-1 shadow-inner sm:inline-flex"
  end

  defp segment_classes(false) do
    "hidden items-center rounded-full border border-slate-300 bg-slate-200/80 p-1 shadow-inner sm:inline-flex"
  end

  defp mode_link_classes(true, true) do
    [
      "inline-flex h-8 items-center gap-1.5 rounded-full px-3 text-xs font-semibold transition",
      "bg-white text-slate-950 shadow-sm ring-1 ring-slate-300"
    ]
  end

  defp mode_link_classes(true, false) do
    [
      "inline-flex h-8 items-center gap-2 rounded-full px-3.5 text-sm font-semibold transition",
      "bg-white text-slate-950 shadow-sm ring-1 ring-slate-300"
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

  defp mode_label_classes(true), do: "hidden lg:inline"
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
