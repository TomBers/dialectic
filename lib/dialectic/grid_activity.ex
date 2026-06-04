defmodule Dialectic.GridActivity do
  import Ecto.Query

  require Logger

  alias Dialectic.Accounts.User
  alias Dialectic.GridActivity.Log
  alias Dialectic.Repo

  @default_limit 25

  def list_for_graph(graph_title, opts \\ []) when is_binary(graph_title) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Log
    |> where([log], log.graph_title == ^graph_title)
    |> order_by([log], desc: log.inserted_at, desc: log.id)
    |> limit(^limit)
    |> Repo.all()
  end

  def record_graph_created(graph_title, actor) when is_binary(graph_title) do
    graph_title
    |> graph_created_attrs(actor)
    |> record()
  end

  def record_graph_created_async(graph_title, actor) when is_binary(graph_title) do
    graph_title
    |> graph_created_attrs(actor)
    |> record_async()
  end

  def record_node_created(graph_title, actor, message, node_id \\ nil)
      when is_binary(graph_title) and is_binary(message) do
    graph_title
    |> node_created_attrs(actor, message, node_id)
    |> record()
  end

  def record_node_created_async(graph_title, actor, message, node_id \\ nil)
      when is_binary(graph_title) and is_binary(message) do
    graph_title
    |> node_created_attrs(actor, message, node_id)
    |> record_async()
  end

  def record_node_deleted(graph_title, actor, node_id \\ nil) when is_binary(graph_title) do
    graph_title
    |> node_deleted_attrs(actor, node_id)
    |> record()
  end

  def record_node_deleted_async(graph_title, actor, node_id \\ nil) when is_binary(graph_title) do
    graph_title
    |> node_deleted_attrs(actor, node_id)
    |> record_async()
  end

  def record(attrs) when is_map(attrs) do
    insert_log(attrs)
  end

  def record_async(attrs) when is_map(attrs) do
    if Application.get_env(:dialectic, :sync_tasks_for_testing, false) do
      record(attrs)
    else
      Task.Supervisor.start_child(Dialectic.TaskSupervisor, fn ->
        case insert_log(attrs) do
          {:ok, _log} ->
            :ok

          {:error, changeset} ->
            Logger.warning("Failed to record grid activity: #{inspect(changeset.errors)}")
        end
      end)
    end
  end

  defp insert_log(attrs) do
    actor = Map.get(attrs, :actor) || Map.get(attrs, "actor")

    attrs =
      attrs
      |> Map.drop([:actor, "actor"])
      |> Map.put_new(:actor_name, actor_name(actor))
      |> Map.put_new(:user_id, actor_id(actor))

    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  defp graph_created_attrs(graph_title, actor) do
    %{
      graph_title: graph_title,
      actor: actor,
      action: "graph.created",
      message: "#{actor_name(actor)} created this grid."
    }
  end

  defp node_created_attrs(graph_title, actor, message, node_id) do
    %{
      graph_title: graph_title,
      actor: actor,
      action: "node.created",
      message: message,
      node_id: node_id
    }
  end

  defp node_deleted_attrs(graph_title, actor, node_id) do
    %{
      graph_title: graph_title,
      actor: actor,
      action: "node.deleted",
      message: "#{actor_name(actor)} deleted a node.",
      node_id: node_id
    }
  end

  defp actor_id(%User{id: id}), do: id
  defp actor_id(_), do: nil

  def actor_name(%User{} = user), do: User.display_name(user)
  def actor_name(name) when is_binary(name) and name != "", do: name
  def actor_name(_), do: "Someone"
end
