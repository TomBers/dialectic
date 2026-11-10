defmodule Dialectic.Integrations.Explorations do
  import Ecto.Query
  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.Integrations.{Exploration, GridAction, GridActions, GridContent}
  alias Dialectic.Repo
  alias Dialectic.Workers.ExplorationWorker

  @stages ~w(opening testing deepening synthesizing)

  def admit(user_id) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
      "mcp-explorations:#{user_id}"
    ])

    cutoff = DateTime.add(DateTime.utc_now(), -1200, :second)

    count =
      Repo.aggregate(
        from(exploration in Exploration,
          join: job in Oban.Job,
          on: job.id == exploration.coordinator_job_id,
          where:
            exploration.user_id == ^user_id and exploration.stage not in ["completed", "failed"],
          where: exploration.inserted_at > ^cutoff,
          where: job.state in ["available", "scheduled", "executing", "retryable"]
        ),
        :count
      )

    if count < Dialectic.Integrations.McpCapabilities.max_active_explorations(),
      do: :ok,
      else: {:error, :too_many_active_operations}
  end

  def enqueue(user, request_id, graph) do
    with {:ok, exploration} <-
           Repo.insert(%Exploration{
             user_id: user.id,
             request_id: request_id,
             graph_title: graph.title
           }),
         {:ok, job} <-
           Oban.insert(ExplorationWorker.new(%{user_id: user.id, request_id: request_id})) do
      save_progress(exploration, %{coordinator_job_id: job.id})
      {:ok, graph}
    end
  end

  def progress(result, request, graph) do
    case Repo.get_by(Exploration, user_id: request.user_id, request_id: request.request_id) do
      nil ->
        result

      exploration ->
        exploration = coordinator_status(exploration)

        status =
          cond do
            exploration.stage == "completed" -> "completed"
            exploration.stage == "failed" -> "failed"
            exploration.stage == "opening" and request.status == "queued" -> "queued"
            true -> "generating"
          end

        ids =
          [request.node_id, request.answer_node_id] ++
            Enum.flat_map(tl(@stages), fn stage ->
              case exploration.steps[stage] do
                %{"node_id" => id} -> [id]
                _ -> []
              end
            end)

        {data, revision} =
          if exploration.completed_revision do
            {:ok, data, revision} =
              GridContent.at_revision(result.graph, exploration.completed_revision)

            {data, revision}
          else
            {Dialectic.Graph.Serialise.graph_to_json(graph), nil}
          end

        nodes =
          GridContent.serialize(data, request.graph_title, revision).nodes
          |> Enum.filter(&(&1.id in ids))

        completed_steps =
          if exploration.stage == "completed" do
            4
          else
            ids =
              Enum.map(@stages, fn stage ->
                if stage == "opening", do: request.request_id, else: step_id(exploration, stage)
              end)

            Repo.aggregate(
              from(operation in GridAction,
                where:
                  operation.user_id == ^request.user_id and operation.request_id in ^ids and
                    operation.status == "completed"
              ),
              :count
            )
          end

        result
        |> Map.put(:status, status)
        |> Map.put(:nodes, nodes)
        |> Map.put(:node, Enum.find(nodes, &(&1.id == request.node_id)))
        |> Map.put(:answer_node, Enum.find(nodes, &(&1.id == request.answer_node_id)))
        |> Map.put(:snapshot_revision, revision)
        |> Map.put(:exploration, %{
          stage: exploration.stage,
          completed_steps: completed_steps,
          total_steps: 4,
          error: exploration.error,
          stages:
            Enum.map(@stages, fn stage ->
              id =
                if stage == "opening",
                  do: request.answer_node_id,
                  else: get_in(exploration.steps, [stage, "node_id"])

              node = Enum.find(nodes, &(&1.id == id))

              %{
                stage: stage,
                node_id: id,
                status: if(node, do: node.generation_status, else: "not_started"),
                content_status: if(node, do: node.content_status, else: "not_started")
              }
            end)
        })
    end
  end

  def advance(user_id, request_id) do
    case Repo.get_by(Exploration, user_id: user_id, request_id: request_id) do
      nil -> :ok
      exploration -> advance_exploration(exploration, user_id)
    end
  end

  defp advance_exploration(exploration, user_id) do
    user = Repo.get(User, user_id)
    graph = Repo.get(Graph, exploration.graph_title)

    cond do
      exploration.stage in ["completed", "failed"] ->
        :ok

      DateTime.diff(DateTime.utc_now(), exploration.inserted_at) > 1200 ->
        fail(exploration, "timed_out")

      is_nil(user) or is_nil(graph) ->
        fail(exploration, "unavailable")

      graph.user_id != user.id or graph.is_deleted == true ->
        fail(exploration, "unavailable")

      (graph.is_locked == true or graph.is_public == true) and
          not synthesis_finished?(exploration) ->
        fail(exploration, "editing_stopped")

      true ->
        advance_stage(exploration, user, graph)
    end
  end

  defp coordinator_status(%{stage: stage} = exploration) when stage in ["completed", "failed"],
    do: exploration

  defp coordinator_status(%{coordinator_job_id: nil} = exploration), do: exploration

  defp coordinator_status(exploration) do
    case Repo.get(Oban.Job, exploration.coordinator_job_id) do
      %{state: state} when state in ["available", "scheduled", "executing", "retryable"] ->
        exploration

      _ ->
        %{exploration | stage: "failed", error: "coordination_stopped"}
    end
  end

  def fail(user_id, request_id, reason) do
    case Repo.get_by(Exploration, user_id: user_id, request_id: request_id) do
      nil -> :ok
      exploration -> fail(exploration, reason)
    end
  end

  defp advance_stage(exploration, user, graph) do
    operation_id =
      if exploration.stage == "opening",
        do: exploration.request_id,
        else: step_id(exploration, exploration.stage)

    operation = Repo.get_by(GridAction, user_id: user.id, request_id: operation_id)

    case operation do
      %GridAction{status: "completed"} ->
        next_stage(exploration, user, graph, operation)

      %GridAction{status: status} when status in ["failed", "unknown"] ->
        fail(exploration, "generation_failed")

      %GridAction{} ->
        {:snooze, 3}

      nil ->
        fail(exploration, "unavailable")
    end
  end

  defp next_stage(%{stage: "synthesizing"} = exploration, _user, graph, _operation) do
    case GraphManager.persist_mcp_content(graph.title, {:exploration, exploration.id}) do
      {:ok, _revision} -> :ok
      {:error, :persistence_failed} -> {:snooze, 5}
      {:error, _} -> fail(exploration, "content_not_persisted")
    end
  end

  defp next_stage(exploration, user, graph, _operation) do
    stage = Enum.at(@stages, Enum.find_index(@stages, &(&1 == exploration.stage)) + 1)
    opening = Repo.get_by!(GridAction, user_id: user.id, request_id: exploration.request_id)

    parent_id =
      if stage == "synthesizing",
        do: exploration.steps["testing"]["node_id"],
        else: opening.answer_node_id

    context_ids =
      if stage == "synthesizing", do: [exploration.steps["deepening"]["node_id"]], else: []

    params = %{
      "request_id" => step_id(exploration, stage),
      "node_id" => parent_id,
      "action" => "exploration_" <> stage,
      "context_node_ids" => context_ids,
      "content_hash" => :crypto.hash(:sha256, :erlang.term_to_binary(context_ids)),
      "private_owner_only" => true
    }

    case GridActions.continue_exploration(user, graph.slug, params) do
      {:ok, result} ->
        steps = Map.put(exploration.steps, stage, %{"node_id" => result.node.id})
        save_progress(exploration, %{stage: stage, steps: steps})
        {:snooze, 3}

      {:error, reason} when reason in [:rate_limited, :too_many_active_requests, :stale] ->
        {:snooze, 10}

      {:error, _} ->
        fail(exploration, "generation_stopped")
    end
  end

  defp synthesis_finished?(%{stage: "synthesizing"} = exploration) do
    match?(
      %{status: "completed"},
      Repo.get_by(GridAction,
        user_id: exploration.user_id,
        request_id: step_id(exploration, "synthesizing")
      )
    )
  end

  defp synthesis_finished?(_), do: false

  defp step_id(exploration, stage) do
    <<a::48, _::4, b::12, _::2, c::62, _::binary>> =
      :crypto.hash(:sha256, "#{exploration.user_id}:#{exploration.request_id}:#{stage}")

    Ecto.UUID.load!(<<a::48, 5::4, b::12, 2::2, c::62>>)
  end

  defp fail(exploration, reason) do
    save_progress(exploration, %{stage: "failed", error: reason})
    :ok
  end

  defp save_progress(exploration, attrs),
    do: exploration |> Ecto.Changeset.change(attrs) |> Repo.update!()
end
