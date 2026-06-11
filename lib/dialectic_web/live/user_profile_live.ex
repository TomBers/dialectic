defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.ProfileBanner
  alias Dialectic.Accounts.ProfileLinks
  alias Dialectic.Follows
  alias DialecticWeb.Utils.NodeTitleHelper
  import DialecticWeb.HomeGridRowComp

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

        effective_username = User.effective_username(profile_user)
        common_tags = Accounts.get_common_tags(profile_user, graphs: graphs)
        featured_graphs = featured_graphs(graphs)
        current_focus = current_focus_text(common_tags, graphs)

        is_own_profile? =
          case socket.assigns[:current_user] do
            %User{id: id} when id == profile_user.id -> true
            _ -> false
          end

        # Load My Ideas data when viewing own profile
        {my_stats, noted_notes} =
          if is_own_profile? do
            stats = Dialectic.DbActions.Notes.get_my_stats(profile_user)

            noted =
              stats.notes
              |> Enum.filter(& &1.is_noted)
              |> Enum.map(fn note ->
                node_title =
                  (note.graph.data["nodes"] || [])
                  |> Enum.find_value(fn n ->
                    if n["id"] == note.node_id do
                      case NodeTitleHelper.extract_node_title(n) do
                        "Untitled" -> nil
                        title -> title
                      end
                    end
                  end)

                Map.put(note, :node_title, node_title || "Node #{note.node_id}")
              end)

            {stats, noted}
          else
            {nil, []}
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
          |> assign(:noted_notes, noted_notes)
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
         |> put_flash(:info, "Profile followed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not follow this profile.")}
    end
  end

  @impl true
  def handle_event("unfollow_profile", _params, socket) do
    current_user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    {:ok, _count} = Follows.unfollow_user(current_user, profile_user)

    {:noreply,
     socket
     |> assign(:following_profile?, false)
     |> put_flash(:info, "Profile unfollowed.")}
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

    <.flash kind={:info} title="Success!" flash={@flash} id="profile-flash-info" />
    <.flash kind={:error} title="Error!" flash={@flash} id="profile-flash-error" />

    <div class={["min-h-screen w-full", theme_bg_class(@theme)]}>
      <div class="mx-auto max-w-6xl px-4 sm:px-6 py-8 sm:py-12">
        <%!-- Profile Header --%>
        <div class={[
          "overflow-hidden rounded-[1.75rem] border shadow-[0_28px_70px_-48px_rgba(15,23,42,0.45)]",
          theme_card_class(@theme)
        ]}>
          <%!-- Banner area --%>
          <%= cond do %>
            <% @profile_banner_url -> %>
              <div class="h-36 overflow-hidden sm:h-44">
                <img
                  src={@profile_banner_url}
                  alt={"#{@effective_username}'s profile banner"}
                  class="h-full w-full object-cover"
                />
              </div>
            <% true -> %>
              <div class={["h-36 sm:h-44", theme_banner_class(@theme)]}></div>
          <% end %>

          <div class="relative px-5 pb-6 sm:px-8 sm:pb-8">
            <%!-- Avatar --%>
            <div class="flex flex-col gap-4 -mt-12 sm:-mt-14 sm:flex-row sm:items-end">
              <div class={[
                "h-24 w-24 sm:h-28 sm:w-28 rounded-full border-4 flex items-center justify-center overflow-hidden flex-shrink-0",
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
                <h1 class={[
                  "truncate text-3xl font-semibold tracking-tight sm:text-4xl",
                  theme_heading_class(@theme)
                ]}>
                  {@effective_username}
                </h1>
              </div>

              <div class="flex items-center gap-2 pb-1">
                <%= if @is_own_profile? do %>
                  <.link
                    navigate={~p"/activity"}
                    id="profile-activity-link"
                    class="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50"
                  >
                    <.icon name="hero-bell" class="w-4 h-4" /> Activity
                  </.link>
                  <.link
                    navigate={~p"/users/settings"}
                    id="profile-settings-link"
                    class={[
                      "inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                      theme_button_class(@theme)
                    ]}
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
                          do: "border border-slate-200 bg-white text-slate-700 hover:bg-slate-50",
                          else: "bg-slate-950 text-white hover:bg-slate-800"
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
                      class="inline-flex items-center gap-1.5 rounded-xl bg-slate-950 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800"
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
                  <p class="max-w-3xl text-xl font-medium leading-8 tracking-tight text-slate-900 sm:text-2xl sm:leading-9">
                    {@profile_user.bio}
                  </p>
                <% end %>

                <%= if @current_focus do %>
                  <div class="mt-4 inline-flex max-w-2xl items-start gap-2 rounded-2xl bg-slate-50 px-3 py-2 text-sm leading-6 text-slate-600 ring-1 ring-slate-200">
                    <.icon name="hero-sparkles" class="mt-0.5 h-4 w-4 shrink-0 text-indigo-500" />
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
                      class={[
                        "inline-flex items-center gap-1.5 text-sm font-medium transition",
                        theme_link_class(@theme)
                      ]}
                    >
                      <.icon name={profile_link_icon(link)} class="w-4 h-4" />
                      {link.label}
                    </a>
                  <% end %>

                  <span class={[
                    "inline-flex items-center gap-1.5 text-sm",
                    theme_subtext_class(@theme)
                  ]}>
                    <.icon name="hero-calendar-days" class="w-4 h-4" />
                    Member since {Calendar.strftime(@stats.member_since, "%B %Y")}
                  </span>
                </div>
              </div>

              <div class="rounded-2xl border border-slate-200 bg-slate-50/80 p-3">
                <div class="grid grid-cols-3 gap-2 text-center">
                  <div>
                    <p class="text-lg font-semibold leading-6 text-slate-950">
                      {@stats.graphs_created}
                    </p>
                    <p class="mt-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                      Grids
                    </p>
                  </div>
                  <div>
                    <p class="text-lg font-semibold leading-6 text-slate-950">
                      {@stats.total_nodes}
                    </p>
                    <p class="mt-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                      Ideas
                    </p>
                  </div>
                  <div>
                    <p class="text-lg font-semibold leading-6 text-slate-950">
                      {format_member_duration(@stats.member_since)}
                    </p>
                    <p class="mt-0.5 text-[10px] font-semibold uppercase tracking-[0.12em] text-slate-500">
                      Days
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Common Tags --%>
            <%= if @common_tags != [] do %>
              <div class="mt-6 flex flex-wrap items-center gap-1.5 border-t border-slate-100 pt-4">
                <span class={[
                  "text-xs font-semibold uppercase tracking-[0.14em]",
                  theme_subtext_class(@theme)
                ]}>
                  Topics
                </span>
                <%= for tag <- @common_tags do %>
                  <span class={[
                    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                    theme_tag_class(@theme)
                  ]}>
                    {tag}
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @featured_graphs != [] do %>
          <section id="profile-start-here" class="mt-10">
            <div class="mb-4 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.18em] text-indigo-600">
                  Start here
                </p>
                <h2 class="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
                  Entry points
                </h2>
              </div>

              <p class="max-w-xl text-sm leading-6 text-slate-600 sm:text-right">
                A few substantial public grids selected from depth, tags, and recency.
              </p>
            </div>

            <div class="grid gap-4 lg:grid-cols-3">
              <%= for {graph, index} <- Enum.with_index(@featured_graphs) do %>
                <.link
                  navigate={graph_path(graph)}
                  class={[
                    "group flex flex-col overflow-hidden border border-slate-200 bg-white shadow-sm transition hover:-translate-y-0.5 hover:border-indigo-200 hover:shadow-md",
                    featured_card_class(index)
                  ]}
                >
                  <div class={[
                    "border-b border-slate-100 bg-gradient-to-br from-slate-950 via-indigo-950 to-sky-900",
                    featured_card_header_class(index)
                  ]}>
                    <div class="flex items-start justify-between gap-3">
                      <span class="inline-flex items-center rounded-full bg-white/10 px-2.5 py-1 text-[11px] font-semibold text-white ring-1 ring-white/20">
                        {exploration_label(graph)}
                      </span>
                      <span class="shrink-0 text-xs font-semibold text-white/60">
                        {graph_updated_label(graph)}
                      </span>
                    </div>
                  </div>

                  <div class={featured_card_body_class(index)}>
                    <h3 class={[
                      "font-semibold leading-7 text-slate-950 group-hover:text-indigo-700",
                      featured_card_title_class(index)
                    ]}>
                      {graph.title}
                    </h3>

                    <p class="mt-2 line-clamp-2 min-h-12 text-sm leading-6 text-slate-600">
                      {graph_preview_sentence(graph)}
                    </p>

                    <div class="mt-4 flex min-h-12 flex-wrap content-start gap-1.5">
                      <%= for tag <- Enum.take(graph.tags || [], 3) do %>
                        <span class={[
                          "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                          table_tag_color_class(tag, @theme)
                        ]}>
                          #{tag}
                        </span>
                      <% end %>
                    </div>

                    <div class="mt-auto flex items-center justify-between border-t border-slate-100 pt-3 text-xs font-medium text-slate-500">
                      <span>{graph_node_count(graph)} ideas</span>
                      <span class="inline-flex items-center gap-1 text-indigo-600 group-hover:text-indigo-700">
                        Open grid <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                      </span>
                    </div>
                  </div>
                </.link>
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
                Public grid archive
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
              <span id="public-grids-chevron-up">
                <.icon name="hero-chevron-up" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
              </span>
              <span id="public-grids-chevron-down" class="hidden">
                <.icon name="hero-chevron-down" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
              </span>
            </span>
          </button>

          <div id="public-grids-content">
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
              <div class={["overflow-hidden rounded-2xl border shadow-sm", theme_card_class(@theme)]}>
                <div class="divide-y divide-slate-100">
                  <%= for graph <- @graphs do %>
                    <.home_grid_row
                      graph={graph}
                      id={"profile-public-grid-" <> (graph.slug || Integer.to_string(:erlang.phash2(graph.title || "")))}
                      variant={:comfortable}
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
                          class="inline-flex h-9 w-9 items-center justify-center rounded-lg text-slate-400 transition hover:bg-red-50 hover:text-red-600"
                          title="Delete grid"
                          aria-label={"Delete " <> (graph.title || "grid")}
                        >
                          <.icon name="hero-trash" class="h-4 w-4" />
                        </button>
                      </:action>
                    </.home_grid_row>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- My Ideas Section (own profile only) --%>
        <%= if @is_own_profile? && @my_stats do %>
          <div class="mt-8">
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
                All My Grids
                <span class={[
                  "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                  theme_tag_class(@theme)
                ]}>
                  {length(@my_stats.graphs)}
                </span>
              </h2>
              <span>
                <span id="all-grids-chevron-up">
                  <.icon name="hero-chevron-up" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
                <span id="all-grids-chevron-down" class="hidden">
                  <.icon name="hero-chevron-down" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
              </span>
            </button>

            <div id="all-grids-content">
              <%= if @my_stats.graphs == [] do %>
                <div class={[
                  "rounded-xl border p-8 text-center shadow-sm",
                  theme_card_class(@theme)
                ]}>
                  <.icon
                    name="hero-document-text"
                    class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
                  />
                  <p class={["text-sm", theme_subtext_class(@theme)]}>
                    No grids yet. Ask a question to create your first one!
                  </p>
                  <.link
                    navigate={~p"/"}
                    class={[
                      "mt-4 inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                      theme_button_class(@theme)
                    ]}
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> Create a grid
                  </.link>
                </div>
              <% else %>
                <div class={["rounded-xl border shadow-sm overflow-hidden", theme_card_class(@theme)]}>
                  <div class="overflow-x-auto">
                    <table class="min-w-full border-separate border-spacing-0 text-left text-sm">
                      <thead class={table_header_class(@theme)}>
                        <tr>
                          <th class="px-4 py-2.5 font-semibold">Grid</th>
                          <th class="px-4 py-2.5 font-semibold">Tags</th>
                          <th class="px-4 py-2.5 text-center font-semibold">Visibility</th>
                          <th class="px-4 py-2.5 text-center font-semibold">Nodes</th>
                          <th class="px-4 py-2.5 text-right font-semibold">Open</th>
                          <th class="px-4 py-2.5 text-right font-semibold">Delete</th>
                        </tr>
                      </thead>
                      <tbody class={table_body_class(@theme)}>
                        <%= for g <- @my_stats.graphs do %>
                          <tr class={table_row_class(@theme)}>
                            <td class="px-4 py-3">
                              <.link
                                navigate={graph_path(g)}
                                class={[
                                  "hidden lg:block font-semibold hover:underline",
                                  table_link_class(@theme)
                                ]}
                              >
                                {g.title}
                              </.link>
                              <.link
                                navigate={graph_path(g)}
                                class={[
                                  "lg:hidden font-semibold hover:underline",
                                  table_link_class(@theme)
                                ]}
                              >
                                {g.title}
                              </.link>
                            </td>
                            <td class="px-4 py-3">
                              <div class="flex flex-wrap gap-1">
                                <%= for tag <- Enum.take(g.tags || [], 3) do %>
                                  <span class={[
                                    "inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold ring-1 ring-inset",
                                    table_tag_color_class(tag, @theme)
                                  ]}>
                                    #{tag}
                                  </span>
                                <% end %>
                              </div>
                            </td>
                            <td class="px-4 py-3 text-center">
                              <%= if g.is_public do %>
                                <span class="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
                                  <.icon name="hero-globe-alt" class="h-3 w-3" /> Public
                                </span>
                              <% else %>
                                <span class="inline-flex items-center gap-1 rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600">
                                  <.icon name="hero-lock-closed" class="h-3 w-3" /> Private
                                </span>
                              <% end %>
                            </td>
                            <td class={["px-4 py-3 text-center", theme_subtext_class(@theme)]}>
                              {g.node_count}
                            </td>
                            <td class="px-4 py-3 text-right">
                              <.link
                                navigate={graph_path(g)}
                                class={[
                                  "hidden lg:inline-flex h-8 w-8 items-center justify-center rounded-full",
                                  theme_icon_button_class(@theme)
                                ]}
                                aria-label={"Open " <> (g.title || "grid")}
                              >
                                <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                              </.link>
                              <.link
                                navigate={graph_path(g)}
                                class={[
                                  "lg:hidden inline-flex h-8 w-8 items-center justify-center rounded-full",
                                  theme_icon_button_class(@theme)
                                ]}
                                aria-label={"Open " <> (g.title || "grid")}
                              >
                                <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                              </.link>
                            </td>
                            <td class="px-4 py-3 text-right">
                              <button
                                type="button"
                                phx-click={
                                  JS.push("show_delete_modal", value: %{title: g.title})
                                  |> show_modal("delete-graph-modal")
                                }
                                id={"delete-grid-btn-" <> (g.slug || Integer.to_string(:erlang.phash2(g.title || "")))}
                                class="inline-flex h-8 w-8 items-center justify-center rounded-full bg-red-500/80 hover:bg-red-600 text-white shadow-sm transition-transform hover:scale-105"
                                title="Delete grid"
                                aria-label={"Delete " <> (g.title || "grid")}
                              >
                                <.icon name="hero-trash" class="h-4 w-4" />
                              </button>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- My Notes Section --%>
          <div class="mt-8">
            <button
              type="button"
              phx-click={
                JS.toggle(to: "#notes-content")
                |> JS.toggle(to: "#notes-chevron-down")
                |> JS.toggle(to: "#notes-chevron-up")
              }
              class={[
                "w-full flex items-center justify-between text-left group mb-4",
                theme_heading_class(@theme)
              ]}
            >
              <h2 class="text-lg sm:text-xl font-semibold tracking-tight">
                My Notes
                <span class={[
                  "ml-2 inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                  theme_tag_class(@theme)
                ]}>
                  {length(@noted_notes)}
                </span>
              </h2>
              <span>
                <span id="notes-chevron-up">
                  <.icon name="hero-chevron-up" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
                <span id="notes-chevron-down" class="hidden">
                  <.icon name="hero-chevron-down" class={"w-5 h-5 " <> theme_subtext_class(@theme)} />
                </span>
              </span>
            </button>

            <div id="notes-content">
              <%= if @noted_notes == [] do %>
                <div class={[
                  "rounded-xl border p-8 text-center shadow-sm",
                  theme_card_class(@theme)
                ]}>
                  <.icon
                    name="hero-bookmark"
                    class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
                  />
                  <p class={["text-sm", theme_subtext_class(@theme)]}>
                    No notes yet. Click the note icon on any node to save it here.
                  </p>
                </div>
              <% else %>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <%= for note <- @noted_notes do %>
                    <%!-- Desktop link (graph view) --%>
                    <.link
                      navigate={graph_path(note.graph, note.node_id)}
                      class={[
                        "hidden lg:block rounded-xl p-4 transition-all",
                        theme_card_class(@theme),
                        theme_link_class(@theme)
                      ]}
                    >
                      <div class={[
                        "text-sm font-medium mb-1.5 line-clamp-2",
                        theme_heading_class(@theme)
                      ]}>
                        {note.node_title}
                      </div>
                      <div class={["flex items-center gap-1.5 text-xs", theme_subtext_class(@theme)]}>
                        <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
                        {note.graph_title}
                      </div>
                    </.link>
                    <%!-- Mobile link (linear view) --%>
                    <.link
                      navigate={graph_path(note.graph, note.node_id)}
                      class={[
                        "lg:hidden block rounded-xl p-4 transition-all",
                        theme_card_class(@theme),
                        theme_link_class(@theme)
                      ]}
                    >
                      <div class={[
                        "text-sm font-medium mb-1.5 line-clamp-2",
                        theme_heading_class(@theme)
                      ]}>
                        {note.node_title}
                      </div>
                      <div class={["flex items-center gap-1.5 text-xs", theme_subtext_class(@theme)]}>
                        <.icon name="hero-arrow-top-right-on-square" class="h-3 w-3" />
                        {note.graph_title}
                      </div>
                    </.link>
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

  defp graph_preview_sentence(graph) do
    case Enum.take(graph.tags || [], 2) do
      [] ->
        "A #{String.downcase(exploration_label(graph))} built from #{graph_node_count(graph)} connected ideas."

      tags ->
        "A #{String.downcase(exploration_label(graph))} around #{human_join(tags)}."
    end
  end

  defp exploration_label(graph) do
    cond do
      graph_node_count(graph) >= 20 -> "Deep dive"
      graph_node_count(graph) <= 4 -> "Seedling"
      true -> "Developing map"
    end
  end

  defp graph_updated_label(graph) do
    case graph.updated_at || graph.inserted_at do
      %DateTime{} = updated_at -> Calendar.strftime(updated_at, "%b %Y")
      _ -> "Recently"
    end
  end

  defp graph_node_count(graph) do
    (graph.data || %{})
    |> Map.get("nodes", [])
    |> Enum.count(fn node -> !Map.get(node, "compound", false) end)
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

  defp featured_card_class(0), do: "min-h-[24rem] rounded-[1.35rem]"
  defp featured_card_class(_), do: "min-h-[24rem] rounded-2xl"

  defp featured_card_header_class(_), do: "h-24 p-4"

  defp featured_card_body_class(0), do: "flex flex-1 flex-col p-4"
  defp featured_card_body_class(_), do: "flex flex-1 flex-col p-4"

  defp featured_card_title_class(0), do: "line-clamp-3 text-lg"
  defp featured_card_title_class(_), do: "line-clamp-3 text-base"

  # --- Profile class helpers ---

  defp theme_bg_class(_), do: "bg-gray-50"
  defp theme_card_class(_), do: "bg-white border-gray-200"

  defp theme_banner_class(_), do: "bg-gradient-to-r from-indigo-500 to-blue-400"

  defp theme_avatar_border_class(_), do: "border-white bg-white"

  defp theme_avatar_default_class(_), do: "bg-indigo-100 text-indigo-600"

  defp theme_heading_class(_), do: "text-gray-900"
  defp theme_subtext_class(_), do: "text-gray-500"
  defp theme_link_class(_), do: "text-indigo-600 hover:text-indigo-500"

  defp theme_button_class(_), do: "bg-indigo-600 text-white hover:bg-indigo-500"

  defp theme_icon_button_class(_),
    do:
      "bg-gradient-to-br from-indigo-500 to-sky-500 text-white shadow-sm ring-1 ring-indigo-500/30 transition-transform hover:scale-105"

  defp theme_tag_class(_), do: "bg-indigo-50 text-indigo-700 ring-1 ring-indigo-200"

  # --- Table helper classes ---

  defp table_header_class(_), do: "bg-slate-50 text-xs uppercase tracking-wide text-slate-600"
  defp table_body_class(_), do: "divide-y divide-slate-200"

  defp table_row_class(_),
    do: "align-top transition-colors odd:bg-slate-50 even:bg-white hover:bg-indigo-50/50"

  defp table_link_class(_), do: "text-slate-900 hover:text-indigo-700"

  defp table_tag_color_class(tag, _theme) do
    colors = [
      "bg-rose-50 text-rose-700 ring-rose-600/20",
      "bg-orange-50 text-orange-700 ring-orange-600/20",
      "bg-amber-50 text-amber-700 ring-amber-600/20",
      "bg-lime-50 text-lime-700 ring-lime-600/20",
      "bg-green-50 text-green-700 ring-green-600/20",
      "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
      "bg-teal-50 text-teal-700 ring-teal-600/20",
      "bg-cyan-50 text-cyan-700 ring-cyan-600/20",
      "bg-sky-50 text-sky-700 ring-sky-600/20",
      "bg-blue-50 text-blue-700 ring-blue-600/20",
      "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
      "bg-violet-50 text-violet-700 ring-violet-600/20",
      "bg-purple-50 text-purple-700 ring-purple-600/20",
      "bg-fuchsia-50 text-fuchsia-700 ring-fuchsia-600/20",
      "bg-pink-50 text-pink-700 ring-pink-600/20"
    ]

    idx = :erlang.phash2(tag, length(colors))
    Enum.at(colors, idx)
  end
end
