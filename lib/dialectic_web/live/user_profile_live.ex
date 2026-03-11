defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.GravatarCache

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
  def render(assigns) do
    ~H"""
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
                <span class={["inline-flex items-center gap-1.5 text-sm", theme_subtext_class(@theme)]}>
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
              Graphs Created
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
          <h2 class={[
            "text-lg sm:text-xl font-semibold tracking-tight mb-4",
            theme_heading_class(@theme)
          ]}>
            <%= if @is_own_profile? do %>
              Public Graphs
            <% else %>
              Graphs by {@effective_username}
            <% end %>
          </h2>

          <%= if @graphs == [] do %>
            <div class={["rounded-xl border p-8 text-center shadow-sm", theme_card_class(@theme)]}>
              <.icon
                name="hero-light-bulb"
                class={"w-10 h-10 mx-auto mb-3 " <> theme_subtext_class(@theme)}
              />
              <p class={["text-sm", theme_subtext_class(@theme)]}>
                No public graphs yet.
              </p>
              <%= if @is_own_profile? do %>
                <.link
                  navigate={~p"/"}
                  class={[
                    "mt-4 inline-flex items-center gap-1.5 rounded-xl px-4 py-2 text-sm font-semibold shadow-sm transition",
                    theme_button_class(@theme)
                  ]}
                >
                  <.icon name="hero-plus" class="w-4 h-4" /> Create your first graph
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
