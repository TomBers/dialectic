defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.GravatarCache
  alias DialecticWeb.Utils.NodeTitleHelper

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
        theme = profile_user.theme || "default"

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
          |> assign(:avatar_url, nil)
          |> assign(:header_image_url, nil)
          |> assign(:theme, theme)
          |> assign(:stats, stats)
          |> assign(:graphs, graphs)
          |> assign(:common_tags, common_tags)
          |> assign(:verified_accounts, [])
          |> assign(:location, nil)
          |> assign(:is_own_profile?, is_own_profile?)
          |> assign(:my_stats, my_stats)
          |> assign(:noted_notes, noted_notes)
          |> assign(:graph_to_delete, nil)

        # Load Gravatar data — served from ETS cache when available,
        # fetched async on cache miss to avoid blocking initial render
        # and to avoid redundant external API calls on repeated mounts.
        socket =
          case profile_user.gravatar_id do
            id when is_binary(id) and id != "" ->
              case GravatarCache.get(id) do
                {:ok, data} ->
                  # Cache hit — apply immediately, no async fetch needed
                  socket
                  |> assign(:avatar_url, data.avatar_url)
                  |> assign(:header_image_url, data.header_image_url)
                  |> assign(:verified_accounts, data.verified_accounts)
                  |> assign(:location, data.location)

                :miss ->
                  # Cache miss — fetch asynchronously so we don't block render
                  start_async(socket, :fetch_gravatar, fn ->
                    GravatarCache.fetch(id)
                  end)
              end

            _ ->
              socket
          end

        {:ok, socket}
    end
  end

  @impl true
  def handle_async(:fetch_gravatar, {:ok, {:ok, result}}, socket) do
    %{
      avatar_url: avatar_url,
      header_image_url: header_image_url,
      verified_accounts: verified_accounts,
      location: location
    } = result

    {:noreply,
     socket
     |> assign(:avatar_url, avatar_url)
     |> assign(:header_image_url, header_image_url)
     |> assign(:verified_accounts, verified_accounts)
     |> assign(:location, location)}
  end

  @impl true
  def handle_async(:fetch_gravatar, {:ok, _error}, socket) do
    # Cache fetch returned an error; keep default nil/empty assigns
    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_gravatar, {:exit, _reason}, socket) do
    # Gravatar fetch failed; keep the default nil/empty assigns
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_delete_modal", %{"title" => title}, socket) do
    {:noreply, assign(socket, :graph_to_delete, title)}
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
  def handle_event("confirm_delete_graph", _params, socket) do
    title = socket.assigns.graph_to_delete
    user = socket.assigns.current_user
    profile_user = socket.assigns.profile_user

    case Dialectic.DbActions.Graphs.soft_delete_user_graph(title, user) do
      {:ok, _graph} ->
        # Reload both my_stats and public graphs to reflect the deleted graph
        my_stats = Dialectic.DbActions.Notes.get_my_stats(user)
        graphs = Accounts.list_user_public_graphs(profile_user)

        {:noreply,
         socket
         |> assign(:graph_to_delete, nil)
         |> assign(:my_stats, my_stats)
         |> assign(:graphs, graphs)
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
    end
  end

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
          This action cannot be undone.
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
      <div class="mx-auto max-w-5xl px-4 sm:px-6 py-10 sm:py-14">
        <%!-- Profile Header --%>
        <div class={[
          "rounded-2xl border shadow-lg overflow-hidden",
          theme_card_class(@theme)
        ]}>
          <%!-- Banner area --%>
          <%= if @header_image_url do %>
            <div class="h-32 sm:h-40 overflow-hidden">
              <img
                src={@header_image_url}
                alt={"#{@effective_username}'s header image"}
                class="h-full w-full object-cover"
              />
            </div>
          <% else %>
            <div class={["h-32 sm:h-40", theme_banner_class(@theme)]}></div>
          <% end %>

          <div class="relative px-6 pb-6">
            <%!-- Avatar --%>
            <div class="flex flex-col sm:flex-row sm:items-end gap-4 -mt-12 sm:-mt-14">
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

              <div class="flex-1 min-w-0 pb-1">
                <h1 class={[
                  "text-2xl sm:text-3xl font-bold tracking-tight truncate",
                  theme_heading_class(@theme)
                ]}>
                  {@effective_username}
                </h1>
              </div>

              <div class="flex items-center gap-2 pb-1">
                <%= if @is_own_profile? do %>
                  <.link
                    navigate={~p"/users/settings"}
                    id="edit-profile-link"
                    class={[
                      "inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                      theme_button_class(@theme)
                    ]}
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" /> Edit Profile
                  </.link>
                <% end %>
              </div>
            </div>

            <%!-- Bio --%>
            <%= if @profile_user.bio && @profile_user.bio != "" do %>
              <p class={["mt-4 text-sm leading-relaxed max-w-2xl", theme_body_text_class(@theme)]}>
                {@profile_user.bio}
              </p>
            <% end %>

            <%!-- Common Tags --%>
            <%= if @common_tags != [] do %>
              <div class="mt-3 flex flex-wrap items-center gap-1.5">
                <span class={["text-xs font-medium", theme_subtext_class(@theme)]}>
                  Mainly talking about:
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

            <%!-- Social Links & Info --%>
            <div class="mt-4 flex flex-wrap items-center gap-3">
              <%= for account <- @verified_accounts do %>
                <a
                  href={account.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={[
                    "inline-flex items-center gap-1.5 text-sm font-medium transition",
                    theme_link_class(@theme)
                  ]}
                >
                  <img src={account.service_icon} alt={account.service_label} class="w-4 h-4" />
                  {account.service_label}
                </a>
              <% end %>

              <%= if @location do %>
                <span class={[
                  "inline-flex items-center gap-1.5 text-sm",
                  theme_subtext_class(@theme)
                ]}>
                  <.icon name="hero-map-pin" class="w-4 h-4" />
                  {@location}
                </span>
              <% end %>

              <span class={["inline-flex items-center gap-1.5 text-sm", theme_subtext_class(@theme)]}>
                <.icon name="hero-calendar-days" class="w-4 h-4" />
                Member since {Calendar.strftime(@stats.member_since, "%B %Y")}
              </span>
            </div>
          </div>
        </div>

        <%!-- Stats Bar --%>
        <div class="mt-6 grid grid-cols-2 sm:grid-cols-3 gap-4">
          <div class={["rounded-xl border p-4 text-center shadow-sm", theme_card_class(@theme)]}>
            <p class={["text-2xl sm:text-3xl font-bold", theme_heading_class(@theme)]}>
              {@stats.graphs_created}
            </p>
            <p class={["text-xs sm:text-sm font-medium mt-1", theme_subtext_class(@theme)]}>
              Grids Created
            </p>
          </div>

          <div class={["rounded-xl border p-4 text-center shadow-sm", theme_card_class(@theme)]}>
            <p class={["text-2xl sm:text-3xl font-bold", theme_heading_class(@theme)]}>
              {@stats.total_nodes}
            </p>
            <p class={["text-xs sm:text-sm font-medium mt-1", theme_subtext_class(@theme)]}>
              Ideas Explored
            </p>
          </div>

          <div class={[
            "rounded-xl border p-4 text-center shadow-sm col-span-2 sm:col-span-1",
            theme_card_class(@theme)
          ]}>
            <p class={["text-2xl sm:text-3xl font-bold", theme_heading_class(@theme)]}>
              {format_member_duration(@stats.member_since)}
            </p>
            <p class={["text-xs sm:text-sm font-medium mt-1", theme_subtext_class(@theme)]}>
              Days Active
            </p>
          </div>
        </div>

        <%!-- Graphs Section --%>
        <div class="mt-8">
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
                My Public Grids
              <% else %>
                Grids by {@effective_username}
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
              <div class="columns-1 sm:columns-2 lg:columns-3 gap-5 space-y-5">
                <%= for graph <- @graphs do %>
                  <div class="break-inside-avoid">
                    <DialecticWeb.PageHtml.GraphComp.render
                      title={graph.title}
                      is_public={graph.is_public}
                      link={graph_path(graph)}
                      linear_link={graph_linear_path(graph)}
                      count={0}
                      tags={graph.tags}
                      node_count={
                        Enum.count(graph.data["nodes"] || [], fn n ->
                          !Map.get(n, "compound", false)
                        end)
                      }
                      is_live={false}
                      generating={false}
                      variant={theme_graph_variant(@theme)}
                      id={
                        "profile-graph-" <>
                          (graph.slug ||
                             "title-" <>
                               Integer.to_string(:erlang.phash2(graph.title || "")))
                      }
                    />
                  </div>
                <% end %>
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
                <div class="columns-1 sm:columns-2 lg:columns-3 gap-5 space-y-5">
                  <%= for g <- @my_stats.graphs do %>
                    <div class="break-inside-avoid relative group/card">
                      <DialecticWeb.PageHtml.GraphComp.render
                        title={g.title}
                        is_public={g.is_public}
                        link={graph_path(g)}
                        linear_link={graph_linear_path(g)}
                        count={g.noted_count}
                        tags={g.tags}
                        node_count={g.node_count}
                        is_live={false}
                        generating={false}
                        variant={theme_graph_variant(@theme)}
                        id={"my-grid-" <> (g.slug || "title-" <> Integer.to_string(:erlang.phash2(g.title || "")))}
                      />
                      <button
                        type="button"
                        phx-click={
                          JS.push("show_delete_modal", value: %{title: g.title})
                          |> show_modal("delete-graph-modal")
                        }
                        id={"delete-grid-btn-" <> (g.slug || Integer.to_string(:erlang.phash2(g.title || "")))}
                        class={[
                          "absolute top-2 right-2 z-20 p-1.5 rounded-lg opacity-0 group-hover/card:opacity-100 transition-opacity",
                          "bg-red-500/80 hover:bg-red-600 text-white shadow-sm"
                        ]}
                        title="Delete grid"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  <% end %>
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
                      navigate={graph_linear_path(note.graph, note.node_id)}
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

  defp theme_graph_variant(theme) when theme in ~w(indigo violet emerald amber rose), do: :glass
  defp theme_graph_variant(_), do: :light

  # --- Theme class helpers ---

  defp theme_bg_class("indigo"), do: "bg-gradient-to-b from-indigo-950 to-slate-950"
  defp theme_bg_class("violet"), do: "bg-gradient-to-b from-violet-950 to-slate-950"
  defp theme_bg_class("emerald"), do: "bg-gradient-to-b from-emerald-950 to-slate-950"
  defp theme_bg_class("amber"), do: "bg-gradient-to-b from-amber-950 to-slate-950"
  defp theme_bg_class("rose"), do: "bg-gradient-to-b from-rose-950 to-slate-950"
  defp theme_bg_class(_), do: "bg-gray-50"

  defp theme_card_class("indigo"), do: "bg-white/10 border-white/15 backdrop-blur-md"
  defp theme_card_class("violet"), do: "bg-white/10 border-white/15 backdrop-blur-md"
  defp theme_card_class("emerald"), do: "bg-white/10 border-white/15 backdrop-blur-md"
  defp theme_card_class("amber"), do: "bg-white/10 border-white/15 backdrop-blur-md"
  defp theme_card_class("rose"), do: "bg-white/10 border-white/15 backdrop-blur-md"
  defp theme_card_class(_), do: "bg-white border-gray-200"

  defp theme_banner_class("indigo"), do: "bg-gradient-to-r from-indigo-600 to-blue-500"
  defp theme_banner_class("violet"), do: "bg-gradient-to-r from-violet-600 to-purple-500"
  defp theme_banner_class("emerald"), do: "bg-gradient-to-r from-emerald-600 to-teal-500"
  defp theme_banner_class("amber"), do: "bg-gradient-to-r from-amber-500 to-orange-500"
  defp theme_banner_class("rose"), do: "bg-gradient-to-r from-rose-600 to-pink-500"
  defp theme_banner_class(_), do: "bg-gradient-to-r from-indigo-500 to-blue-400"

  defp theme_avatar_border_class("default"), do: "border-white bg-white"
  defp theme_avatar_border_class(_), do: "border-white/30 bg-white/10"

  defp theme_avatar_default_class("indigo"), do: "bg-indigo-500/30 text-indigo-200"
  defp theme_avatar_default_class("violet"), do: "bg-violet-500/30 text-violet-200"
  defp theme_avatar_default_class("emerald"), do: "bg-emerald-500/30 text-emerald-200"
  defp theme_avatar_default_class("amber"), do: "bg-amber-500/30 text-amber-200"
  defp theme_avatar_default_class("rose"), do: "bg-rose-500/30 text-rose-200"
  defp theme_avatar_default_class(_), do: "bg-indigo-100 text-indigo-600"

  defp theme_heading_class(theme) when theme in ~w(indigo violet emerald amber rose),
    do: "text-white"

  defp theme_heading_class(_), do: "text-gray-900"

  defp theme_subtext_class(theme) when theme in ~w(indigo violet emerald amber rose),
    do: "text-white/60"

  defp theme_subtext_class(_), do: "text-gray-500"

  defp theme_body_text_class(theme) when theme in ~w(indigo violet emerald amber rose),
    do: "text-white/80"

  defp theme_body_text_class(_), do: "text-gray-700"

  defp theme_link_class("indigo"), do: "text-indigo-300 hover:text-indigo-200"
  defp theme_link_class("violet"), do: "text-violet-300 hover:text-violet-200"
  defp theme_link_class("emerald"), do: "text-emerald-300 hover:text-emerald-200"
  defp theme_link_class("amber"), do: "text-amber-300 hover:text-amber-200"
  defp theme_link_class("rose"), do: "text-rose-300 hover:text-rose-200"
  defp theme_link_class(_), do: "text-indigo-600 hover:text-indigo-500"

  defp theme_button_class("indigo"), do: "bg-indigo-500 text-white hover:bg-indigo-400"
  defp theme_button_class("violet"), do: "bg-violet-500 text-white hover:bg-violet-400"
  defp theme_button_class("emerald"), do: "bg-emerald-500 text-white hover:bg-emerald-400"
  defp theme_button_class("amber"), do: "bg-amber-500 text-white hover:bg-amber-400"
  defp theme_button_class("rose"), do: "bg-rose-500 text-white hover:bg-rose-400"
  defp theme_button_class(_), do: "bg-indigo-600 text-white hover:bg-indigo-500"

  defp theme_tag_class("indigo"), do: "bg-indigo-500/20 text-indigo-200 ring-1 ring-indigo-400/30"
  defp theme_tag_class("violet"), do: "bg-violet-500/20 text-violet-200 ring-1 ring-violet-400/30"

  defp theme_tag_class("emerald"),
    do: "bg-emerald-500/20 text-emerald-200 ring-1 ring-emerald-400/30"

  defp theme_tag_class("amber"), do: "bg-amber-500/20 text-amber-200 ring-1 ring-amber-400/30"
  defp theme_tag_class("rose"), do: "bg-rose-500/20 text-rose-200 ring-1 ring-rose-400/30"
  defp theme_tag_class(_), do: "bg-indigo-50 text-indigo-700 ring-1 ring-indigo-200"
end
