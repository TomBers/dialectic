defmodule DialecticWeb.SiteNavigation do
  use DialecticWeb, :html

  attr :current_user, :any, required: true
  attr :active_path, :string, required: true

  def nav(assigns) do
    ~H"""
    <nav
      id="site-navigation"
      aria-label="Main navigation"
      class="mx-auto flex h-full w-full max-w-7xl items-center justify-between gap-1 px-2 text-xs sm:gap-2 sm:px-4"
    >
      <.link
        href={~p"/"}
        aria-label="RationalGrid home"
        class="inline-flex h-9 shrink-0 items-center gap-2 rounded px-1 text-white focus-visible:outline-2 focus-visible:outline-teal-300"
      >
        <img src={~p"/images/brandmark.svg"} alt="" width="40" height="40" class="h-5 w-5" />
        <span class="hidden font-semibold tracking-tight sm:inline">RationalGrid</span>
      </.link>

      <div id="site-navigation-links" class="flex h-full items-center gap-0.5 text-slate-300 sm:gap-1">
        <%= if @current_user do %>
          <.nav_link
            id="my-learning-nav-link"
            href={~p"/my/learning"}
            label="My Learning"
            active={@active_path == "/my/learning"}
          />
        <% else %>
          <.nav_link
            id="guide-nav-link"
            href={~p"/intro/how"}
            label="Guide"
            icon="hero-book-open"
            compact
            active={@active_path == "/intro/how"}
          />
          <.nav_link
            id="about-nav-link"
            href={~p"/about"}
            label="About"
            icon="hero-information-circle"
            compact
            active={@active_path == "/about"}
          />
        <% end %>

        <.nav_link
          id="community-nav-link"
          href={~p"/community"}
          label="Community"
          active={@active_path in ["/community", "/search"]}
        />

        <.link
          id="desktop-new-grid-nav-link"
          href={if @current_user, do: ~p"/my/learning?new=true", else: ~p"/?focus=grid#start-here"}
          class={[
            "ml-1 h-8 shrink-0 items-center justify-center rounded-md bg-teal-300 px-2 font-semibold text-slate-950 hover:bg-teal-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-300 sm:px-2.5",
            if(@current_user, do: "inline-flex", else: "hidden md:inline-flex")
          ]}
        >
          {if @current_user, do: "+ Private grid", else: "+ Public grid"}
        </.link>

        <%= if @current_user do %>
          <button
            id="account-menu-toggle"
            type="button"
            popovertarget="account-menu"
            aria-label="Account"
            title="Account"
            class={[
              "inline-flex h-9 items-center gap-1 rounded-md px-1.5 font-medium hover:bg-slate-800 hover:text-white focus-visible:outline-2 focus-visible:outline-teal-300 sm:px-2",
              @active_path in [
                "/u/#{@current_user.username}",
                "/users/settings",
                "/intro/how",
                "/about",
                "/admin/curated"
              ] && "text-white"
            ]}
          >
            <.icon name="hero-user-circle" class="h-4 w-4" />
            <span class="hidden sm:inline">Account</span>
            <.icon name="hero-chevron-down" class="hidden h-3 w-3 sm:block" />
          </button>

          <div
            id="account-menu"
            popover="auto"
            aria-label="Account links"
            class="fixed bottom-auto left-auto right-2 top-12 m-0 w-56 max-w-[calc(100vw-1rem)] rounded-xl border border-slate-200 bg-white p-2 text-sm text-slate-700 shadow-xl sm:right-4"
          >
            <.account_link
              id="account-profile-link"
              href={~p"/u/#{@current_user.username}"}
              label="My Profile"
              icon="hero-user-circle"
              active={@active_path == "/u/#{@current_user.username}"}
            />
            <.account_link
              id="account-settings-link"
              href={~p"/users/settings"}
              label="Settings"
              icon="hero-cog-6-tooth"
              active={@active_path == "/users/settings"}
            />
            <div class="my-1 border-t border-slate-100"></div>
            <.account_link
              id="account-guide-link"
              href={~p"/intro/how"}
              label="Guide"
              icon="hero-book-open"
              active={@active_path == "/intro/how"}
            />
            <.account_link
              id="account-about-link"
              href={~p"/about"}
              label="About"
              icon="hero-information-circle"
              active={@active_path == "/about"}
            />
            <.account_link
              :if={@current_user.is_admin}
              id="account-curate-link"
              href={~p"/admin/curated"}
              label="Curate"
              icon="hero-star"
              active={@active_path == "/admin/curated"}
            />
            <div class="my-1 border-t border-slate-100"></div>
            <.link
              id="account-log-out-link"
              href={~p"/users/log_out"}
              method="delete"
              class="flex min-h-11 items-center gap-3 rounded-lg px-3 py-2 hover:bg-slate-100 focus-visible:outline-2 focus-visible:outline-teal-700"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" /> Log out
            </.link>
          </div>
        <% else %>
          <.link
            id="global-sign-up-link"
            href={~p"/users/register"}
            data-analytics-event="sign_up_cta_clicked"
            data-analytics-location="global_navigation"
            class="ml-1 inline-flex h-8 items-center rounded-md bg-teal-300 px-2 font-semibold text-slate-950 hover:bg-teal-200 sm:px-3"
          >Sign up free</.link>
          <.nav_link
            id="log-in-nav-link"
            href={~p"/users/log_in"}
            label="Log in"
            active={@active_path == "/users/log_in"}
          />
        <% end %>
      </div>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :compact, :boolean, default: false
  attr :active, :boolean, default: false

  defp nav_link(assigns) do
    ~H"""
    <.link
      id={@id}
      href={@href}
      aria-label={@label}
      title={@label}
      aria-current={if @active, do: "page"}
      class={[
        "inline-flex h-full shrink-0 items-center gap-1 border-b-2 px-1 font-medium focus-visible:outline-2 focus-visible:outline-teal-300 sm:px-2",
        if(@active,
          do: "border-teal-300 text-white",
          else: "border-transparent hover:border-slate-500 hover:text-white"
        )
      ]}
    >
      <.icon :if={@icon} name={@icon} class="h-4 w-4" />
      <span class={[@compact && "hidden sm:inline"]}>{@label}</span>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  defp account_link(assigns) do
    ~H"""
    <.link
      id={@id}
      href={@href}
      aria-label={@label}
      aria-current={if @active, do: "page"}
      class={[
        "flex min-h-11 items-center gap-3 rounded-lg px-3 py-2 hover:bg-slate-100 focus-visible:outline-2 focus-visible:outline-teal-700",
        @active && "bg-teal-50 font-semibold text-teal-800"
      ]}
    >
      <.icon name={@icon} class="h-4 w-4" /> {@label}
    </.link>
    """
  end
end
