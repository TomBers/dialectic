defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.ProfileBanner
  alias Dialectic.Accounts.ProfileLinks
  alias Dialectic.Follows
  import DialecticWeb.GridCardComp

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_for_profile(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> redirect(to: ~p"/")}

      profile_user ->
        graphs = Accounts.list_user_public_graphs(profile_user)
        stats = Accounts.get_profile_stats(profile_user, graphs)
        following_users = Follows.list_user_following_users(profile_user)
        follower_users = Follows.list_user_followers(profile_user)

        effective_username = User.effective_username(profile_user)
        common_tags = Accounts.get_common_tags(profile_user, graphs: graphs)
        featured_graphs = featured_graphs(graphs)
        current_focus = current_focus_text(common_tags, graphs)

        is_own_profile? =
          case socket.assigns[:current_user] do
            %User{id: id} when id == profile_user.id -> true
            _ -> false
          end

        socket =
          socket
          |> assign(:page_title, "#{effective_username} — Profile")
          |> assign(:profile_user, profile_user)
          |> assign(:effective_username, effective_username)
          |> assign(:avatar_url, profile_user.avatar_path)
          |> assign(:profile_banner_url, effective_banner_url(profile_user))
          |> assign(:theme, nil)
          |> assign(:stats, stats)
          |> assign(:following_users, following_users)
          |> assign(:follower_users, follower_users)
          |> assign(:graph_count, length(graphs))
          |> assign(:featured_count, length(featured_graphs))
          |> assign(:current_focus, current_focus)
          |> assign(:common_tags, common_tags)
          |> assign(:profile_links, ProfileLinks.display_links(profile_user.profile_links))
          |> assign(:is_own_profile?, is_own_profile?)
          |> assign(
            :following_profile?,
            following_profile?(socket.assigns[:current_user], profile_user)
          )
          |> stream_configure(:public_grids, dom_id: &public_grid_id/1)
          |> stream(:public_grids, graphs)
          |> stream_configure(:featured_grids,
            dom_id: fn item -> "profile-featured-grid-" <> grid_key(item.graph) end
          )
          |> stream(
            :featured_grids,
            Enum.with_index(featured_graphs, fn graph, index -> %{graph: graph, index: index} end)
          )

        {:ok, socket, layout: false}
    end
  end

  @impl true
  def handle_event("follow_profile", _params, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    case Follows.follow_user(current_user, profile_user) do
      {:ok, _follow} ->
        {:noreply,
         socket
         |> assign(:following_profile?, true)
         |> refresh_social_stats()
         |> put_flash(:info, "Profile followed.")}

      {:error, :unauthenticated} ->
        {:noreply, put_flash(socket, :error, "Log in to follow profiles.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not follow this profile.")}
    end
  end

  @impl true
  def handle_event("unfollow_profile", _params, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    case Follows.unfollow_user(current_user, profile_user) do
      {:ok, _count} ->
        {:noreply,
         socket
         |> assign(:following_profile?, false)
         |> refresh_social_stats()
         |> put_flash(:info, "Profile unfollowed.")}

      {:error, :unauthenticated} ->
        {:noreply, put_flash(socket, :error, "Log in to manage followed profiles.")}
    end
  end

  defp profile_link_icon(%{kind: "email"}), do: "hero-envelope"
  defp profile_link_icon(_), do: "hero-link"

  defp grid_key(graph), do: graph.slug || Base.url_encode64(graph.title, padding: false)
  defp public_grid_id(graph), do: "profile-public-grid-row-" <> grid_key(graph)

  defp effective_banner_url(%User{banner_path: path}) when is_binary(path) and path != "",
    do: path

  defp effective_banner_url(%User{profile_banner: banner}), do: ProfileBanner.url(banner)

  defp following_profile?(%User{} = current_user, %User{} = profile_user) do
    current_user.id != profile_user.id and Follows.following_user?(current_user, profile_user)
  end

  defp following_profile?(_current_user, _profile_user), do: false

  defp refresh_social_stats(socket) do
    profile_user = socket.assigns.profile_user

    socket
    |> assign(:following_users, Follows.list_user_following_users(profile_user))
    |> assign(:follower_users, Follows.list_user_followers(profile_user))
  end

  defp show_social_modal(type) when type in ["following", "followers"] do
    other_type = if type == "following", do: "followers", else: "following"
    panel_title = "profile-social-#{type}-panel-title"

    %JS{}
    |> JS.add_class("hidden", to: "#profile-social-#{other_type}-panel")
    |> JS.remove_class("hidden", to: "#profile-social-#{type}-panel")
    |> JS.set_attribute({"aria-labelledby", panel_title},
      to: "#profile-social-modal [role='dialog']"
    )
    |> show_modal("profile-social-modal")
  end

  defp profile_user_path(%User{} = user), do: ~p"/u/#{User.effective_username(user)}"

  defp user_initial(%User{} = user) do
    user
    |> User.effective_username()
    |> String.first()
    |> String.upcase()
  end

  defp social_users_panel(assigns) do
    ~H"""
    <div id={@id} class={["profile-social-panel", @hidden && "hidden"]}>
      <div class="mb-5">
        <p class="text-xs font-semibold uppercase text-cyan-700">
          {@effective_username}
        </p>
        <h2 id={"#{@id}-title"} class="mt-1 text-2xl font-semibold text-slate-950">
          {@title}
        </h2>
      </div>

      <div id={"#{@id}-users"} class="max-h-[28rem] overflow-y-auto divide-y divide-slate-100">
        <%= if @users == [] do %>
          <div id={"#{@id}-empty"} class="rounded-xl border border-slate-200 p-8 text-center">
            <.icon name="hero-user-group" class="mx-auto mb-3 h-10 w-10 text-slate-400" />
            <p class="text-sm text-slate-500">
              {@empty_text}
            </p>
          </div>
        <% else %>
          <%= for user <- @users do %>
            <.link
              navigate={profile_user_path(user)}
              id={"#{@id}-user-#{user.id}"}
              class="flex items-center gap-3 px-1 py-3 transition hover:bg-slate-50 sm:px-3"
            >
              <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full bg-slate-900 text-sm font-semibold text-white">
                <%= if user.avatar_path do %>
                  <img
                    src={user.avatar_path}
                    alt={"#{User.effective_username(user)}'s avatar"}
                    class="h-full w-full object-cover"
                  />
                <% else %>
                  {user_initial(user)}
                <% end %>
              </span>
              <span class="min-w-0">
                <span class="block truncate text-sm font-semibold text-slate-950">
                  {User.effective_username(user)}
                </span>
                <span :if={user.bio && user.bio != ""} class="block truncate text-xs text-slate-500">
                  {user.bio}
                </span>
              </span>
            </.link>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp public_grid_row(assigns) do
    tags = assigns.graph |> Map.get(:tags, []) |> then(&(&1 || [])) |> Enum.take(3)

    assigns =
      assigns
      |> assign(:title, profile_grid_title(assigns.graph))
      |> assign(:tags, tags)
      |> assign(:node_count, graph_node_count(assigns.graph))
      |> assign(:created_label, created_label(assigns.graph))
      |> assign(:accent_style, profile_grid_row_accent(tags))

    ~H"""
    <article
      id={@id}
      data-role="profile-public-grid-row"
      class="group relative grid gap-5 px-5 py-5 pl-6 transition hover:bg-[#fbfaf6] sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:px-6 sm:pl-7"
    >
      <div aria-hidden="true" class="absolute inset-y-0 left-0 w-1" style={@accent_style}></div>
      <div class="min-w-0">
        <.link
          navigate={graph_path(@graph)}
          class="text-balance font-serif text-xl font-semibold leading-7 tracking-tight text-slate-950 transition group-hover:text-teal-800 hover:text-teal-900 sm:text-2xl"
        >
          {@title}
        </.link>

        <div
          data-role="profile-public-grid-meta"
          class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-slate-500"
        >
          <span aria-label={"Created " <> @created_label}>{@created_label}</span>
          <span aria-hidden="true">·</span>
          <span>{profile_idea_count_label(@node_count)}</span>
        </div>

        <div class="mt-4 flex flex-wrap items-center gap-x-4 gap-y-2">
          <%= if @tags == [] do %>
            <span class="text-xs font-medium text-slate-500">Untagged</span>
          <% else %>
            <span
              :for={tag <- @tags}
              class="inline-flex items-center gap-1.5 text-xs font-medium text-slate-600"
            >
              <span
                aria-hidden="true"
                class="h-1.5 w-1.5 shrink-0 rounded-full"
                style={"background-color: " <> tag_color_hex(tag)}
              ></span>
              {tag_label(tag)}
            </span>
          <% end %>
        </div>
      </div>

      <div class="flex items-center border-t border-stone-200 pt-4 sm:border-t-0 sm:pt-0">
        <.link
          navigate={graph_path(@graph)}
          class="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-800 transition hover:text-teal-950"
          aria-label={"Read grid: " <> @title}
        >
          Read grid
          <.icon
            name="hero-arrow-right"
            class="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5"
          />
        </.link>
      </div>
    </article>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.modal id="profile-social-modal" class="mx-auto w-full max-w-2xl">
        <div id="profile-social-modal-panel">
          <.social_users_panel
            id="profile-social-following-panel"
            hidden={true}
            effective_username={@effective_username}
            title="Following"
            users={@following_users}
            empty_text="Not following any profiles yet."
          />
          <.social_users_panel
            id="profile-social-followers-panel"
            hidden={true}
            effective_username={@effective_username}
            title="Followers"
            users={@follower_users}
            empty_text="No profile followers yet."
          />
        </div>
      </.modal>

      <div class={["min-h-screen w-full", theme_bg_class(@theme)]}>
        <div class="mx-auto max-w-6xl px-4 pb-8 pt-4 sm:px-6 sm:pb-12 sm:pt-6">
          <%!-- Profile Header --%>
          <div
            id="public-profile-header"
            class={[
              "relative overflow-hidden rounded-[2rem] border border-slate-900/10 bg-slate-950 text-white shadow-[0_36px_110px_-56px_rgba(15,23,42,0.85)]"
            ]}
          >
            <%!-- Banner area --%>
            <div class="relative h-36 overflow-hidden sm:h-44 lg:h-48">
              <%= cond do %>
                <% @profile_banner_url -> %>
                  <img
                    src={@profile_banner_url}
                    alt={"#{@effective_username}'s profile banner"}
                    class="absolute inset-0 h-full w-full object-cover"
                  />
                <% true -> %>
                  <div class={["absolute inset-0", theme_banner_class(@theme)]}></div>
              <% end %>
              <div class="absolute inset-x-0 bottom-0 h-px bg-white/10"></div>
            </div>

            <div class="relative px-5 pb-6 pt-5 sm:px-8 sm:pb-8 sm:pt-6">
              <%!-- Avatar --%>
              <div class="flex flex-col gap-4 sm:flex-row sm:items-end">
                <div class={[
                  "h-24 w-24 sm:h-28 sm:w-28 rounded-full border-4 flex items-center justify-center overflow-hidden flex-shrink-0 shadow-2xl shadow-slate-950/35",
                  theme_avatar_border_class(@theme)
                ]}>
                  <%= if @avatar_url do %>
                    <img
                      src={@avatar_url}
                      alt={"#{@effective_username}'s avatar"}
                      class="h-full w-full object-cover rounded-full"
                    />
                  <% else %>
                    <div class={[
                      "h-full w-full flex items-center justify-center rounded-full text-3xl font-bold",
                      theme_avatar_default_class(@theme)
                    ]}>
                      {String.first(@effective_username) |> String.upcase()}
                    </div>
                  <% end %>
                </div>

                <div class="min-w-0 flex-1 pb-1">
                  <h1 class="break-words text-4xl font-semibold leading-[1.15] text-white sm:text-6xl sm:leading-[1.15]">
                    {@effective_username}
                  </h1>
                </div>

                <div class="flex flex-wrap items-center gap-2 pb-1">
                  <.link
                    :if={@is_own_profile?}
                    id="profile-settings-link"
                    navigate={~p"/users/settings"}
                    class="inline-flex items-center gap-2 rounded-xl bg-white px-4 py-2 text-sm font-semibold text-slate-950"
                  >
                    <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit public profile
                  </.link>
                  <%= if not @is_own_profile? do %>
                    <%= if @current_user do %>
                      <button
                        id="profile-follow-button"
                        type="button"
                        phx-click={
                          if(@following_profile?, do: "unfollow_profile", else: "follow_profile")
                        }
                        class={[
                          "inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                          if(@following_profile?,
                            do: "border border-white/15 bg-white/10 text-white hover:bg-white/15",
                            else: "bg-white text-slate-950 hover:bg-cyan-50"
                          )
                        ]}
                      >
                        <.icon
                          name={if(@following_profile?, do: "hero-check", else: "hero-plus")}
                          class="w-4 h-4"
                        />
                        <%= if @following_profile? do %>
                          Following
                        <% else %>
                          Follow
                        <% end %>
                      </button>
                    <% else %>
                      <.link
                        navigate={~p"/users/log_in"}
                        id="profile-follow-login-link"
                        class="inline-flex items-center gap-1.5 rounded-xl bg-white px-4 py-2 text-sm font-semibold text-slate-950 shadow-sm transition hover:bg-cyan-50"
                      >
                        <.icon name="hero-plus" class="w-4 h-4" /> Follow
                      </.link>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div class="mt-6 grid gap-6 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end">
                <div>
                  <%= if @profile_user.bio && @profile_user.bio != "" do %>
                    <p
                      id="profile-bio"
                      class={[
                        "max-w-3xl font-semibold text-white",
                        profile_bio_text_class(@profile_user.bio)
                      ]}
                    >
                      {@profile_user.bio}
                    </p>
                  <% end %>

                  <%= if @current_focus do %>
                    <div class="mt-5 inline-flex max-w-2xl items-start gap-2 rounded-2xl bg-white/10 px-3 py-2 text-sm leading-6 text-slate-100 ring-1 ring-white/15">
                      <.icon name="hero-sparkles" class="mt-0.5 h-4 w-4 shrink-0 text-cyan-200" />
                      <p>{@current_focus}</p>
                    </div>
                  <% end %>

                  <%!-- Social Links & Info --%>
                  <div class="mt-4 flex flex-wrap items-center gap-3">
                    <%= for link <- @profile_links do %>
                      <a
                        href={link.href}
                        target={if link.kind == "url", do: "_blank", else: nil}
                        rel={if link.kind == "url", do: "noopener noreferrer me", else: "me"}
                        class="inline-flex items-center gap-1.5 text-sm font-semibold text-cyan-200 transition hover:text-white"
                      >
                        <.icon name={profile_link_icon(link)} class="w-4 h-4" />
                        {link.label}
                      </a>
                    <% end %>

                    <span class="inline-flex items-center gap-1.5 text-sm text-slate-300">
                      <.icon name="hero-calendar-days" class="w-4 h-4" />
                      Member since {Calendar.strftime(@stats.member_since, "%B %Y")}
                    </span>
                  </div>
                </div>

                <div class="rounded-2xl border border-white/10 bg-white/10 p-3 shadow-2xl shadow-slate-950/20 backdrop-blur">
                  <div class="grid grid-cols-3 gap-2 text-center">
                    <div class="px-1 py-1">
                      <p class="text-2xl font-semibold leading-7 text-white">
                        {@stats.graphs_created}
                      </p>
                      <p class="mt-1 text-[10px] font-semibold uppercase text-slate-300">
                        Grids
                      </p>
                    </div>
                    <div class="px-1 py-1">
                      <p class="text-2xl font-semibold leading-7 text-white">
                        {@stats.total_nodes}
                      </p>
                      <p class="mt-1 text-[10px] font-semibold uppercase text-slate-300">
                        Ideas
                      </p>
                    </div>
                    <div class="px-1 py-1">
                      <p class="text-2xl font-semibold leading-7 text-white">
                        {format_member_duration(@stats.member_since)}
                      </p>
                      <p class="mt-1 text-[10px] font-semibold uppercase text-slate-300">
                        Days
                      </p>
                    </div>
                  </div>

                  <div class="mt-2 grid grid-cols-2 gap-2 border-t border-white/10 pt-2 text-center">
                    <button
                      id="profile-following-stat"
                      type="button"
                      phx-click={show_social_modal("following")}
                      class="rounded-xl px-2 py-1 transition hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-cyan-200"
                    >
                      <p class="text-2xl font-semibold leading-7 text-white">
                        {length(@following_users)}
                      </p>
                      <p class="mt-1 text-[10px] font-semibold uppercase text-slate-300">
                        Following
                      </p>
                    </button>
                    <button
                      id="profile-followers-stat"
                      type="button"
                      phx-click={show_social_modal("followers")}
                      class="rounded-xl px-2 py-1 transition hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-cyan-200"
                    >
                      <p class="text-2xl font-semibold leading-7 text-white">
                        {length(@follower_users)}
                      </p>
                      <p class="mt-1 text-[10px] font-semibold uppercase text-slate-300">
                        Followers
                      </p>
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Common Tags --%>
              <%= if @common_tags != [] do %>
                <div class="mt-6 flex flex-wrap items-center gap-1.5 border-t border-white/10 pt-4">
                  <span class="text-xs font-semibold uppercase text-slate-300">
                    Topics
                  </span>
                  <%= for tag <- @common_tags do %>
                    <span class="inline-flex items-center rounded-full bg-white/10 px-2.5 py-0.5 text-xs font-semibold text-white ring-1 ring-white/15">
                      {tag_label(tag)}
                    </span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%= if @featured_count > 0 do %>
            <section id="profile-start-here" class="mt-12">
              <div class="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
                <div>
                  <p class="text-xs font-semibold uppercase text-teal-700">
                    Start here
                  </p>
                  <h2 class="mt-1 text-3xl font-semibold text-slate-950">
                    Entry points
                  </h2>
                </div>

                <p class="max-w-xl text-sm leading-6 text-slate-600 sm:text-right">
                  A few substantial public grids selected from depth, tags, and recency.
                </p>
              </div>

              <div
                id="profile-featured-grid-list"
                phx-update="stream"
                class="grid gap-4 lg:grid-cols-12"
              >
                <%= for {id, item} <- @streams.featured_grids do %>
                  <.grid_card
                    graph={item.graph}
                    id={id}
                    variant={:featured}
                    featured_index={item.index}
                    tag_limit={3}
                  />
                <% end %>
              </div>
            </section>
          <% end %>

          <%!-- Graphs Section --%>
          <div class="mt-10 border-t border-slate-200 pt-8">
            <div class="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.14em] text-teal-700">
                  Public thinking
                </p>
                <h2 class="mt-1 text-2xl font-semibold tracking-tight text-slate-950 sm:text-3xl">
                  Public grids
                </h2>
              </div>
              <p class="text-sm text-slate-600">
                <span class={[
                  "mr-1 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                  theme_tag_class(@theme)
                ]}>
                  {@graph_count}
                </span>
                by {@effective_username}
              </p>
            </div>

            <div id="public-grids-content">
              <%= if @graph_count == 0 do %>
                <div class={["rounded-xl border p-8 text-center shadow-sm", theme_card_class(@theme)]}>
                  <.icon
                    name="hero-light-bulb"
                    class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
                  />
                  <p class={["text-sm", theme_subtext_class(@theme)]}>
                    No public grids yet.
                  </p>
                </div>
              <% else %>
                <div
                  id="profile-public-grid-list"
                  phx-update="stream"
                  class="divide-y divide-slate-200 overflow-hidden border border-slate-200 bg-white"
                >
                  <%= for {id, graph} <- @streams.public_grids do %>
                    <.public_grid_row
                      graph={graph}
                      id={id}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Back link --%>
          <div class="mt-10 flex items-center justify-between">
            <.link
              navigate={~p"/"}
              class={[
                "inline-flex items-center gap-2 text-sm font-semibold transition",
                theme_link_class(@theme)
              ]}
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to home
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # --- Helper functions ---

  defp format_member_duration(inserted_at) do
    days = Date.diff(Date.utc_today(), DateTime.to_date(inserted_at))

    cond do
      days < 1 -> "1"
      true -> Integer.to_string(days)
    end
  end

  defp featured_graphs(graphs) do
    graphs
    |> Enum.sort_by(fn graph ->
      {-featured_graph_score(graph), -graph_unix(graph), String.downcase(graph.title || "")}
    end)
    |> Enum.take(3)
  end

  defp featured_graph_score(graph) do
    tag_count = length(graph.tags || [])
    tag_bonus = min(tag_count, 5) * 12
    missing_tag_penalty = if tag_count == 0, do: -20, else: 0

    min(graph_node_count(graph), 30) * 2 + tag_bonus + missing_tag_penalty
  end

  defp current_focus_text(common_tags, graphs) do
    case Enum.take(common_tags, 3) do
      [] ->
        if graphs == [] do
          nil
        else
          "You'll find #{length(graphs)} public grids here, with #{total_node_count(graphs)} connected ideas to explore."
        end

      tags ->
        "You'll find thinking on #{human_join(tags)} here, spread across #{length(graphs)} public grids."
    end
  end

  defp graph_node_count(%{node_count: count}) when is_integer(count), do: count

  defp graph_node_count(graph) do
    nodes =
      (Map.get(graph, :data) || %{})
      |> then(fn data -> Map.get(data, "nodes") || Map.get(data, :nodes) || [] end)

    if is_list(nodes) do
      Enum.count(nodes, fn node -> !Map.get(node, "compound", false) end)
    else
      0
    end
  end

  defp profile_idea_count_label(1), do: "1 idea"
  defp profile_idea_count_label(count), do: "#{count} ideas"

  defp profile_grid_title(graph) do
    title = Map.get(graph, :title) || "Untitled grid"

    case String.next_grapheme(title) do
      {first, rest} -> String.upcase(first) <> rest
      nil -> "Untitled grid"
    end
  end

  defp profile_grid_row_accent(tags) do
    colors = tags |> Enum.map(&tag_color_hex/1) |> Enum.uniq()

    gradient_colors =
      case colors do
        [] -> [tag_color_hex(""), "#cbd5e1"]
        [color] -> [color, "#cbd5e1"]
        colors -> colors
      end

    "background-image: linear-gradient(180deg, #{Enum.join(gradient_colors, ", ")});"
  end

  defp total_node_count(graphs) do
    Enum.reduce(graphs, 0, fn graph, count -> count + graph_node_count(graph) end)
  end

  defp graph_unix(graph) do
    case graph.updated_at || graph.inserted_at do
      %DateTime{} = datetime -> DateTime.to_unix(datetime)
      _ -> 0
    end
  end

  defp human_join([]), do: ""
  defp human_join([one]), do: one
  defp human_join([first, second]), do: "#{first} and #{second}"

  defp human_join(items) do
    {last, rest} = List.pop_at(items, -1)
    Enum.join(rest, ", ") <> ", and " <> last
  end

  # --- Profile class helpers ---

  defp theme_bg_class(_),
    do: "bg-[linear-gradient(180deg,#f8fafc_0%,#eef7f6_46%,#fff7ed_100%)]"

  defp theme_card_class(_), do: "bg-white border-gray-200"

  defp theme_banner_class(_),
    do: "bg-[linear-gradient(135deg,#0f172a_0%,#0f766e_58%,#d97706_100%)]"

  defp theme_avatar_border_class(_), do: "border-white bg-white"

  defp theme_avatar_default_class(_), do: "bg-indigo-100 text-indigo-600"

  defp theme_subtext_class(_), do: "text-gray-500"
  defp theme_link_class(_), do: "text-teal-700 hover:text-teal-600"

  defp theme_tag_class(_), do: "bg-teal-50 text-teal-700 ring-1 ring-teal-200"

  defp profile_bio_size(bio) when is_binary(bio) do
    bio
    |> String.trim()
    |> String.length()
    |> profile_bio_size()
  end

  defp profile_bio_size(length) when length <= 80, do: "short"
  defp profile_bio_size(length) when length <= 160, do: "medium"
  defp profile_bio_size(_length), do: "long"

  defp profile_bio_text_class(bio) when is_binary(bio),
    do: bio |> profile_bio_size() |> profile_bio_size_text_class()

  defp profile_bio_size_text_class("short"),
    do: "text-2xl leading-9 sm:text-3xl sm:leading-10"

  defp profile_bio_size_text_class("medium"),
    do: "text-xl leading-8 sm:text-2xl sm:leading-9"

  defp profile_bio_size_text_class("long"), do: "text-lg leading-7 sm:text-xl sm:leading-8"
end
