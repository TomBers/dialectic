defmodule DialecticWeb.ActivityLive do
  use DialecticWeb, :live_view

  import Ecto.Query

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.Follows
  alias Dialectic.Follows.Follow
  alias Dialectic.GridActivity
  alias Dialectic.GridActivity.Log
  alias Dialectic.Repo

  @base_filters [
    %{id: "all", label: "All", icon: "hero-inbox-stack"},
    %{id: "mentions", label: "Mentions of you", icon: "hero-at-symbol"},
    %{id: "your_grids", label: "Your grids", icon: "hero-home"},
    %{id: "following", label: "Following", icon: "hero-user-group"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Activity")
     |> assign(:activity_filter, "all")
     |> assign_activity(user)}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply,
     assign_activity(assign(socket, :activity_filter, filter), socket.assigns.current_user)}
  end

  @impl true
  def handle_event("mark_seen", _params, socket) do
    user = socket.assigns.current_user
    Follows.mark_seen(user)

    {:noreply,
     socket
     |> put_flash(:info, "Activity marked as seen.")
     |> assign_activity(user)}
  end

  defp assign_activity(socket, user) do
    follows = Follows.list_user_follows(user)
    visible_follows = Enum.reject(follows, &(&1.target_type == "topic"))
    context = activity_context(user, follows)
    items = activity_stream(user, follows, context)
    filter = socket.assigns[:activity_filter] || "all"
    filtered_items = filter_items(items, filter)

    socket
    |> assign(:follows, visible_follows)
    |> assign(:activity_items, filtered_items)
    |> assign(:activity_stats, activity_stats(items, visible_follows))
    |> assign(:activity_filters, activity_filters(items))
  end

  defp activity_context(user, follows) do
    %{
      user_id: user && user.id,
      followed_graph_titles:
        follows
        |> Enum.filter(&(&1.target_type == "graph"))
        |> Enum.map(& &1.graph_title)
        |> MapSet.new(),
      followed_user_ids:
        follows
        |> Enum.filter(&(&1.target_type == "user"))
        |> Enum.map(& &1.target_user_id)
        |> MapSet.new()
    }
  end

  defp activity_stream(nil, _follows, _context), do: []

  defp activity_stream(%User{} = user, follows, context) do
    []
    |> Kernel.++(user_follow_items(user))
    |> Kernel.++(grid_follow_items(user))
    |> Kernel.++(owned_grid_digest_items(user))
    |> Kernel.++(followed_user_created_grid_items(context))
    |> Kernel.++(followed_grid_update_items(context))
    |> Enum.sort_by(& &1.occurred_at, {:desc, DateTime})
    |> Enum.take(75)
    |> dedupe_followed_own_grid(follows, user)
  end

  defp user_follow_items(%User{} = user) do
    Follow
    |> where([f], f.target_type == "user" and f.target_user_id == ^user.id)
    |> where([f], f.follower_user_id != ^user.id)
    |> preload([:follower])
    |> Repo.all()
    |> Enum.map(fn follow ->
      %{
        id: "user-follow-#{follow.id}",
        category: "mentions",
        type: :user_followed_you,
        actor: follow.follower,
        occurred_at: follow.inserted_at,
        icon: "hero-user-plus",
        title: "#{display_name(follow.follower)} followed you",
        body: nil,
        path: profile_path(follow.follower),
        action_label: "View profile"
      }
    end)
  end

  defp grid_follow_items(%User{} = user) do
    Follow
    |> join(:inner, [f], graph in Graph, on: graph.title == f.graph_title)
    |> where([f, graph], f.target_type == "graph" and graph.user_id == ^user.id)
    |> where([f, _graph], f.follower_user_id != ^user.id)
    |> preload([f, graph], follower: [], graph: graph)
    |> Repo.all()
    |> Enum.map(fn follow ->
      %{
        id: "grid-follow-#{follow.id}",
        category: "mentions",
        type: :grid_followed,
        actor: follow.follower,
        graph: follow.graph,
        occurred_at: follow.inserted_at,
        icon: "hero-squares-plus",
        title: "#{display_name(follow.follower)} followed your grid",
        body: follow.graph.title,
        path: graph_path(follow.graph),
        action_label: "Open grid"
      }
    end)
  end

  defp owned_grid_digest_items(%User{} = user) do
    Log
    |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
    |> where([log, graph], graph.user_id == ^user.id and log.action != "graph.created")
    |> where([_log, graph], graph.is_deleted != true)
    |> preload([_log, graph], graph: graph)
    |> Repo.all()
    |> group_logs("your_grids", :owned_grid_updated, "Your grid got updates", "Open latest")
  end

  defp followed_user_created_grid_items(context) do
    if MapSet.size(context.followed_user_ids) == 0 do
      []
    else
      followed_user_ids = MapSet.to_list(context.followed_user_ids)

      Log
      |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
      |> join(:inner, [_log, graph], actor in User, on: actor.id == graph.user_id)
      |> where(
        [log, graph, _actor],
        log.action == "graph.created" and graph.user_id in ^followed_user_ids
      )
      |> where([_log, graph, _actor], graph.is_public == true and graph.is_published == true)
      |> where([_log, graph, _actor], graph.is_deleted != true)
      |> preload([_log, graph, actor], graph: graph, actor: actor)
      |> Repo.all()
      |> Enum.map(fn log ->
        %{
          id: "followed-user-created-grid-#{log.id}",
          category: "following",
          type: :followed_user_created_grid,
          actor: log.actor,
          graph: log.graph,
          occurred_at: log.inserted_at,
          icon: "hero-sparkles",
          title: "#{display_name(log.actor)} created a new grid",
          body: log.graph.title,
          path: graph_path(log.graph),
          action_label: "Open grid"
        }
      end)
    end
  end

  defp followed_grid_update_items(context) do
    if MapSet.size(context.followed_graph_titles) == 0 do
      []
    else
      followed_graph_titles = MapSet.to_list(context.followed_graph_titles)

      Log
      |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
      |> where(
        [log, graph],
        log.graph_title in ^followed_graph_titles and log.action != "graph.created"
      )
      |> where([_log, graph], graph.is_public == true and graph.is_published == true)
      |> where([_log, graph], graph.is_deleted != true)
      |> preload([_log, graph], graph: graph)
      |> Repo.all()
      |> group_logs(
        "following",
        :followed_grid_updated,
        "Followed grid got updates",
        "Open latest"
      )
    end
  end

  defp group_logs(logs, category, type, title, action_label) do
    logs
    |> Enum.group_by(& &1.graph_title)
    |> Enum.map(fn {_graph_title, group_logs} ->
      sorted_logs = Enum.sort_by(group_logs, & &1.inserted_at, {:desc, DateTime})
      latest = List.first(sorted_logs)
      count = length(sorted_logs)

      %{
        id: "#{type}-#{:erlang.phash2(latest.graph_title)}",
        category: category,
        type: type,
        graph: latest.graph,
        latest_log: latest,
        logs: sorted_logs,
        count: count,
        occurred_at: latest.inserted_at,
        icon: digest_icon(type),
        title: title,
        body: "#{update_count_label(count)} on #{latest.graph.title}",
        path: graph_path(latest.graph, latest.node_id),
        action_label: action_label
      }
    end)
  end

  defp dedupe_followed_own_grid(items, follows, %User{} = user) do
    own_followed_titles =
      follows
      |> Enum.filter(fn follow ->
        follow.target_type == "graph" && follow.graph && follow.graph.user_id == user.id
      end)
      |> Enum.map(& &1.graph_title)
      |> MapSet.new()

    Enum.reject(items, fn item ->
      item.type == :followed_grid_updated && item.graph &&
        MapSet.member?(own_followed_titles, item.graph.title)
    end)
  end

  defp filter_items(items, "all"), do: items
  defp filter_items(items, filter), do: Enum.filter(items, &(&1.category == filter))

  defp activity_stats(items, follows) do
    since = DateTime.add(DateTime.utc_now(), -7, :day)

    %{
      followed_grids: Enum.count(follows, &(&1.target_type == "graph")),
      followed_users: Enum.count(follows, &(&1.target_type == "user")),
      updates_this_week:
        Enum.count(items, fn item ->
          item.occurred_at && DateTime.compare(item.occurred_at, since) in [:gt, :eq]
        end),
      active_grids:
        items
        |> Enum.filter(&Map.has_key?(&1, :graph))
        |> Enum.map(& &1.graph.title)
        |> Enum.uniq()
        |> length(),
      last_update: items |> List.first() |> then(&(&1 && &1.occurred_at))
    }
  end

  defp activity_filters(items) do
    counts = %{
      "all" => length(items),
      "mentions" => Enum.count(items, &(&1.category == "mentions")),
      "your_grids" => Enum.count(items, &(&1.category == "your_grids")),
      "following" => Enum.count(items, &(&1.category == "following"))
    }

    Enum.map(@base_filters, &Map.put(&1, :count, Map.get(counts, &1.id, 0)))
  end

  defp activity_time(nil), do: ""
  defp activity_time(inserted_at), do: Calendar.strftime(inserted_at, "%d %b %Y, %H:%M")

  defp last_update_label(nil), do: "No updates"
  defp last_update_label(inserted_at), do: Calendar.strftime(inserted_at, "%d %b, %H:%M")

  defp follow_label(%{target_type: "graph", graph: %{title: title}}), do: title
  defp follow_label(%{target_type: "user", target_user: %User{} = user}), do: display_name(user)
  defp follow_label(follow), do: follow.target_type

  defp follow_icon(%{target_type: "graph"}), do: "hero-squares-2x2"
  defp follow_icon(%{target_type: "user"}), do: "hero-user"
  defp follow_icon(_follow), do: "hero-bell"

  defp follow_path(%{target_type: "graph", graph: graph}) when not is_nil(graph),
    do: graph_path(graph)

  defp follow_path(%{target_type: "user", target_user: %User{} = user}), do: profile_path(user)
  defp follow_path(_follow), do: nil

  defp profile_path(%User{username: username}) when is_binary(username) and username != "" do
    ~p"/u/#{username}"
  end

  defp profile_path(_user), do: nil

  defp display_name(%User{} = user), do: User.display_name(user)
  defp display_name(_user), do: "Someone"

  defp update_count_label(1), do: "1 update"
  defp update_count_label(count), do: "#{count} updates"

  defp digest_icon(:owned_grid_updated), do: "hero-pencil-square"
  defp digest_icon(:followed_grid_updated), do: "hero-bolt"
  defp digest_icon(_type), do: "hero-bell"

  defp item_detail(%{type: :owned_grid_updated} = item) do
    "#{update_count_label(item.count)} on your grid"
  end

  defp item_detail(%{type: :followed_grid_updated} = item) do
    "#{update_count_label(item.count)} since you followed it"
  end

  defp item_detail(%{type: :user_followed_you}), do: "New follower"
  defp item_detail(%{type: :grid_followed}), do: "New grid follower"
  defp item_detail(%{type: :followed_user_created_grid}), do: "New grid from someone you follow"
  defp item_detail(_item), do: nil

  defp item_preview_logs(%{logs: logs}), do: Enum.take(logs, 3)
  defp item_preview_logs(_item), do: []

  defp action_icon(%{action: "node.deleted"}), do: "hero-trash"

  defp action_icon(%{action: action}) when is_binary(action) do
    cond do
      String.contains?(action, "comment") -> "hero-chat-bubble-left-right"
      String.contains?(action, "branch") -> "hero-arrow-turn-down-right"
      String.contains?(action, "question") -> "hero-question-mark-circle"
      true -> "hero-bolt"
    end
  end

  defp action_icon(_log), do: "hero-bolt"

  defp node_label(%{metadata: %{"node_title" => title}}) when is_binary(title) and title != "" do
    title
  end

  defp node_label(%{node_id: node_id}) when is_binary(node_id) and node_id != "",
    do: "Node #{node_id}"

  defp node_label(_log), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="activity-page" class="min-h-screen bg-slate-50 px-4 py-6 sm:px-6 sm:py-8">
      <div class="mx-auto max-w-7xl">
        <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-indigo-600">
              Network activity
            </p>
            <h1 class="mt-1 text-3xl font-semibold tracking-tight text-slate-950">Activity</h1>
          </div>

          <button
            id="activity-mark-seen-button"
            type="button"
            phx-click="mark_seen"
            class="inline-flex items-center justify-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50"
          >
            <.icon name="hero-check" class="h-4 w-4" /> Mark seen
          </button>
        </div>

        <section id="activity-summary" class="mt-5 grid grid-cols-2 gap-3 md:grid-cols-4">
          <div class="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">Following</p>
            <p class="mt-1.5 text-xl font-semibold text-slate-950">
              {@activity_stats.followed_grids + @activity_stats.followed_users}
            </p>
            <p class="mt-1 text-xs text-slate-500">
              {@activity_stats.followed_grids} grids · {@activity_stats.followed_users} users
            </p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">This week</p>
            <p class="mt-1.5 text-xl font-semibold text-slate-950">
              {@activity_stats.updates_this_week}
            </p>
            <p class="mt-1 text-xs text-slate-500">stream items</p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
              Active grids
            </p>
            <p class="mt-1.5 text-xl font-semibold text-slate-950">
              {@activity_stats.active_grids}
            </p>
            <p class="mt-1 text-xs text-slate-500">with movement</p>
          </div>
          <div class="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <p class="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">Latest</p>
            <p class="mt-1.5 text-xl font-semibold text-slate-950">
              {last_update_label(@activity_stats.last_update)}
            </p>
            <p class="mt-1 text-xs text-slate-500">most recent event</p>
          </div>
        </section>

        <div class="mt-5 grid gap-5 md:grid-cols-[18rem_minmax(0,1fr)] xl:grid-cols-[20rem_minmax(0,1fr)]">
          <aside class="space-y-4">
            <section class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 class="text-sm font-semibold text-slate-950">View</h2>
              <div id="activity-filter-list" class="mt-3 grid gap-2">
                <%= for filter <- @activity_filters do %>
                  <button
                    id={"activity-filter-#{filter.id}"}
                    type="button"
                    phx-click="set_filter"
                    phx-value-filter={filter.id}
                    class={[
                      "flex items-center justify-between gap-3 rounded-xl border px-3 py-2 text-left text-sm font-semibold transition",
                      if(@activity_filter == filter.id,
                        do: "border-indigo-200 bg-indigo-50 text-indigo-700",
                        else: "border-slate-200 bg-white text-slate-700 hover:bg-slate-50"
                      )
                    ]}
                  >
                    <span class="inline-flex items-center gap-2">
                      <.icon name={filter.icon} class="h-4 w-4" />
                      {filter.label}
                    </span>
                    <span class="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500 ring-1 ring-slate-200">
                      {filter.count}
                    </span>
                  </button>
                <% end %>
              </div>
            </section>

            <section class="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
              <h2 class="text-sm font-semibold text-slate-950">Following</h2>
              <%= if @follows == [] do %>
                <p id="activity-following-empty" class="mt-3 text-sm leading-6 text-slate-500">
                  Follow a grid or user to build this stream.
                </p>
              <% else %>
                <div id="activity-following-list" class="mt-3 flex flex-wrap gap-2">
                  <%= for follow <- @follows do %>
                    <% path = follow_path(follow) %>
                    <.link
                      :if={path}
                      navigate={path}
                      class="inline-flex max-w-full items-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-semibold text-slate-700 transition hover:border-indigo-200 hover:bg-indigo-50 hover:text-indigo-700"
                    >
                      <.icon name={follow_icon(follow)} class="h-3.5 w-3.5 shrink-0" />
                      <span class="truncate">{follow_label(follow)}</span>
                      <.icon name="hero-arrow-right" class="h-3 w-3 shrink-0" />
                    </.link>
                  <% end %>
                </div>
              <% end %>
            </section>
          </aside>

          <main>
            <%= if @activity_items == [] do %>
              <div
                id="activity-feed-empty"
                class="rounded-2xl border border-slate-200 bg-white p-10 text-center shadow-sm"
              >
                <.icon name="hero-bell-alert" class="mx-auto h-10 w-10 text-slate-300" />
                <p class="mt-3 text-sm text-slate-500">No activity for this view.</p>
              </div>
            <% else %>
              <ol
                id="activity-stream"
                class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm"
              >
                <%= for item <- @activity_items do %>
                  <li
                    id={"activity-item-#{item.id}"}
                    class="border-b border-slate-100 p-4 last:border-b-0 sm:p-5"
                  >
                    <div class="flex items-start gap-3">
                      <div class="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-indigo-50 text-indigo-600">
                        <.icon name={item.icon} class="h-5 w-5" />
                      </div>
                      <div class="min-w-0 flex-1">
                        <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                          <div class="min-w-0">
                            <p class="text-sm font-semibold leading-6 text-slate-950">
                              {item.title}
                            </p>
                            <p :if={item.body} class="mt-0.5 text-sm leading-6 text-slate-600">
                              {item.body}
                            </p>
                            <p class="mt-1 text-xs font-medium text-slate-400">
                              {item_detail(item)} · {activity_time(item.occurred_at)}
                            </p>
                          </div>
                          <.link
                            :if={item.path}
                            navigate={item.path}
                            class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-50"
                          >
                            {item.action_label} <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                          </.link>
                        </div>

                        <ol :if={item_preview_logs(item) != []} class="mt-3 space-y-2">
                          <%= for log <- item_preview_logs(item) do %>
                            <li
                              id={"activity-log-#{log.id}"}
                              class="flex items-start gap-2 rounded-xl bg-slate-50 px-3 py-2"
                            >
                              <.icon
                                name={action_icon(log)}
                                class="mt-0.5 h-4 w-4 shrink-0 text-slate-400"
                              />
                              <div class="min-w-0">
                                <p class="text-xs font-medium leading-5 text-slate-700">
                                  {GridActivity.display_message(log)}
                                </p>
                                <p :if={node_label(log)} class="text-xs text-slate-500">
                                  {node_label(log)}
                                </p>
                              </div>
                            </li>
                          <% end %>
                        </ol>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ol>
            <% end %>
          </main>
        </div>
      </div>
    </div>
    """
  end
end
