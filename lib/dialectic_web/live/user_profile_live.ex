defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.Graph
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.ProfileBanner
  alias Dialectic.Accounts.ProfileLinks
  alias Dialectic.Follows
  alias Dialectic.Highlights
  alias DialecticWeb.Utils.NodeTitleHelper
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

        # Load private library data only when viewing your own profile.
        {my_stats, private_graphs, noted_notes, saved_highlights, followed_graphs} =
          if is_own_profile? do
            stats = Dialectic.DbActions.Notes.get_my_stats(profile_user)

            {stats, private_graphs(stats), noted_notes(stats),
             Highlights.list_user_highlights(profile_user),
             Follows.list_user_following_graphs(profile_user)}
          else
            {nil, [], [], [], []}
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
          |> assign(:graphs, graphs)
          |> assign(:featured_graphs, featured_graphs)
          |> assign(:current_focus, current_focus)
          |> assign(:common_tags, common_tags)
          |> assign(:profile_links, ProfileLinks.display_links(profile_user.profile_links))
          |> assign(:is_own_profile?, is_own_profile?)
          |> assign(
            :following_profile?,
            following_profile?(socket.assigns[:current_user], profile_user)
          )
          |> assign(:my_stats, my_stats)
          |> assign(:private_graphs, private_graphs)
          |> assign(:noted_notes, noted_notes)
          |> assign(:saved_highlights, saved_highlights)
          |> assign(:followed_graphs, followed_graphs)
          |> assign(:graph_to_delete, nil)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("show_delete_modal", %{"title" => title}, socket) do
    {:noreply, assign(socket, :graph_to_delete, title)}
  end

  @impl true
  def handle_event("lv:clear-flash", %{"key" => key}, socket) do
    {:noreply, clear_flash(socket, flash_key(key))}
  end

  @impl true
  def handle_event("lv:clear-flash", _params, socket) do
    {:noreply, clear_flash(socket)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :graph_to_delete, nil)}
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

  @impl true
  def handle_event("confirm_delete_graph", _params, socket) do
    title = socket.assigns.graph_to_delete
    user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    case Dialectic.DbActions.Graphs.soft_delete_user_graph(title, user) do
      {:ok, _graph} ->
        # Reload both my_stats and public graphs to reflect the deleted graph
        my_stats = Dialectic.DbActions.Notes.get_my_stats(user)
        graphs = Accounts.list_user_public_graphs(profile_user)
        stats = Accounts.get_profile_stats(profile_user, graphs)
        common_tags = Accounts.get_common_tags(profile_user, graphs: graphs)
        featured_graphs = featured_graphs(graphs)
        current_focus = current_focus_text(common_tags, graphs)

        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> assign(:my_stats, my_stats)
         |> assign(:private_graphs, private_graphs(my_stats))
         |> assign(:graphs, graphs)
         |> assign(:featured_graphs, featured_graphs)
         |> assign(:current_focus, current_focus)
         |> assign(:stats, stats)
         |> assign(:common_tags, common_tags)
         |> put_flash(:info, "Grid \"#{title}\" has been deleted.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> put_flash(:error, "Grid not found.")}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> put_flash(:error, "You don't have permission to delete this grid.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> put_flash(:error, "Unable to delete this grid. Please try again.")}
    end
  end

  defp flash_key("info"), do: :info
  defp flash_key("error"), do: :error

  defp profile_link_icon(%{kind: "email"}), do: "hero-envelope"
  defp profile_link_icon(_), do: "hero-link"

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

  defp graph_author_name(%Graph{user: %User{} = user}), do: User.effective_username(user)
  defp graph_author_name(_graph), do: nil

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

  defp private_graphs(%{graphs: graphs}) when is_list(graphs) do
    Enum.filter(graphs, &(&1.is_public != true))
  end

  defp private_graphs(_stats), do: []

  defp noted_notes(%{notes: notes}) when is_list(notes) do
    notes
    |> Enum.filter(& &1.is_noted)
    |> Enum.map(&put_note_node_title/1)
  end

  defp noted_notes(_stats), do: []

  defp put_note_node_title(%{graph: %Graph{} = graph, node_id: node_id} = note) do
    Map.put(note, :node_title, node_title(graph, node_id))
  end

  defp put_note_node_title(%{node_id: node_id} = note) do
    Map.put(note, :node_title, fallback_node_title(node_id))
  end

  defp note_path(%{graph: %Graph{} = graph, node_id: node_id}), do: graph_path(graph, node_id)

  defp note_graph_title(%{graph: %Graph{title: title}}), do: title
  defp note_graph_title(%{graph_title: title}) when is_binary(title), do: title
  defp note_graph_title(_note), do: "Grid"

  defp node_title(%Graph{} = graph, node_id) when is_binary(node_id) and node_id != "" do
    graph
    |> graph_node(node_id)
    |> case do
      nil -> fallback_node_title(node_id)
      node -> NodeTitleHelper.extract_node_title(node, max_length: 72)
    end
  end

  defp node_title(_graph, node_id), do: fallback_node_title(node_id)

  defp fallback_node_title(node_id) when is_binary(node_id) and node_id != "",
    do: "Node #{node_id}"

  defp fallback_node_title(_node_id), do: "Node"

  defp highlight_path(%{mudg: %Graph{} = graph, node_id: node_id, id: id}) do
    graph_path(graph, node_id, highlight: id)
  end

  defp highlight_graph_title(%{mudg: %Graph{title: title}}), do: title
  defp highlight_graph_title(%{mudg_id: title}) when is_binary(title), do: title
  defp highlight_graph_title(_highlight), do: "Grid"

  defp highlight_note?(%{note: note}) when is_binary(note), do: String.trim(note) != ""
  defp highlight_note?(_highlight), do: false

  defp highlight_node_title(%{mudg: %Graph{} = graph, node_id: node_id})
       when is_binary(node_id) and node_id != "" do
    node_title(graph, node_id)
  end

  defp highlight_node_title(%{node_id: node_id}) when is_binary(node_id) and node_id != "",
    do: fallback_node_title(node_id)

  defp highlight_node_title(_highlight), do: "Node"

  defp graph_node(%Graph{data: data}, node_id) when is_map(data) do
    nodes = Map.get(data, "nodes") || Map.get(data, :nodes) || []

    if is_list(nodes) do
      Enum.find(nodes, &((Map.get(&1, "id") || Map.get(&1, :id)) == node_id))
    end
  end

  defp graph_node(_graph, _node_id), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Delete Confirmation Modal --%>
    <.modal id="delete-graph-modal" on_cancel={JS.push("cancel_delete")}>
      <div class="text-center">
        <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 mb-4">
          <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
        </div>
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Delete Grid</h3>
        <p class="text-sm text-gray-500 mb-6">
          Are you sure you want to delete <strong class="text-gray-700">"{@graph_to_delete}"</strong>?
          This will hide the grid from your profile.
        </p>
        <div class="flex justify-center gap-3">
          <button
            type="button"
            phx-click={hide_modal("delete-graph-modal") |> JS.push("cancel_delete")}
            class="rounded-lg px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 transition"
          >
            Cancel
          </button>
          <button
            type="button"
            id="confirm-delete-graph-btn"
            phx-click={hide_modal("delete-graph-modal") |> JS.push("confirm_delete_graph")}
            class="rounded-lg px-4 py-2 text-sm font-semibold text-white bg-red-600 hover:bg-red-700 transition"
          >
            Delete Grid
          </button>
        </div>
      </div>
    </.modal>

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

    <.flash kind={:info} title="Success!" flash={@flash} id="profile-flash-info" />
    <.flash kind={:error} title="Error!" flash={@flash} id="profile-flash-error" />

    <div class={["min-h-screen w-full", theme_bg_class(@theme)]}>
      <div class="mx-auto max-w-6xl px-4 pb-8 pt-4 sm:px-6 sm:pb-12 sm:pt-6">
        <%!-- Profile Header --%>
        <div class={[
          "relative overflow-hidden rounded-[2rem] border border-slate-900/10 bg-slate-950 text-white shadow-[0_36px_110px_-56px_rgba(15,23,42,0.85)]"
        ]}>
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
                <%= if @is_own_profile? do %>
                  <.link
                    navigate={~p"/activity"}
                    id="profile-activity-link"
                    class="inline-flex items-center gap-1.5 rounded-xl border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-white/15"
                  >
                    <.icon name="hero-bell" class="w-4 h-4" /> Activity
                  </.link>
                  <.link
                    navigate={~p"/users/settings"}
                    id="profile-settings-link"
                    class="inline-flex items-center gap-1.5 rounded-xl bg-white px-4 py-2 text-sm font-semibold text-slate-950 shadow-sm transition hover:bg-cyan-50"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" /> Account Settings
                  </.link>
                <% else %>
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
                    {tag}
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @featured_graphs != [] do %>
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

            <div class="grid gap-4 lg:grid-cols-12">
              <%= for {graph, index} <- Enum.with_index(@featured_graphs) do %>
                <.grid_card
                  graph={graph}
                  id={"profile-featured-grid-" <> (graph.slug || Integer.to_string(:erlang.phash2(graph.title || "")))}
                  variant={:featured}
                  featured_index={index}
                  tag_limit={3}
                />
              <% end %>
            </div>
          </section>
        <% end %>

        <%!-- Graphs Section --%>
        <div class="mt-10 border-t border-slate-200 pt-8">
          <button
            type="button"
            phx-click={
              JS.toggle(to: "#public-grids-content")
              |> JS.toggle(to: "#public-grids-chevron-down")
              |> JS.toggle(to: "#public-grids-chevron-up")
            }
            class={[
              "w-full flex items-center justify-between text-left group mb-4",
              theme_heading_class(@theme)
            ]}
          >
            <h2 class="text-lg sm:text-xl font-semibold tracking-tight">
              <%= if @is_own_profile? do %>
                Public grids
              <% else %>
                Grid archive by {@effective_username}
              <% end %>
              <span class={[
                "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                theme_tag_class(@theme)
              ]}>
                {length(@graphs)}
              </span>
            </h2>
            <span>
              <span id="public-grids-chevron-up" class={if(@featured_graphs != [], do: "hidden")}>
                <.icon name="hero-chevron-up" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
              </span>
              <span
                id="public-grids-chevron-down"
                class={if(@featured_graphs != [], do: "", else: "hidden")}
              >
                <.icon name="hero-chevron-down" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
              </span>
            </span>
          </button>

          <div id="public-grids-content" class={if(@featured_graphs != [], do: "hidden")}>
            <%= if @graphs == [] do %>
              <div class={["rounded-xl border p-8 text-center shadow-sm", theme_card_class(@theme)]}>
                <.icon
                  name="hero-light-bulb"
                  class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
                />
                <p class={["text-sm", theme_subtext_class(@theme)]}>
                  No public grids yet.
                </p>
                <%= if @is_own_profile? do %>
                  <.link
                    navigate={~p"/"}
                    class={[
                      "mt-4 inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                      theme_button_class(@theme)
                    ]}
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> Create your first grid
                  </.link>
                <% end %>
              </div>
            <% else %>
              <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <%= for graph <- @graphs do %>
                  <.grid_card
                    graph={graph}
                    id={"profile-public-grid-" <> (graph.slug || Integer.to_string(:erlang.phash2(graph.title || "")))}
                    tag_limit={4}
                  >
                    <:action :if={@is_own_profile?}>
                      <button
                        type="button"
                        phx-click={
                          JS.push("show_delete_modal", value: %{title: graph.title})
                          |> show_modal("delete-graph-modal")
                        }
                        id={"delete-public-grid-btn-" <> (graph.slug || Integer.to_string(:erlang.phash2(graph.title || "")))}
                        class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-red-100 bg-red-50 text-red-600 transition hover:bg-red-100"
                        title="Delete grid"
                        aria-label={"Delete " <> (graph.title || "grid")}
                      >
                        <.icon name="hero-trash" class="h-4 w-4" />
                      </button>
                    </:action>
                  </.grid_card>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Private thinking library (own profile only) --%>
        <%= if @is_own_profile? && @my_stats do %>
          <section
            id="profile-thinking-library"
            class="mt-12 overflow-hidden rounded-[2rem] border border-slate-900 bg-slate-950 shadow-[0_30px_90px_-58px_rgba(15,23,42,0.9)]"
          >
            <div class="flex flex-col gap-3 border-b border-white/10 p-5 sm:flex-row sm:items-end sm:justify-between sm:p-6">
              <div>
                <p class="text-xs font-semibold uppercase text-cyan-200">
                  Your saved thinking
                </p>
                <h2 class="mt-1 text-3xl font-semibold text-white">
                  Bookmarks and notes
                </h2>
              </div>
            </div>

            <div class="grid gap-px bg-white/10 lg:grid-cols-2">
              <section id="profile-noted-panel" class="overflow-hidden bg-white">
                <div class="relative flex items-start justify-between gap-4 border-b-2 border-slate-200 bg-slate-50/80 p-5 after:absolute after:bottom-[-2px] after:left-5 after:h-1 after:w-24 after:rounded-full after:bg-amber-400">
                  <div class="flex min-w-0 items-start gap-3">
                    <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-amber-50 text-amber-700 ring-1 ring-amber-200">
                      <.icon name="hero-bookmark" class="h-5 w-5" />
                    </span>
                    <div>
                      <h3 class="text-base font-semibold tracking-tight text-slate-950">
                        Bookmarked ideas
                        <span class={[
                          "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                          theme_tag_class(@theme)
                        ]}>
                          {length(@noted_notes)}
                        </span>
                      </h3>
                      <p class="mt-1 text-sm leading-5 text-slate-500">
                        Keep useful nodes close and add your own notes.
                      </p>
                    </div>
                  </div>
                </div>

                <div
                  id="profile-noted-content"
                  class="max-h-[34rem] overflow-y-auto divide-y divide-slate-100"
                >
                  <%= if @noted_notes == [] do %>
                    <div class="p-8 text-center">
                      <.icon
                        name="hero-bookmark"
                        class={"mx-auto mb-3 h-10 w-10 " <> theme_subtext_class(@theme)}
                      />
                      <p class={["text-sm", theme_subtext_class(@theme)]}>
                        Bookmark a useful node and add a note to begin your personal collection.
                      </p>
                    </div>
                  <% else %>
                    <%= for note <- @noted_notes do %>
                      <.link
                        navigate={note_path(note)}
                        id={"profile-noted-note-#{note.id}"}
                        class="group flex gap-3 p-4 transition hover:bg-slate-50"
                      >
                        <span class="mt-0.5 inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-amber-50 text-amber-700 ring-1 ring-amber-200">
                          <.icon name="hero-bookmark" class="h-4 w-4" />
                        </span>
                        <span class="min-w-0">
                          <span class="block line-clamp-2 text-sm font-semibold leading-6 text-slate-900 group-hover:text-indigo-700">
                            {note.node_title}
                          </span>
                          <span class="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                            <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
                            <span>{note_graph_title(note)}</span>
                          </span>
                        </span>
                      </.link>
                    <% end %>
                  <% end %>
                </div>
              </section>

              <section id="profile-highlights-panel" class="overflow-hidden bg-white">
                <div class="relative flex items-start justify-between gap-4 border-b-2 border-slate-200 bg-slate-50/80 p-5 after:absolute after:bottom-[-2px] after:left-5 after:h-1 after:w-24 after:rounded-full after:bg-indigo-400">
                  <div class="flex min-w-0 items-start gap-3">
                    <span class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-indigo-50 text-indigo-700 ring-1 ring-indigo-200">
                      <.icon name="hero-bookmark-square" class="h-5 w-5" />
                    </span>
                    <div>
                      <h3 class="text-base font-semibold tracking-tight text-slate-950">
                        Quotes and notes
                        <span class={[
                          "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                          theme_tag_class(@theme)
                        ]}>
                          {length(@saved_highlights)}
                        </span>
                      </h3>
                      <p class="mt-1 text-sm leading-5 text-slate-500">
                        Save passages and capture why they matter to you.
                      </p>
                    </div>
                  </div>
                </div>

                <div
                  id="highlights-content"
                  class="max-h-[34rem] overflow-y-auto divide-y divide-slate-100"
                >
                  <%= if @saved_highlights == [] do %>
                    <div class="p-8 text-center">
                      <.icon
                        name="hero-bookmark-square"
                        class={"mx-auto mb-3 h-10 w-10 " <> theme_subtext_class(@theme)}
                      />
                      <p class={["text-sm", theme_subtext_class(@theme)]}>
                        Select a useful passage in any grid, then save it with your own note.
                      </p>
                    </div>
                  <% else %>
                    <%= for highlight <- @saved_highlights do %>
                      <.link
                        navigate={highlight_path(highlight)}
                        id={"profile-highlight-#{highlight.id}"}
                        class="group block p-4 transition hover:bg-slate-50"
                      >
                        <blockquote class="border-l-2 border-indigo-300 pl-3 text-sm font-medium leading-6 text-slate-900 line-clamp-4 group-hover:text-indigo-700">
                          “{highlight.selected_text_snapshot}”
                        </blockquote>

                        <p
                          :if={highlight_note?(highlight)}
                          class={["mt-3 text-xs leading-5 line-clamp-2", theme_subtext_class(@theme)]}
                        >
                          {highlight.note}
                        </p>

                        <div class={[
                          "mt-3 flex flex-wrap items-center gap-1.5 text-xs",
                          theme_subtext_class(@theme)
                        ]}>
                          <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
                          <span>{highlight_graph_title(highlight)}</span>
                          <span>·</span>
                          <span>{highlight_node_title(highlight)}</span>
                        </div>
                      </.link>
                    <% end %>
                  <% end %>
                </div>
              </section>
            </div>
          </section>

          <section id="profile-followed-grids" class="mt-8">
            <div class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p class="text-xs font-semibold uppercase text-teal-700">
                  Following
                </p>
                <h2 class="text-lg font-semibold tracking-tight text-slate-950 sm:text-xl">
                  Grids you follow
                  <span class={[
                    "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                    theme_tag_class(@theme)
                  ]}>
                    {length(@followed_graphs)}
                  </span>
                </h2>
              </div>
            </div>

            <%= if @followed_graphs == [] do %>
              <div
                id="profile-followed-grids-empty"
                class={["rounded-xl border p-8 text-center shadow-sm", theme_card_class(@theme)]}
              >
                <.icon
                  name="hero-squares-2x2"
                  class={"mx-auto mb-3 h-10 w-10 " <> theme_subtext_class(@theme)}
                />
                <p class={["text-sm", theme_subtext_class(@theme)]}>
                  Follow grids to keep them close to your profile.
                </p>
              </div>
            <% else %>
              <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <%= for graph <- @followed_graphs do %>
                  <.grid_card
                    graph={graph}
                    id={"profile-followed-grid-" <> (graph.slug || Integer.to_string(:erlang.phash2(graph.title || "")))}
                    author_name={graph_author_name(graph)}
                    author_marker="by"
                    label="Following"
                    tag_limit={3}
                  />
                <% end %>
              </div>
            <% end %>
          </section>

          <%!-- Private grids Section --%>
          <div id="profile-grid-workspace" class="mt-8">
            <button
              type="button"
              phx-click={
                JS.toggle(to: "#all-grids-content")
                |> JS.toggle(to: "#all-grids-chevron-down")
                |> JS.toggle(to: "#all-grids-chevron-up")
              }
              class={[
                "w-full flex items-center justify-between text-left group mb-4",
                theme_heading_class(@theme)
              ]}
            >
              <h2 class="text-lg sm:text-xl font-semibold tracking-tight">
                Private grids
                <span class={[
                  "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                  theme_tag_class(@theme)
                ]}>
                  {length(@private_graphs)}
                </span>
              </h2>
              <span>
                <span id="all-grids-chevron-up" class="hidden">
                  <.icon name="hero-chevron-up" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
                <span id="all-grids-chevron-down">
                  <.icon name="hero-chevron-down" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
              </span>
            </button>

            <div id="all-grids-content" class="hidden">
              <%= if @private_graphs == [] do %>
                <div class={[
                  "rounded-xl border p-8 text-center shadow-sm",
                  theme_card_class(@theme)
                ]}>
                  <.icon
                    name="hero-document-text"
                    class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
                  />
                  <p class={["text-sm", theme_subtext_class(@theme)]}>
                    No private grids. Private drafts and unpublished explorations will appear here.
                  </p>
                  <.link
                    navigate={~p"/"}
                    class={[
                      "mt-4 inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                      theme_button_class(@theme)
                    ]}
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> Create a private grid
                  </.link>
                </div>
              <% else %>
                <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  <%= for g <- @private_graphs do %>
                    <.grid_card
                      graph={g}
                      id={"profile-workspace-grid-" <> (g.slug || Integer.to_string(:erlang.phash2(g.title || "")))}
                      tag_limit={3}
                      show_visibility={true}
                    >
                      <:action>
                        <button
                          type="button"
                          phx-click={
                            JS.push("show_delete_modal", value: %{title: g.title})
                            |> show_modal("delete-graph-modal")
                          }
                          id={"delete-grid-btn-" <> (g.slug || Integer.to_string(:erlang.phash2(g.title || "")))}
                          class="inline-flex h-8 w-8 items-center justify-center rounded-full border border-red-100 bg-red-50 text-red-600 transition hover:bg-red-100"
                          title="Delete grid"
                          aria-label={"Delete " <> (g.title || "grid")}
                        >
                          <.icon name="hero-trash" class="h-4 w-4" />
                        </button>
                      </:action>
                    </.grid_card>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

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

  defp theme_heading_class(_), do: "text-gray-900"
  defp theme_subtext_class(_), do: "text-gray-500"
  defp theme_link_class(_), do: "text-teal-700 hover:text-teal-600"

  defp theme_button_class(_), do: "bg-slate-950 text-white hover:bg-slate-800"

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
