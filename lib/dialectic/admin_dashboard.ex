defmodule Dialectic.AdminDashboard do
  import Ecto.Query

  require Logger

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.GridActivity.Log
  alias Dialectic.Repo

  @active_job_states ["available", "executing", "scheduled", "retryable"]
  @query_options [timeout: 3_000]

  def snapshot(%User{is_admin: true}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    week = DateTime.add(now, -7, :day)
    day = DateTime.add(now, -1, :day)
    started = System.monotonic_time(:millisecond)

    with {:ok, _} <- Ecto.Adapters.SQL.query(Repo, "SELECT 1", [], @query_options) do
      database_ms = System.monotonic_time(:millisecond) - started

      {:ok,
       %{
         measured_at: now,
         database_ms: database_ms,
         users: users(week),
         grids: grids(week),
         activity: activity(week, day),
         queues: queues(day),
         recent_users: recent_users(),
         recent_grids: recent_grids(),
         attention_jobs: attention_jobs(day),
         runtime: runtime()
       }}
    else
      _ -> {:error, :unavailable}
    end
  rescue
    error ->
      Logger.warning("Admin dashboard snapshot failed: #{inspect(error.__struct__)}")
      {:error, :unavailable}
  end

  def snapshot(_user), do: {:error, :forbidden}

  defp users(week) do
    Repo.one(
      from(u in User,
        select: %{
          total: count(u.id),
          new_week: filter(count(u.id), u.inserted_at >= ^week),
          confirmed: filter(count(u.id), not is_nil(u.confirmed_at)),
          creators: filter(count(u.id), u.id in subquery(from(g in Graph, select: g.user_id)))
        }
      ),
      @query_options
    )
  end

  defp grids(week) do
    Repo.one(
      from(g in Graph,
        select: %{
          total: count(g.title),
          new_week: filter(count(g.title), g.inserted_at >= ^week),
          public:
            filter(count(g.title), g.is_public == true and not coalesce(g.is_deleted, false)),
          private:
            filter(
              count(g.title),
              not coalesce(g.is_public, false) and not coalesce(g.is_deleted, false)
            ),
          hidden: filter(count(g.title), g.is_deleted == true),
          ownerless:
            filter(count(g.title), is_nil(g.user_id) and not coalesce(g.is_deleted, false))
        }
      ),
      @query_options
    )
  end

  defp activity(week, day) do
    Repo.one(
      from(l in Log,
        where: l.inserted_at >= ^week,
        select: %{
          contributors_week: count(l.actor_user_id, :distinct),
          events_day: filter(count(l.id), l.inserted_at >= ^day)
        }
      ),
      @query_options
    )
  end

  defp queues(day) do
    counts =
      Repo.all(
        from(j in Oban.Job,
          where:
            j.state in ^@active_job_states or
              (j.state == "completed" and j.completed_at >= ^day) or
              (j.state == "discarded" and j.discarded_at >= ^day),
          group_by: [j.queue, j.state],
          select: {j.queue, j.state, count(j.id)}
        ),
        @query_options
      )

    configured = Application.get_env(:dialectic, Oban, []) |> Keyword.get(:queues, [])

    names =
      (Enum.map(configured, fn {name, _} -> to_string(name) end) ++ Enum.map(counts, &elem(&1, 0)))
      |> Enum.uniq()
      |> Enum.sort()

    Enum.map(names, fn name ->
      states = for {^name, state, count} <- counts, into: %{}, do: {state, count}
      local = Oban.check_queue(queue: name)

      %{
        id: name,
        local_status:
          cond do
            is_nil(local) -> "No local worker"
            local.paused -> "Paused locally"
            true -> "Running locally · limit #{local.limit}"
          end,
        waiting: Map.get(states, "available", 0),
        running: Map.get(states, "executing", 0),
        scheduled: Map.get(states, "scheduled", 0),
        retrying: Map.get(states, "retryable", 0),
        completed: Map.get(states, "completed", 0),
        failed: Map.get(states, "discarded", 0)
      }
    end)
  end

  defp recent_users do
    Repo.all(
      from(u in User,
        order_by: [desc: u.inserted_at, desc: u.id],
        limit: 6,
        select: %{id: u.id, username: u.username, email: u.email, inserted_at: u.inserted_at}
      ),
      @query_options
    )
  end

  defp recent_grids do
    Repo.all(
      from(g in Graph,
        left_join: u in User,
        on: u.id == g.user_id,
        order_by: [desc: g.updated_at, asc: g.title],
        limit: 6,
        select: %{
          id: g.title,
          title: g.title,
          slug: g.slug,
          user_id: g.user_id,
          username: u.username,
          is_public: g.is_public,
          is_deleted: g.is_deleted,
          updated_at: g.updated_at
        }
      ),
      @query_options
    )
  end

  defp attention_jobs(day) do
    Repo.all(
      from(j in Oban.Job,
        where: j.state == "retryable" or (j.state == "discarded" and j.discarded_at >= ^day),
        order_by: [desc: j.attempted_at, desc: j.id],
        limit: 5,
        select: %{
          id: j.id,
          queue: j.queue,
          worker: j.worker,
          state: j.state,
          attempt: j.attempt,
          max_attempts: j.max_attempts
        }
      ),
      @query_options
    )
  end

  defp runtime do
    presences = DialecticWeb.Presence.list("online_users")
    {uptime_ms, _} = :erlang.statistics(:wall_clock)

    %{
      viewers: map_size(presences),
      open_grids:
        presences
        |> Map.values()
        |> Enum.flat_map(& &1.metas)
        |> Enum.map(& &1.graph_id)
        |> Enum.uniq()
        |> length(),
      memory_mb: round(:erlang.memory(:total) / 1_048_576),
      uptime_seconds: div(uptime_ms, 1_000),
      processes: :erlang.system_info(:process_count),
      loaded_grids: DynamicSupervisor.count_children(GraphSupervisor).active,
      node: to_string(node()),
      environment: Application.get_env(:dialectic, :env, :unknown),
      version: Application.spec(:dialectic, :vsn) |> to_string(),
      jobs_running?: is_pid(Oban.whereis(Oban))
    }
  end
end
