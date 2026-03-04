defmodule DialecticWeb.UserProfileLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_for_profile(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> redirect(to: ~p"/")}

      profile_user ->
        stats = Accounts.get_profile_stats(profile_user)
        graphs = Accounts.list_user_public_graphs(profile_user)

        effective_username = User.effective_username(profile_user)
        display_name = User.display_name(profile_user)
        avatar_url = User.avatar_url(profile_user)
        theme = profile_user.theme || "default"

        is_own_profile? =
          socket.assigns[:current_user] &&
            socket.assigns.current_user.id == profile_user.id

        {:ok,
         socket
         |> assign(:page_title, "#{display_name} — MuDG Profile")
         |> assign(:profile_user, profile_user)
         |> assign(:effective_username, effective_username)
         |> assign(:display_name, display_name)
         |> assign(:avatar_url, avatar_url)
         |> assign(:theme, theme)
         |> assign(:stats, stats)
         |> assign(:graphs, graphs)
         |> assign(:is_own_profile?, is_own_profile?)}
    end
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
          <div class={["h-32 sm:h-40", theme_banner_class(@theme)]}></div>

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
                    alt={"#{@display_name}'s avatar"}
                    class="h-full w-full object-cover rounded-full"
                  />
                <% else %>
                  <div class={[
                    "h-full w-full flex items-center justify-center rounded-full text-3xl font-bold",
                    theme_avatar_default_class(@theme)
                  ]}>
                    {String.first(@display_name) |> String.upcase()}
                  </div>
                <% end %>
              </div>

              <div class="flex-1 min-w-0 pb-1">
                <h1 class={[
                  "text-2xl sm:text-3xl font-bold tracking-tight truncate",
                  theme_heading_class(@theme)
                ]}>
                  {@display_name}
                </h1>
                <p class={["text-sm font-medium", theme_subtext_class(@theme)]}>
                  @{@effective_username}
                </p>
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

            <%!-- Social Links --%>
            <div class="mt-4 flex flex-wrap items-center gap-3">
              <%= if @profile_user.website_url && @profile_user.website_url != "" do %>
                <a
                  href={@profile_user.website_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={[
                    "inline-flex items-center gap-1.5 text-sm font-medium transition",
                    theme_link_class(@theme)
                  ]}
                >
                  <.icon name="hero-globe-alt" class="w-4 h-4" />
                  {URI.parse(@profile_user.website_url).host || @profile_user.website_url}
                </a>
              <% end %>

              <%= if @profile_user.twitter_handle && @profile_user.twitter_handle != "" do %>
                <a
                  href={"https://x.com/#{@profile_user.twitter_handle}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={[
                    "inline-flex items-center gap-1.5 text-sm font-medium transition",
                    theme_link_class(@theme)
                  ]}
                >
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                  </svg>
                  @{@profile_user.twitter_handle}
                </a>
              <% end %>

              <%= if @profile_user.linkedin_url && @profile_user.linkedin_url != "" do %>
                <a
                  href={@profile_user.linkedin_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={[
                    "inline-flex items-center gap-1.5 text-sm font-medium transition",
                    theme_link_class(@theme)
                  ]}
                >
                  <svg class="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                  </svg>
                  LinkedIn
                </a>
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
              Your Public Graphs
            <% else %>
              Graphs by {@display_name}
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
                    id={"profile-graph-#{graph.slug || graph.title}"}
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
end
