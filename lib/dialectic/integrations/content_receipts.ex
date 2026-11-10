defmodule Dialectic.Integrations.ContentReceipts do
  import Ecto.Query
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Serialise
  alias Dialectic.Integrations.{GridAction, GridSnapshot, Exploration}
  alias Dialectic.Repo
  require Logger

  def generation_persisted?(title, node_id, job_id) do
    Repo.exists?(
      from operation in GridAction,
        where:
          operation.graph_title == ^title and operation.job_id == ^job_id and
            not is_nil(operation.completed_revision),
        where:
          operation.answer_node_id == ^node_id or
            (is_nil(operation.answer_node_id) and operation.node_id == ^node_id)
    )
  end

  def persist_generation(title, node_id, job_id) do
    operation =
      Repo.one(
        from operation in GridAction,
          where:
            operation.graph_title == ^title and operation.job_id == ^job_id and
              operation.action != "add_idea",
          where:
            operation.answer_node_id == ^node_id or
              (is_nil(operation.answer_node_id) and operation.node_id == ^node_id),
          order_by: [desc: operation.id],
          limit: 1
      )

    case operation do
      %{completed_revision: revision} when is_integer(revision) -> {:ok, revision}
      %{id: id} -> GraphManager.persist_mcp_content(title, {:operation, id})
      nil -> :not_mcp
    end
  rescue
    _error -> {:error, :persistence_failed}
  catch
    :exit, _reason -> {:error, :persistence_failed}
  end

  def persist_in_graph({graph_struct, graph} = state, receipt) do
    result =
      Repo.transact(fn ->
        stored =
          Repo.one(
            from stored in Graph, where: stored.title == ^graph_struct.title, lock: "FOR UPDATE"
          )

        cond do
          is_nil(stored) or stored.is_deleted == true ->
            {:error, :unavailable}

          stored.data_revision > graph_struct.data_revision ->
            {:error, :stale}

          true ->
            data = Serialise.graph_to_json(graph) |> Jason.encode!() |> Jason.decode!()

            revision =
              max(
                System.system_time(:microsecond),
                max(stored.data_revision, graph_struct.data_revision) + 1
              )

            with :ok <- validate_receipt(receipt, stored.title, data),
                 {:ok, :updated} <-
                   Dialectic.DbActions.Graphs.save_graph_if_newer(stored.title, data, revision),
                 {:ok, _} <-
                   Repo.insert(%GridSnapshot{
                     graph_title: stored.title,
                     revision: revision,
                     data: data
                   }),
                 :ok <- record_receipt(receipt, revision) do
              {:ok, %{stored | data: data, data_revision: revision}}
            end
        end
      end)

    case result do
      {:ok, saved} -> {{:ok, saved.data_revision}, {saved, graph}}
      {:error, reason} -> {{:error, reason}, state}
    end
  rescue
    error ->
      Logger.error("MCP content receipt could not be saved: #{inspect(error.__struct__)}")
      {{:error, :persistence_failed}, state}
  end

  defp validate_receipt({:exploration, id}, title, data) do
    exploration = Repo.get!(Exploration, id)

    opening =
      Repo.get_by!(GridAction, user_id: exploration.user_id, request_id: exploration.request_id)

    ids =
      [opening.node_id, opening.answer_node_id] ++
        Enum.map(~w(testing deepening synthesizing), &get_in(exploration.steps, [&1, "node_id"]))

    nodes = Map.new(data["nodes"], &{&1["id"], &1})

    if exploration.graph_title == title and
         Enum.all?(ids, fn id ->
           match?(%{"deleted" => false}, nodes[id]) and is_binary(nodes[id]["content"]) and
             String.trim(nodes[id]["content"]) != ""
         end), do: :ok, else: {:error, :incomplete_content}
  end

  defp validate_receipt({:operation, id}, title, data) do
    operation = Repo.get!(GridAction, id)
    node_id = operation.answer_node_id || operation.node_id

    if operation.graph_title == title and
         Enum.any?(
           data["nodes"],
           &(&1["id"] == node_id and &1["deleted"] != true and is_binary(&1["content"]))
         ), do: :ok, else: {:error, :incomplete_content}
  end

  defp record_receipt({:operation, id}, revision) do
    Repo.get!(GridAction, id)
    |> Ecto.Changeset.change(completed_revision: revision)
    |> Repo.update!()

    :ok
  end

  defp record_receipt({:exploration, id}, revision) do
    Repo.get!(Exploration, id)
    |> Ecto.Changeset.change(stage: "completed", completed_revision: revision)
    |> Repo.update!()

    :ok
  end
end
