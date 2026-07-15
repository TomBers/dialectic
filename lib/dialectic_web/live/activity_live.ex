defmodule DialecticWeb.ActivityLive do
  use DialecticWeb, :live_view

  import Ecto.Query

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.Follows
  alias Dialectic.Follows.Follow
  alias Dialectic.GridActivity
  alias Dialectic.GridActivity.Log
  alias Dialectic.Repo
  alias DialecticWeb.Utils.NodeTitleHelper

  @feed_filters [
    %{id: "all", label: "All", icon: "hero-inbox-stack"},
    %{id: "mentions", label: "Mentions of you", icon: "hero-at-symbol"},
    %{id: "following", label: "Following", icon: "hero-user-group"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Activity")
     |> assign(:activity_tab, "feed")
     |> assign(:activity_filter, "all")
     |> assign_activity(user)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket)
      when tab in ["feed", "my_grids", "following"] do
    {:noreply, assign(socket, :activity_tab, tab)}
  end

  @impl true
  def handle_event("show_area", %{"area" => "feed"}, socket) do
    {:noreply,
     socket
     |> assign(:activity_tab, "feed")
     |> assign(:activity_filter, "all")
     |> assign_activity(socket.assigns.current_user)}
  end

  def handle_event("show_area", %{"area" => "my_grids"}, socket) do
    {:noreply, assign(socket, :activity_tab, "my_grids")}
  end

  def handle_event("show_area", %{"area" => "following"}, socket) do
    {:noreply, assign(socket, :activity_tab, "following")}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:activity_tab, "feed")
     |> assign(:activity_filter, filter)
     |> assign_activity(socket.assigns.current_user)}
  end

  @impl true
  def handle_event("mark_seen", _params, socket) do
    user = socket.assigns.current_user
    Follows.mark_seen(user)

    {:noreply,
     socket
     |> put_flash(:info, "Followed activity marked as seen.")
     |> assign_activity(user)}
  end

  @impl true
  def handle_event("unfollow", %{"follow-id" => follow_id}, socket) do
    user = socket.assigns.current_user

    case unfollow_by_id(user, follow_id) do
      {:ok, message} ->
        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign_activity(user)}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp assign_activity(socket, user) do
    follows = Follows.list_user_follows(user)
    visible_follows = Enum.reject(follows, &(&1.target_type == "topic"))
    context = activity_context(user, follows)
    feed_items = activity_feed(user, follows, context)
    owned_grid_items = owned_grid_digest_items(user)
    filter = socket.assigns[:activity_filter] || "all"
    filtered_feed_items = filter_items(feed_items, filter)

    socket
    |> assign(:follows, visible_follows)
    |> assign(:activity_feed_items, filtered_feed_items)
    |> assign(:owned_grid_items, owned_grid_items)
    |> assign(:activity_stats, activity_stats(feed_items, owned_grid_items, visible_follows))
    |> assign(:activity_filters, activity_filters(feed_items))
  end

  defp unfollow_by_id(nil, _follow_id), do: {:error, "Log in to manage followed items."}

  defp unfollow_by_id(%User{} = user, follow_id) do
    with {id, ""} <- Integer.parse(to_string(follow_id)),
         %Follow{} = follow <- find_user_follow(user, id),
         {:ok, message} <- unfollow_target(user, follow) do
      {:ok, message}
    else
      :error -> {:error, "Could not unfollow that item."}
      nil -> {:error, "Could not find that followed item."}
      {:error, message} -> {:error, message}
      _other -> {:error, "Could not unfollow that item."}
    end
  end

  defp find_user_follow(%User{} = user, follow_id) do
    user
    |> Follows.list_user_follows()
    |> Enum.find(&(&1.id == follow_id))
  end

  defp unfollow_target(%User{} = user, %{target_type: "graph", graph: %Graph{} = graph}) do
    case Follows.unfollow_graph(user, graph) do
      {:ok, _count} -> {:ok, "Grid unfollowed."}
      _error -> {:error, "Could not unfollow that grid."}
    end
  end

  defp unfollow_target(%User{} = user, %{target_type: "user", target_user: %User{} = target_user}) do
    case Follows.unfollow_user(user, target_user) do
      {:ok, _count} -> {:ok, "Profile unfollowed."}
      _error -> {:error, "Could not unfollow that profile."}
    end
  end

  defp unfollow_target(_user, _follow), do: {:error, "Could not unfollow that item."}

  defp activity_context(user, follows) do
    %{
      user_id: user && user.id,
      followed_graphs:
        follows
        |> Enum.filter(&(&1.target_type == "graph"))
        |> Map.new(fn follow ->
          {follow.graph_title,
           %{followed_at: follow.inserted_at, last_seen_at: follow.last_seen_at}}
        end),
      followed_users:
        follows
        |> Enum.filter(&(&1.target_type == "user"))
        |> Map.new(fn follow ->
          {follow.target_user_id,
           %{followed_at: follow.inserted_at, last_seen_at: follow.last_seen_at}}
        end)
    }
  end

  defp activity_feed(nil, _follows, _context), do: []

  defp activity_feed(%User{} = user, follows, context) do
    []
    |> Kernel.++(user_follow_items(user))
    |> Kernel.++(grid_follow_items(user))
    |> Kernel.++(followed_user_created_grid_items(context))
    |> Kernel.++(followed_grid_event_items(context))
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
    if map_size(context.followed_users) == 0 do
      []
    else
      followed_user_ids = Map.keys(context.followed_users)

      Log
      |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
      |> join(:inner, [_log, graph], actor in User, on: actor.id == graph.user_id)
      |> where(
        [log, graph, _actor],
        log.action == "graph.created" and graph.user_id in ^followed_user_ids
      )
      |> where([_log, graph, _actor], graph.is_public == true and graph.is_published == true)
      |> where([_log, graph, _actor], graph.is_deleted != true)
      |> order_by([log, _graph, _actor], desc: log.inserted_at, desc: log.id)
      |> limit(75)
      |> preload([_log, graph, actor], graph: graph, actor: actor)
      |> Repo.all()
      |> Enum.filter(fn log ->
        followed_after?(log.inserted_at, Map.fetch!(context.followed_users, log.graph.user_id))
      end)
      |> Enum.map(fn log ->
        follow = Map.fetch!(context.followed_users, log.graph.user_id)

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
          action_label: "Open grid",
          new_count: new_count([log], follow.last_seen_at),
          unseen?: unseen_since?(log.inserted_at, follow.last_seen_at)
        }
      end)
    end
  end

  defp followed_grid_event_items(context) do
    if map_size(context.followed_graphs) == 0 do
      []
    else
      followed_graph_titles = Map.keys(context.followed_graphs)

      Log
      |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
      |> join(:left, [log, _graph], actor in User, on: actor.id == log.actor_user_id)
      |> where(
        [log, graph, _actor],
        log.graph_title in ^followed_graph_titles and log.action != "graph.created"
      )
      |> where([_log, graph, _actor], graph.is_public == true and graph.is_published == true)
      |> where([_log, graph, _actor], graph.is_deleted != true)
      |> order_by([log, _graph, _actor], desc: log.inserted_at, desc: log.id)
      |> limit(200)
      |> preload([_log, graph, actor], graph: graph, actor: actor)
      |> Repo.all()
      |> Enum.filter(fn log ->
        followed_after?(log.inserted_at, Map.fetch!(context.followed_graphs, log.graph_title))
      end)
      |> Enum.map(fn log ->
        follow = Map.fetch!(context.followed_graphs, log.graph_title)

        %{
          id: "followed-grid-log-#{log.id}",
          category: "following",
          type: :followed_grid_updated,
          actor: log.actor,
          graph: log.graph,
          latest_log: log,
          occurred_at: log.inserted_at,
          icon: action_icon(log),
          title: GridActivity.display_message(log),
          body: log.graph.title,
          path: graph_path(log.graph, log.node_id),
          action_label: "Open",
          node_label: node_label(log),
          new_count: new_count([log], follow.last_seen_at),
          unseen?: unseen_since?(log.inserted_at, follow.last_seen_at)
        }
      end)
    end
  end

  defp group_logs(logs, category, type, title, action_label, seen_context \\ %{}) do
    logs
    |> Enum.group_by(& &1.graph_title)
    |> Enum.map(fn {_graph_title, group_logs} ->
      sorted_logs = Enum.sort_by(group_logs, & &1.inserted_at, {:desc, DateTime})
      latest = List.first(sorted_logs)
      count = length(sorted_logs)
      tracks_seen? = Map.has_key?(seen_context, latest.graph_title)
      seen_at = seen_at_for(latest.graph_title, seen_context)

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
        action_label: action_label,
        new_count: if(tracks_seen?, do: new_count(sorted_logs, seen_at), else: 0),
        unseen?: tracks_seen? && unseen_since?(latest.inserted_at, seen_at)
      }
    end)
    |> Enum.sort_by(& &1.occurred_at, {:desc, DateTime})
  end

  defp followed_after?(_inserted_at, %{followed_at: nil}), do: true

  defp followed_after?(inserted_at, %{followed_at: followed_at}) do
    DateTime.compare(inserted_at, followed_at) in [:gt, :eq]
  end

  defp seen_at_for(graph_title, seen_context) do
    seen_context
    |> Map.get(graph_title, %{})
    |> Map.get(:last_seen_at)
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

  defp activity_stats(feed_items, owned_grid_items, follows) do
    since = DateTime.add(DateTime.utc_now(), -7, :day)
    all_items = feed_items ++ owned_grid_items

    %{
      followed_grids: Enum.count(follows, &(&1.target_type == "graph")),
      followed_users: Enum.count(follows, &(&1.target_type == "user")),
      updates_this_week:
        Enum.reduce(all_items, 0, fn item, total ->
          total + item_event_count_since(item, since)
        end),
      new_following:
        feed_items
        |> Enum.filter(&(&1.category == "following"))
        |> Enum.reduce(0, fn item, total -> total + Map.get(item, :new_count, 0) end),
      feed_count: length(feed_items),
      owned_grid_count: length(owned_grid_items),
      owned_update_count: Enum.reduce(owned_grid_items, 0, &(&2 + Map.get(&1, :count, 0))),
      last_update:
        all_items
        |> Enum.sort_by(& &1.occurred_at, {:desc, DateTime})
        |> List.first()
        |> then(&(&1 && &1.occurred_at))
    }
  end

  defp activity_filters(items) do
    counts = %{
      "all" => length(items),
      "mentions" => Enum.count(items, &(&1.category == "mentions")),
      "following" => Enum.count(items, &(&1.category == "following"))
    }

    new_counts = %{
      "all" => new_item_count(items),
      "mentions" => 0,
      "following" => new_item_count(Enum.filter(items, &(&1.category == "following")))
    }

    Enum.map(@feed_filters, fn filter ->
      filter
      |> Map.put(:count, Map.get(counts, filter.id, 0))
      |> Map.put(:new_count, Map.get(new_counts, filter.id, 0))
    end)
  end

  defp item_event_count_since(%{logs: logs}, since) do
    Enum.count(logs, &(DateTime.compare(&1.inserted_at, since) in [:gt, :eq]))
  end

  defp item_event_count_since(%{occurred_at: occurred_at}, since) when not is_nil(occurred_at) do
    if DateTime.compare(occurred_at, since) in [:gt, :eq], do: 1, else: 0
  end

  defp item_event_count_since(_item, _since), do: 0

  defp new_item_count(items) do
    Enum.reduce(items, 0, fn item, total -> total + Map.get(item, :new_count, 0) end)
  end

  defp new_count(logs, nil), do: length(logs)

  defp new_count(logs, seen_at) do
    Enum.count(logs, &(DateTime.compare(&1.inserted_at, seen_at) == :gt))
  end

  defp unseen_since?(_inserted_at, nil), do: true
  defp unseen_since?(inserted_at, seen_at), do: DateTime.compare(inserted_at, seen_at) == :gt

  defp activity_time(nil), do: ""
  defp activity_time(inserted_at), do: Calendar.strftime(inserted_at, "%d %b %Y, %H:%M")

  defp last_update_label(nil), do: "No updates"
  defp last_update_label(inserted_at), do: Calendar.strftime(inserted_at, "%d %b, %H:%M")

  defp follow_label(%{target_type: "graph", graph: %Graph{title: title}}), do: title
  defp follow_label(%{target_type: "user", target_user: %User{} = user}), do: display_name(user)
  defp follow_label(_follow), do: "Followed item"

  defp follow_type_label(%{target_type: "graph"}), do: "Grid"
  defp follow_type_label(%{target_type: "user"}), do: "Profile"
  defp follow_type_label(_follow), do: "Follow"

  defp follow_icon(%{target_type: "graph"}), do: "hero-squares-2x2"
  defp follow_icon(%{target_type: "user"}), do: "hero-user"
  defp follow_icon(_follow), do: "hero-bell"

  defp follow_icon_tone_class(%{target_type: "graph"}), do: "bg-amber-50 text-amber-700"
  defp follow_icon_tone_class(%{target_type: "user"}), do: "bg-emerald-50 text-emerald-700"
  defp follow_icon_tone_class(_follow), do: "bg-slate-100 text-slate-700"

  defp follow_path(%{target_type: "graph", graph: %Graph{} = graph}), do: graph_path(graph)
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

  defp item_detail(%{type: :followed_grid_updated, count: count} = item) do
    cond do
      Map.get(item, :new_count, 0) > 0 ->
        "#{update_count_label(item.new_count)} since last seen"

      true ->
        "#{update_count_label(count)} since you followed it"
    end
  end

  defp item_detail(%{type: :followed_grid_updated} = item) do
    if Map.get(item, :unseen?, false) do
      "New from a followed grid"
    else
      "Followed grid"
    end
  end

  defp item_detail(%{type: :user_followed_you}), do: "New follower"
  defp item_detail(%{type: :grid_followed}), do: "New grid follower"

  defp item_detail(%{type: :followed_user_created_grid} = item) do
    if Map.get(item, :unseen?, false) do
      "New grid from someone you follow"
    else
      "Grid from someone you follow"
    end
  end

  defp item_detail(_item), do: nil

  defp item_preview_logs(%{logs: logs}), do: Enum.take(logs, 3)
  defp item_preview_logs(_item), do: []

  defp empty_state_title("mentions"), do: "No mentions yet"
  defp empty_state_title("following"), do: "No followed activity yet"
  defp empty_state_title(_filter), do: "No feed events yet"

  defp empty_state_body("mentions") do
    "When someone follows you or one of your grids, it will appear here."
  end

  defp empty_state_body("your_grids") do
    "Invite people into a grid or share a grid link to get the discussion moving."
  end

  defp empty_state_body("following") do
    "Follow public grids or users to turn this into a useful reading list."
  end

  defp empty_state_body(_filter) do
    "Mentions and updates from grids or people you follow will appear here."
  end

  defp unseen_item?(item), do: Map.get(item, :unseen?, false)

  defp item_accent_class(%{category: "mentions"}), do: "border-l-emerald-400"
  defp item_accent_class(%{category: "following", unseen?: true}), do: "border-l-indigo-500"
  defp item_accent_class(%{category: "following"}), do: "border-l-sky-300"
  defp item_accent_class(%{category: "your_grids"}), do: "border-l-amber-400"
  defp item_accent_class(_item), do: "border-l-slate-200"

  defp item_icon_tone_class(%{category: "mentions"}), do: "bg-emerald-50 text-emerald-700"

  defp item_icon_tone_class(%{category: "following", unseen?: true}),
    do: "bg-indigo-600 text-white"

  defp item_icon_tone_class(%{category: "following"}), do: "bg-sky-50 text-sky-700"
  defp item_icon_tone_class(%{category: "your_grids"}), do: "bg-amber-50 text-amber-700"
  defp item_icon_tone_class(_item), do: "bg-slate-100 text-slate-700"

  defp item_source_label(%{category: "mentions"}), do: "Mention"
  defp item_source_label(%{category: "following"}), do: "Following"
  defp item_source_label(%{category: "your_grids"}), do: "Your grid"
  defp item_source_label(_item), do: "Activity"

  defp node_context(%{node_label: node_label}) when is_binary(node_label) and node_label != "",
    do: node_label

  defp node_context(%{latest_log: log}), do: node_label(log)
  defp node_context(_item), do: nil

  defp action_icon(%{action: "node.deleted"}), do: "hero-trash"

  defp action_icon(%{action: action}) when is_binary(action) do
    cond do
      String.contains?(action, "comment") -> "hero-chat-bubble-left-right"
      String.contains?(action, "branch") -> "hero-squares-plus"
      String.contains?(action, "question") -> "hero-question-mark-circle"
      true -> "hero-bolt"
    end
  end

  defp action_icon(_log), do: "hero-bolt"

  defp node_label(%{metadata: %{"node_title" => title}}) when is_binary(title) and title != "" do
    title
  end

  defp node_label(%{node_id: node_id, graph: %Graph{} = graph})
       when is_binary(node_id) and node_id != "" do
    case find_graph_node(graph, node_id) do
      nil -> "Node #{node_id}"
      node -> NodeTitleHelper.extract_node_title(node, max_length: 96)
    end
  end

  defp node_label(%{node_id: node_id}) when is_binary(node_id) and node_id != "",
    do: "Node #{node_id}"

  defp node_label(_log), do: nil

  defp find_graph_node(%Graph{data: data}, node_id) when is_map(data) do
    data
    |> graph_nodes()
    |> Enum.find(&(node_id_for(&1) == node_id))
  end

  defp find_graph_node(_graph, _node_id), do: nil

  defp graph_nodes(data) do
    nodes = Map.get(data, "nodes") || Map.get(data, :nodes) || []

    if is_list(nodes), do: nodes, else: []
  end

  defp node_id_for(node) when is_map(node), do: Map.get(node, "id") || Map.get(node, :id)
  defp node_id_for(_node), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="activity-page" class="min-h-screen bg-[#f7f9fc] px-4 py-6 sm:px-6 sm:py-8">
      <div class="mx-auto max-w-5xl">
        <header class="border-b border-slate-200 pb-5">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="inline-flex items-center gap-2 rounded-full border border-indigo-100 bg-white px-2.5 py-1 text-xs font-semibold uppercase tracking-[0.14em] text-indigo-700 shadow-sm">
                <.icon name="hero-bolt" class="h-3.5 w-3.5" /> Network activity
              </p>
              <h1 class="mt-3 text-3xl font-semibold tracking-tight text-slate-950">Activity</h1>
            </div>

            <button
              :if={@activity_stats.new_following > 0}
              id="activity-mark-seen-button"
              type="button"
              phx-click="mark_seen"
              class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:border-indigo-200 hover:bg-indigo-50 hover:text-indigo-700"
            >
              <.icon name="hero-check" class="h-4 w-4" /> Mark following seen
              <span
                :if={@activity_stats.new_following > 0}
                class="ml-1 rounded-full bg-indigo-600 px-2 py-0.5 text-xs text-white"
              >
                {@activity_stats.new_following}
              </span>
            </button>
          </div>

          <section id="activity-summary" class="mt-4 flex flex-wrap items-center gap-2 text-sm">
            <button
              id="activity-summary-feed"
              type="button"
              phx-click="show_area"
              phx-value-area="feed"
              class="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3 py-1.5 font-medium text-slate-700 shadow-sm transition hover:border-sky-200 hover:bg-sky-50 hover:text-sky-800"
            >
              <.icon name="hero-rss" class="h-4 w-4 text-sky-600" /> {@activity_stats.feed_count} feed events
            </button>
            <button
              id="activity-summary-my-grids"
              type="button"
              phx-click="show_area"
              phx-value-area="my_grids"
              class="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3 py-1.5 font-medium text-slate-700 shadow-sm transition hover:border-amber-200 hover:bg-amber-50 hover:text-amber-800"
            >
              <.icon name="hero-squares-2x2" class="h-4 w-4 text-amber-600" /> {update_count_label(
                @activity_stats.owned_update_count
              )} on your grids
            </button>
            <button
              id="activity-summary-following"
              type="button"
              phx-click="show_area"
              phx-value-area="following"
              class="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3 py-1.5 font-medium text-slate-700 shadow-sm transition hover:border-emerald-200 hover:bg-emerald-50 hover:text-emerald-800"
            >
              <.icon name="hero-user-group" class="h-4 w-4 text-emerald-600" />
              {@activity_stats.followed_grids + @activity_stats.followed_users} following
            </button>
            <span class="inline-flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-3 py-1.5 font-medium text-slate-700 shadow-sm">
              <.icon name="hero-clock" class="h-4 w-4 text-slate-500" />
              Latest {last_update_label(@activity_stats.last_update)}
            </span>
          </section>
        </header>

        <div class="mt-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div
            id="activity-tabs"
            class="inline-flex w-full rounded-lg border border-slate-200 bg-white p-1 shadow-sm sm:w-auto"
          >
            <button
              id="activity-tab-feed"
              type="button"
              phx-click="set_tab"
              phx-value-tab="feed"
              class={[
                "flex flex-1 items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition sm:flex-none",
                if(@activity_tab == "feed",
                  do: "bg-slate-950 text-white shadow-sm",
                  else: "text-slate-600 hover:bg-slate-50 hover:text-slate-950"
                )
              ]}
            >
              <.icon name="hero-rss" class="h-4 w-4" /> Feed
              <span class="rounded-full bg-white/15 px-2 py-0.5 text-xs">
                {@activity_stats.feed_count}
              </span>
            </button>
            <button
              id="activity-tab-my-grids"
              type="button"
              phx-click="set_tab"
              phx-value-tab="my_grids"
              class={[
                "flex flex-1 items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition sm:flex-none",
                if(@activity_tab == "my_grids",
                  do: "bg-slate-950 text-white shadow-sm",
                  else: "text-slate-600 hover:bg-slate-50 hover:text-slate-950"
                )
              ]}
            >
              <.icon name="hero-squares-2x2" class="h-4 w-4" /> My grids
              <span class="rounded-full bg-white/15 px-2 py-0.5 text-xs">
                {@activity_stats.owned_grid_count}
              </span>
            </button>
            <button
              id="activity-tab-following"
              type="button"
              phx-click="set_tab"
              phx-value-tab="following"
              class={[
                "flex flex-1 items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-semibold transition sm:flex-none",
                if(@activity_tab == "following",
                  do: "bg-slate-950 text-white shadow-sm",
                  else: "text-slate-600 hover:bg-slate-50 hover:text-slate-950"
                )
              ]}
            >
              <.icon name="hero-user-group" class="h-4 w-4" /> Following
              <span class="rounded-full bg-white/15 px-2 py-0.5 text-xs">
                {@activity_stats.followed_grids + @activity_stats.followed_users}
              </span>
            </button>
          </div>

          <div :if={@activity_tab == "feed"} id="activity-filter-list" class="flex flex-wrap gap-2">
            <%= for filter <- @activity_filters do %>
              <button
                id={"activity-filter-#{filter.id}"}
                type="button"
                phx-click="set_filter"
                phx-value-filter={filter.id}
                class={[
                  "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-semibold transition",
                  if(@activity_filter == filter.id,
                    do: "border-indigo-200 bg-indigo-50 text-indigo-700",
                    else:
                      "border-slate-200 bg-white text-slate-600 hover:border-slate-300 hover:text-slate-950"
                  )
                ]}
              >
                <.icon name={filter.icon} class="h-4 w-4" />
                <span>{filter.label}</span>
                <span
                  :if={filter.new_count > 0}
                  class="rounded-full bg-indigo-600 px-2 py-0.5 text-[11px] text-white"
                >
                  {filter.new_count} new
                </span>
                <span class="rounded-full bg-white px-2 py-0.5 text-xs text-slate-500 ring-1 ring-slate-200">
                  {filter.count}
                </span>
              </button>
            <% end %>
          </div>
        </div>

        <main class="mt-5">
          <section :if={@activity_tab == "feed"} id="activity-feed-panel">
            <%= if @activity_feed_items == [] do %>
              <div
                id="activity-feed-empty"
                class="rounded-lg border border-slate-200 bg-white p-10 text-center shadow-sm"
              >
                <.icon name="hero-bell-alert" class="mx-auto h-10 w-10 text-slate-300" />
                <h2 class="mt-3 text-base font-semibold text-slate-950">
                  {empty_state_title(@activity_filter)}
                </h2>
                <p class="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-500">
                  {empty_state_body(@activity_filter)}
                </p>
              </div>
            <% else %>
              <ol id="activity-stream" class="space-y-3">
                <%= for item <- @activity_feed_items do %>
                  <li
                    id={"activity-item-#{item.id}"}
                    class={[
                      "relative overflow-hidden rounded-lg border border-l-4 border-slate-200 bg-white p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md",
                      item_accent_class(item),
                      unseen_item?(item) && "ring-1 ring-indigo-100"
                    ]}
                  >
                    <div class="flex items-start gap-3">
                      <div class={[
                        "mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg",
                        item_icon_tone_class(item)
                      ]}>
                        <.icon name={item.icon} class="h-5 w-5" />
                      </div>

                      <div class="min-w-0 flex-1">
                        <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                          <div class="min-w-0">
                            <div class="flex flex-wrap items-center gap-2 text-xs font-semibold">
                              <span class="text-slate-500">{item_source_label(item)}</span>
                              <span
                                :if={unseen_item?(item)}
                                class="rounded-full bg-indigo-600 px-2 py-0.5 text-[11px] text-white"
                              >
                                New
                              </span>
                              <span class="text-slate-400">{activity_time(item.occurred_at)}</span>
                            </div>

                            <p class="mt-1 text-sm font-semibold leading-6 text-slate-950">
                              {item.title}
                            </p>

                            <.link
                              :if={item.path && item.body}
                              navigate={item.path}
                              class="mt-2 inline-flex max-w-full items-center gap-1.5 rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs font-semibold text-slate-700 transition hover:border-indigo-200 hover:bg-indigo-50 hover:text-indigo-700"
                            >
                              <.icon name="hero-squares-2x2" class="h-3.5 w-3.5 shrink-0" />
                              <span class="truncate">{item.body}</span>
                            </.link>

                            <p :if={node_context(item)} class="mt-2 text-xs text-slate-500">
                              {node_context(item)}
                            </p>

                            <p class="mt-2 text-xs font-medium text-slate-400">
                              {item_detail(item)}
                            </p>
                          </div>

                          <.link
                            :if={item.path}
                            navigate={item.path}
                            class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-50"
                          >
                            {item.action_label} <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                          </.link>
                        </div>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ol>
            <% end %>
          </section>

          <section :if={@activity_tab == "my_grids"} id="activity-my-grids-panel">
            <%= if @owned_grid_items == [] do %>
              <div
                id="activity-my-grids-empty"
                class="rounded-lg border border-slate-200 bg-white p-10 text-center shadow-sm"
              >
                <.icon name="hero-squares-2x2" class="mx-auto h-10 w-10 text-slate-300" />
                <h2 class="mt-3 text-base font-semibold text-slate-950">
                  No updates on your grids yet
                </h2>
                <p class="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-500">
                  Share a grid or invite someone into a discussion to create movement here.
                </p>
              </div>
            <% else %>
              <ol id="owned-grid-updates" class="grid gap-3">
                <%= for item <- @owned_grid_items do %>
                  <li
                    id={"activity-item-#{item.id}"}
                    class={[
                      "rounded-lg border border-l-4 border-slate-200 bg-white p-4 shadow-sm",
                      item_accent_class(item)
                    ]}
                  >
                    <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                      <div class="min-w-0">
                        <div class="flex flex-wrap items-center gap-2 text-xs font-semibold">
                          <span class="text-amber-700">{item_source_label(item)}</span>
                          <span class="rounded-full bg-amber-50 px-2 py-0.5 text-amber-700 ring-1 ring-amber-100">
                            {update_count_label(item.count)}
                          </span>
                          <span class="text-slate-400">{activity_time(item.occurred_at)}</span>
                        </div>
                        <h2 class="mt-1 text-base font-semibold leading-6 text-slate-950">
                          {item.graph.title}
                        </h2>
                        <p class="mt-1 text-sm text-slate-500">{item_detail(item)}</p>
                      </div>

                      <.link
                        :if={item.path}
                        navigate={item.path}
                        class="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-50"
                      >
                        {item.action_label} <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                      </.link>
                    </div>

                    <ol :if={item_preview_logs(item) != []} class="mt-3 grid gap-2">
                      <%= for log <- item_preview_logs(item) do %>
                        <li
                          id={"activity-log-#{log.id}"}
                          class="flex items-start gap-2 rounded-md bg-slate-50 px-3 py-2"
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
                  </li>
                <% end %>
              </ol>
            <% end %>
          </section>

          <section :if={@activity_tab == "following"} id="activity-following-panel">
            <%= if @follows == [] do %>
              <div
                id="activity-following-empty"
                class="rounded-lg border border-slate-200 bg-white p-10 text-center shadow-sm"
              >
                <.icon name="hero-user-group" class="mx-auto h-10 w-10 text-slate-300" />
                <h2 class="mt-3 text-base font-semibold text-slate-950">
                  You are not following anything yet
                </h2>
                <p class="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-500">
                  Follow public grids or profiles to build a useful activity feed.
                </p>
              </div>
            <% else %>
              <div
                id="activity-following-list"
                class="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm"
              >
                <div class="border-b border-slate-100 px-4 py-3">
                  <h2 class="text-sm font-semibold text-slate-950">Grids and people you follow</h2>
                  <p class="mt-1 text-xs text-slate-500">
                    Manage what appears in your feed.
                  </p>
                </div>

                <ol>
                  <%= for follow <- @follows do %>
                    <% path = follow_path(follow) %>
                    <li
                      id={"activity-follow-#{follow.id}"}
                      class="flex flex-col gap-3 border-b border-slate-100 px-4 py-3 last:border-b-0 sm:flex-row sm:items-center sm:justify-between"
                    >
                      <div class="flex min-w-0 items-start gap-3">
                        <div class={[
                          "mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg",
                          follow_icon_tone_class(follow)
                        ]}>
                          <.icon name={follow_icon(follow)} class="h-5 w-5" />
                        </div>

                        <div class="min-w-0">
                          <p class="text-sm font-semibold leading-6 text-slate-950">
                            {follow_label(follow)}
                          </p>
                          <p class="text-xs font-medium text-slate-500">
                            {follow_type_label(follow)} · Followed {activity_time(follow.inserted_at)}
                          </p>
                        </div>
                      </div>

                      <div class="flex shrink-0 items-center gap-2">
                        <.link
                          :if={path}
                          navigate={path}
                          class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 transition hover:bg-slate-50"
                        >
                          Open <.icon name="hero-arrow-right" class="h-3.5 w-3.5" />
                        </.link>

                        <button
                          id={"activity-unfollow-#{follow.id}"}
                          type="button"
                          phx-click="unfollow"
                          phx-value-follow-id={follow.id}
                          class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-rose-200 bg-white px-3 py-1.5 text-xs font-semibold text-rose-700 transition hover:bg-rose-50"
                        >
                          <.icon name="hero-x-mark" class="h-3.5 w-3.5" /> Unfollow
                        </button>
                      </div>
                    </li>
                  <% end %>
                </ol>
              </div>
            <% end %>
          </section>
        </main>
      </div>
    </div>
    """
  end
end
