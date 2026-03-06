defmodule DialecticWeb.FeedLive do
  use DialecticWeb, :live_view

  alias Dialectic.Social
  alias Dialectic.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    graphs = Social.list_feed_graphs(current_user)
    following_count = Social.following_count(current_user)

    {:ok,
     socket
     |> assign(:page_title, "Feed")
     |> assign(:graphs, graphs)
     |> assign(:following_count, following_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-[#1a0533] via-[#1e1145] to-[#0f0a1e]">
      <div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold tracking-tight text-white sm:text-3xl">
            Your Feed
          </h1>
          <p class="mt-1 text-sm text-white/60">
            Recent graphs from people you follow
          </p>
        </div>

        <%= if @graphs == [] do %>
          <div class="rounded-xl border border-white/10 bg-white/5 p-10 text-center shadow-sm">
            <.icon name="hero-user-group" class="mx-auto mb-4 h-12 w-12 text-white/30" />
            <%= if @following_count == 0 do %>
              <p class="text-base font-medium text-white/70">
                You're not following anyone yet
              </p>
              <p class="mt-2 text-sm text-white/50">
                Visit a user's profile and follow them to see their graphs here.
              </p>
              <.link
                navigate={~p"/view_all/graphs"}
                class="mt-6 inline-flex items-center gap-2 rounded-xl bg-white/10 px-5 py-2.5 text-sm font-semibold text-white ring-1 ring-white/20 transition hover:bg-white/15"
              >
                <.icon name="hero-magnifying-glass" class="h-4 w-4" /> Browse public graphs
              </.link>
            <% else %>
              <p class="text-base font-medium text-white/70">
                No new graphs yet
              </p>
              <p class="mt-2 text-sm text-white/50">
                The people you follow haven't published any public graphs yet. Check back later!
              </p>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-6">
            <%= for graph <- @graphs do %>
              <div
                id={"feed-graph-#{graph.slug || "title-" <> Integer.to_string(:erlang.phash2(graph.title || ""))}"}
                class="rounded-xl border border-white/10 bg-white/5 p-5 shadow-sm transition hover:bg-white/[0.07]"
              >
                <div class="flex items-start gap-4">
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2 text-xs text-white/50">
                      <.link
                        navigate={~p"/u/#{User.effective_username(graph.user)}"}
                        class="font-semibold text-white/70 hover:text-white transition"
                      >
                        {User.display_name(graph.user)}
                      </.link>
                      <span>·</span>
                      <time datetime={DateTime.to_iso8601(graph.updated_at)}>
                        {format_relative_time(graph.updated_at)}
                      </time>
                    </div>

                    <.link navigate={graph_path(graph)} class="mt-1.5 block group">
                      <h2 class="text-base font-semibold text-white group-hover:text-white/90 transition line-clamp-2">
                        {graph.title}
                      </h2>
                    </.link>

                    <div class="mt-3 flex flex-wrap items-center gap-2">
                      <% node_count =
                        Enum.count(graph.data["nodes"] || [], fn n ->
                          !Map.get(n, "compound", false)
                        end) %>
                      <span class="inline-flex items-center rounded-md bg-white/10 px-2 py-0.5 text-[10px] font-bold text-white/70 ring-1 ring-inset ring-white/15">
                        {node_count} {if node_count == 1, do: "node", else: "nodes"}
                      </span>

                      <%= if node_count < 5 do %>
                        <span class="inline-flex items-center rounded-md bg-emerald-500/15 px-2 py-0.5 text-[10px] font-bold text-emerald-100 ring-1 ring-inset ring-emerald-300/30">
                          <.icon name="hero-sparkles" class="mr-1 h-3 w-3" /> Seedling
                        </span>
                      <% end %>

                      <%= if node_count > 20 do %>
                        <span class="inline-flex items-center rounded-md bg-blue-500/15 px-2 py-0.5 text-[10px] font-bold text-blue-100 ring-1 ring-inset ring-blue-300/30">
                          <.icon name="hero-book-open" class="mr-1 h-3 w-3" /> Deep Dive
                        </span>
                      <% end %>

                      <%= for tag <- (graph.tags || []) do %>
                        <span class={[
                          "inline-flex items-center rounded-md px-2 py-0.5 text-[10px] font-bold ring-1 ring-inset",
                          tag_color_class(tag)
                        ]}>
                          {tag}
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <.link
                    navigate={graph_path(graph)}
                    class="shrink-0 rounded-lg bg-white/10 p-2 text-white/60 ring-1 ring-white/15 transition hover:bg-white/15 hover:text-white"
                  >
                    <.icon name="hero-arrow-right" class="h-4 w-4" />
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="mt-10">
          <.link
            navigate={~p"/"}
            class="inline-flex items-center gap-2 text-sm font-semibold text-white/60 transition hover:text-white"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  defp tag_color_class(tag) do
    colors = [
      "bg-rose-500/15 text-rose-100 ring-rose-300/30",
      "bg-orange-500/15 text-orange-100 ring-orange-300/30",
      "bg-amber-500/15 text-amber-100 ring-amber-300/30",
      "bg-lime-500/15 text-lime-100 ring-lime-300/30",
      "bg-green-500/15 text-green-100 ring-green-300/30",
      "bg-emerald-500/15 text-emerald-100 ring-emerald-300/30",
      "bg-teal-500/15 text-teal-100 ring-teal-300/30",
      "bg-cyan-500/15 text-cyan-100 ring-cyan-300/30",
      "bg-sky-500/15 text-sky-100 ring-sky-300/30",
      "bg-blue-500/15 text-blue-100 ring-blue-300/30",
      "bg-indigo-500/15 text-indigo-100 ring-indigo-300/30",
      "bg-violet-500/15 text-violet-100 ring-violet-300/30",
      "bg-purple-500/15 text-purple-100 ring-purple-300/30",
      "bg-fuchsia-500/15 text-fuchsia-100 ring-fuchsia-300/30",
      "bg-pink-500/15 text-pink-100 ring-pink-300/30"
    ]

    idx = :erlang.phash2(tag, length(colors))
    Enum.at(colors, idx)
  end
end
