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
      <button
        id="reader-mobile-more"
        type="button"
        phx-click={JS.dispatch("toggle-panel", to: "#outline-layout", detail: %{id: "right-panel"})}
        data-panel-toggle="right-panel"
        aria-controls="right-panel"
        aria-expanded="false"
        aria-label="Open grid tools"
      >
        <.icon name="hero-wrench-screwdriver" class="h-5 w-5" />
        <span>Tools</span>
      </button>
    </nav>
    """
  end
end
