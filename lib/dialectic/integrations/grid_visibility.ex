defmodule Dialectic.Integrations.GridVisibility do
  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.{Exploration, GridAction, GridActions}
  alias Dialectic.Repo

  def set(user, slug, params) do
    with true <- Map.keys(params) -- ~w(slug request_id visibility expected_revision) == [],
         {:ok, _uuid} <- Ecto.UUID.cast(params["request_id"]),
         visibility when visibility in ["public", "private"] <- params["visibility"],
         expected <- params["expected_revision"],
         true <- is_nil(expected) or (is_integer(expected) and expected >= 0),
         true <- visibility == "private" or is_integer(expected) do
      case Repo.get_by(Graph, slug: slug) do
        %Graph{} = graph ->
          if owner?(graph, user),
            do: GraphManager.set_mcp_visibility(graph.title, user, params),
            else: {:error, :not_found}

        _ ->
          {:error, :not_found}
      end
    else
      _ -> {:error, :invalid_arguments}
    end
  end

  def set_in_graph({graph_struct, live_graph} = state, user, params) do
    slug = graph_struct.slug
    {:ok, uuid} = Ecto.UUID.cast(params["request_id"])
    expected = params["expected_revision"]
    visibility = params["visibility"]
    hash = :crypto.hash(:sha256, :erlang.term_to_binary({slug, visibility, expected}))

    result =
      Repo.transact(fn ->
        GridActions.lock_request(user.id, uuid)
        graph = Repo.one(from g in Graph, where: g.slug == ^slug, lock: "FOR UPDATE")
        receipt = Repo.get_by(GridAction, user_id: user.id, request_id: uuid)

        cond do
          not owner?(graph, user) ->
            {:error, :not_found}

          receipt && (receipt.action != "set_grid_visibility" or receipt.content_hash != hash) ->
            {:error, :request_conflict}

          receipt ->
            {:ok, envelope(receipt, :accepted)}

          not is_nil(expected) and expected != graph.data_revision ->
            {:error, :stale}

          true ->
            with :ok <- live_revision(graph, graph_struct, live_graph, visibility == "public"),
                 {:ok, updated} <- commit(graph, visibility == "public"),
                 {:ok, receipt} <-
                   Repo.insert(%GridAction{
                     user_id: user.id,
                     request_id: uuid,
                     graph_title: graph.title,
                     action: "set_grid_visibility",
                     content_hash: hash,
                     status: "completed",
                     completed_revision: updated.data_revision,
                     result: %{
                       "visibility" => visibility,
                       "visibility_version" => updated.visibility_version,
                       "committed_content_revision" => updated.data_revision,
                       "canonical_url" => DialecticWeb.Endpoint.url() <> "/g/" <> updated.slug,
                       "application_state" => "applied",
                       "anonymous_access_verification" => "pending"
                     }
                   }) do
              %{"request_id" => uuid, "user_id" => user.id}
              |> Dialectic.Workers.VisibilityVerificationWorker.new()
              |> Oban.insert!()

              {:ok, envelope(receipt, :accepted)}
            end
        end
      end)

    state =
      case result do
        {:ok, _} ->
          fresh = Repo.get!(Graph, graph_struct.title)

          {%{
             graph_struct
             | is_public: fresh.is_public,
               visibility_version: fresh.visibility_version
           }, live_graph}

        _ ->
          state
      end

    {result, state}
  end

  def change(graph, user, false), do: change_in_graph(nil, graph, user, false)

  def change(graph, user, target) do
    GraphManager.change_visibility(graph.title, user, target)
  end

  def change_in_graph(state, graph, user, target) do
    Repo.transact(fn ->
      fresh = Repo.one(from g in Graph, where: g.title == ^graph.title, lock: "FOR UPDATE")

      if owner?(fresh, user) do
        public? = if(target == :toggle, do: fresh.is_public != true, else: target)
        with :ok <- live_revision(fresh, state, public?), do: commit(fresh, public?)
      else
        {:error, :forbidden}
      end
    end)
  end

  defp live_revision(_fresh, _state, false), do: :ok
  defp live_revision(fresh, {stored, graph}, true), do: live_revision(fresh, stored, graph, true)

  defp live_revision(_fresh, _stored, _graph, false), do: :ok

  defp live_revision(fresh, stored, graph, true) do
    saved = Dialectic.Graph.Serialise.json_to_graph(fresh.data)

    try do
      if stored.data_revision <= fresh.data_revision and canonical(graph) == canonical(saved),
        do: :ok,
        else: {:error, :stale}
    after
      :digraph.delete(saved)
    end
  end

  defp canonical(graph) do
    data =
      graph |> Dialectic.Graph.Serialise.graph_to_json() |> Jason.encode!() |> Jason.decode!()

    %{nodes: Enum.sort_by(data["nodes"], & &1["id"]), edges: Enum.sort(data["edges"])}
  end

  def envelope(receipt, view \\ :current) do
    result =
      if view == :accepted,
        do: receipt.result,
        else: Map.merge(receipt.result, receipt.verification)

    %{
      schema_version: "operation_v1",
      operation_kind: "set_grid_visibility",
      request_id: receipt.request_id,
      state: "completed",
      result_revision: receipt.completed_revision,
      result: result,
      error: nil,
      updated_at: if(view == :accepted, do: receipt.inserted_at, else: receipt.updated_at),
      next_poll_after_seconds: if(result["anonymous_access_verification"] == "pending", do: 3)
    }
  end

  def active?(title) do
    Repo.exists?(
      from e in Exploration,
        left_join: job in Oban.Job,
        on: job.id == e.coordinator_job_id,
        where: e.graph_title == ^title and e.stage not in ["completed", "failed"],
        where:
          is_nil(e.coordinator_job_id) or
            job.state in ["available", "scheduled", "executing", "retryable"]
    ) or
      Repo.exists?(
        from a in GridAction,
          where: a.graph_title == ^title and a.status in ["queued", "generating"]
      ) or
      MapSet.size(Dialectic.Responses.RequestQueue.pending_node_ids(title)) > 0
  end

  defp commit(graph, public?) do
    if public? and active?(graph.title) do
      {:error, :generation_in_progress}
    else
      with {:ok, updated} <-
             graph
             |> Ecto.Changeset.change(
               is_public: public?,
               visibility_version: graph.visibility_version + 1
             )
             |> Repo.update() do
        %{"graph_title" => graph.title}
        |> Dialectic.Workers.GraphAccessNotificationWorker.new()
        |> Oban.insert!()

        {:ok, updated}
      end
    end
  end

  defp owner?(%Graph{user_id: id, is_deleted: deleted}, %{id: id}), do: deleted != true
  defp owner?(_, _), do: false
end
