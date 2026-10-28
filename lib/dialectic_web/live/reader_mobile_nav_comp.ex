defmodule DialecticWeb.ReaderMobileNavComp do
  use DialecticWeb, :html

  attr :can_edit, :boolean, default: true
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
        data-explore-toggle
        aria-controls="outline-mobile-nav-panel"
        aria-expanded="false"
        aria-label="Show outline"
      >
        <span data-explore-hide-icon aria-hidden="true" class="hidden"><.icon
          name="hero-chevron-double-left"
          class="h-5 w-5"
        /></span>
        <span data-explore-show-icon aria-hidden="true"><.icon
          name="hero-bars-3-bottom-left"
          class="h-5 w-5"
        /></span>
        <span data-explore-label>Show outline</span>
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
        id="reader-mobile-ask"
        type="button"
        phx-click="open_follow_up"
        disabled={!@can_edit}
        class="disabled:opacity-40"
      >
        <.icon name="hero-chat-bubble-left-right" class="h-5 w-5" />
        <span>Ask</span>
      </button>
      <button
        id="reader-mobile-more"
        type="button"
        phx-click={JS.dispatch("toggle-panel", to: "#outline-layout", detail: %{id: "right-panel"})}
        data-panel-toggle="right-panel"
        aria-controls="right-panel"
        aria-expanded="false"
        aria-label="More grid actions"
      >
        <.icon name="hero-ellipsis-horizontal" class="h-5 w-5" />
        <span>More</span>
      </button>
    </nav>
    """
  end
end
