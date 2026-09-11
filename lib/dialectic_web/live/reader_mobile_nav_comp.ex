defmodule DialecticWeb.ReaderMobileNavComp do
  use DialecticWeb, :html

  attr :reader_style, :string, required: true
  attr :highlights_count, :integer, default: 0
  attr :current_user, :any, default: nil
  attr :following_graph?, :boolean, default: false

  def reader_mobile_nav(assigns) do
    ~H"""
    <nav id="reader-mobile-toolbar" aria-label="Reader actions" class="reader-mobile-toolbar">
      <button
        id="reader-workspace-bar-outline"
        type="button"
        phx-click={JS.dispatch("toggle-mobile-outline", to: "#outline-layout")}
        aria-controls="outline-mobile-nav-panel"
        aria-expanded="false"
        aria-label="Show conversation outline"
      >
        <.icon name="hero-bars-3-bottom-left" class="h-5 w-5" />
        <span>Outline</span>
      </button>
      <button
        id="reader-mobile-search"
        type="button"
        phx-click={JS.focus() |> JS.push("open_search_overlay_click")}
      >
        <.icon name="hero-magnifying-glass" class="h-5 w-5" />
        <span>Search</span>
      </button>
      <button
        id="reader-mobile-highlights"
        type="button"
        phx-click={
          JS.focus()
          |> JS.dispatch("toggle-panel", to: "#outline-layout", detail: %{id: "highlights-drawer"})
        }
        data-panel-toggle="highlights-drawer"
        aria-controls="highlights-drawer"
        aria-label={"Highlights. #{@highlights_count} saved highlights"}
      >
        <span class="relative inline-flex">
          <.icon name="hero-pencil" class="h-5 w-5" />
          <span
            :if={@highlights_count > 0}
            id="reader-mobile-highlights-count"
            aria-hidden="true"
            class="absolute -right-3 -top-1 inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-amber-700 px-1 text-[10px] font-semibold leading-none text-white ring-2 ring-amber-50"
          >
            {@highlights_count}
          </span>
        </span>
        <span>Highlights</span>
      </button>
      <button id="reader-mobile-more" type="button" popovertarget="reader-mobile-menu">
        <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
        <span>More</span>
      </button>
    </nav>

    <section
      id="reader-mobile-menu"
      popover
      aria-labelledby="reader-mobile-menu-title"
      class="reader-mobile-menu"
    >
      <div class="flex items-center justify-between border-b border-slate-200 px-4 py-2">
        <h2 id="reader-mobile-menu-title" class="text-base font-semibold">Reader options</h2>
        <button
          id="reader-mobile-menu-close"
          type="button"
          popovertarget="reader-mobile-menu"
          popovertargetaction="hide"
          aria-label="Close reader options"
          class="inline-flex h-11 w-11 items-center justify-center rounded-lg"
        >
          <.icon name="hero-x-mark" class="h-5 w-5" />
        </button>
      </div>
      <div class="space-y-4 p-4">
        <fieldset>
          <legend class="mb-2 text-sm font-semibold">Reading style</legend>
          <div class="grid grid-cols-2 gap-2">
            <button
              :for={
                {label, style} <- [
                  {"Book", "book"},
                  {"Screen", "screen"},
                  {"Large print", "large_print"},
                  {"Compact", "compact"}
                ]
              }
              id={"reader-mobile-style-#{style}"}
              type="button"
              aria-pressed={to_string(@reader_style == style)}
              phx-click={
                JS.focus(to: "#reader-mobile-more")
                |> JS.push("save_reader_appearance", value: %{style: style})
              }
              popovertarget="reader-mobile-menu"
              popovertargetaction="hide"
              class="min-h-11 rounded-xl border border-slate-200 px-3 py-2 text-sm font-medium aria-pressed:border-teal-700 aria-pressed:bg-teal-50 aria-pressed:text-teal-900"
            >
              {label}
            </button>
          </div>
        </fieldset>
        <div class="grid gap-1">
          <button
            id="reader-mobile-share"
            type="button"
            phx-click={JS.focus(to: "#reader-mobile-more") |> JS.push("open_share_modal")}
            popovertarget="reader-mobile-menu"
            popovertargetaction="hide"
            class="reader-mobile-menu-action"
          >
            <.icon name="hero-share" class="h-5 w-5" /> Share
          </button>
          <button
            :if={@current_user}
            id="reader-mobile-follow"
            type="button"
            phx-click={if(@following_graph?, do: "unfollow_graph", else: "follow_graph")}
            aria-pressed={to_string(@following_graph?)}
            class="reader-mobile-menu-action"
          >
            <.icon name="hero-bell" class="h-5 w-5" />
            {if(@following_graph?, do: "Turn off grid updates", else: "Get grid updates")}
          </button>
          <.link
            :if={!@current_user}
            id="reader-mobile-follow-login"
            navigate={~p"/users/log_in"}
            class="reader-mobile-menu-action"
          >
            <.icon name="hero-bell" class="h-5 w-5" /> Sign in for grid updates
          </.link>
        </div>
      </div>
    </section>
    """
  end
end
