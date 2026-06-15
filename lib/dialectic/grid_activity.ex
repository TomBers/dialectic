defmodule Dialectic.GridActivity do
  import Ecto.Query

  require Logger

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.GridActivity.{Actions, Log}
  alias Dialectic.Repo

  @default_limit 25
  @default_summary_limit 100

  def valid_actions, do: Actions.valid_actions()

  def list_for_graph(graph_title, opts \\ []) when is_binary(graph_title) do
    limit = Keyword.get(opts, :limit, @default_limit)
    since = Keyword.get(opts, :since)

    Log
    |> where([log], log.graph_title == ^graph_title)
    |> maybe_since(since)
    |> order_by([log], desc: log.inserted_at, desc: log.id)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_for_graphs(graph_titles, opts \\ []) when is_list(graph_titles) do
    limit = Keyword.get(opts, :limit, @default_summary_limit)
    since = Keyword.get(opts, :since)

    Log
    |> where([log], log.graph_title in ^graph_titles)
    |> maybe_since(since)
    |> order_by([log], desc: log.inserted_at, desc: log.id)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_for_owned_graphs(owner, since, opts \\ []) do
    owner_id = user_id(owner)
    actions = Keyword.get(opts, :actions)

    Log
    |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
    |> where([_log, graph], graph.user_id == ^owner_id)
    |> maybe_since(since)
    |> maybe_actions(actions)
    |> select([log, _graph], count(log.id))
    |> Repo.one()
  end

  def list_for_owned_graphs(owner, opts \\ []) do
    owner_id = user_id(owner)
    limit = Keyword.get(opts, :limit, @default_summary_limit)
    since = Keyword.get(opts, :since)
    actions = Keyword.get(opts, :actions)

    Log
    |> join(:inner, [log], graph in Graph, on: graph.title == log.graph_title)
    |> where([_log, graph], graph.user_id == ^owner_id)
    |> maybe_since(since)
    |> maybe_actions(actions)
    |> order_by([log, _graph], desc: log.inserted_at, desc: log.id)
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

  def record_node_event(graph_title, actor, action, node_or_id \\ nil, metadata \\ %{})
      when is_binary(graph_title) and is_binary(action) and is_map(metadata) do
    graph_title
    |> node_event_attrs(actor, action, node_or_id, metadata)
    |> record()
  end

  def record_node_event_async(graph_title, actor, action, node_or_id \\ nil, metadata \\ %{})
      when is_binary(graph_title) and is_binary(action) and is_map(metadata) do
    graph_title
    |> node_event_attrs(actor, action, node_or_id, metadata)
    |> record_async()
  end

  def record_node_comment_created(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event(graph_title, actor, Actions.node_comment_created(), node_or_id, metadata)
  end

  def record_node_comment_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_comment_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_follow_up_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_follow_up_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_branch_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_branch_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_synthesis_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_synthesis_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_related_ideas_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_related_ideas_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_selection_explained_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_selection_explained(),
      node_or_id,
      metadata
    )
  end

  def record_node_selection_question_created_async(
        graph_title,
        actor,
        node_or_id,
        metadata \\ %{}
      ) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_selection_question_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_deep_dive_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_deep_dive_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_starting_point_created_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(
      graph_title,
      actor,
      Actions.node_starting_point_created(),
      node_or_id,
      metadata
    )
  end

  def record_node_regenerated_async(graph_title, actor, node_or_id, metadata \\ %{}) do
    record_node_event_async(graph_title, actor, Actions.node_regenerated(), node_or_id, metadata)
  end

  def record_node_deleted(graph_title, actor, node_or_id \\ nil, metadata \\ %{}) do
    record_node_event(graph_title, actor, Actions.node_deleted(), node_or_id, metadata)
  end

  def record_node_deleted_async(graph_title, actor, node_or_id \\ nil, metadata \\ %{}) do
    record_node_event_async(graph_title, actor, Actions.node_deleted(), node_or_id, metadata)
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

  def display_message(%Log{} = log), do: display_message(log.action, log.actor_name)

  def display_message(%{action: action, actor_name: actor_name}),
    do: display_message(action, actor_name)

  def display_message(action, actor_name) when is_binary(action) do
    actor = actor_name(actor_name)

    case action do
      "graph.created" -> "#{actor} created this grid."
      "node.comment.created" -> "#{actor} added a comment."
      "node.follow_up.created" -> "#{actor} asked a follow-up question."
      "node.branch.created" -> "#{actor} branched from a node."
      "node.synthesis.created" -> "#{actor} added a synthesis."
      "node.related_ideas.created" -> "#{actor} added related ideas."
      "node.selection_explained" -> "#{actor} asked about selected text."
      "node.selection_question.created" -> "#{actor} asked a question about selected text."
      "node.deep_dive.created" -> "#{actor} added a deep dive."
      "node.critical_tool.created" -> "#{actor} used a critical thinking tool."
      "node.starting_point.created" -> "#{actor} added a new starting point."
      "node.regenerated" -> "#{actor} regenerated a node."
      "node.deleted" -> "#{actor} deleted a node."
      _ -> "#{actor} updated this grid."
    end
  end

  def display_message(_action, actor_name), do: "#{actor_name(actor_name)} updated this grid."

  defp insert_log(attrs) do
    actor = Map.get(attrs, :actor) || Map.get(attrs, "actor")

    attrs =
      attrs
      |> Map.drop([:actor, "actor"])
      |> Map.put_new(:actor_name, actor_name(actor))
      |> Map.put_new(:actor_user_id, user_id(actor))
      |> Map.update(:metadata, %{}, &stringify_metadata/1)

    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  defp graph_created_attrs(graph_title, actor) do
    %{
      graph_title: graph_title,
      actor: actor,
      action: Actions.graph_created(),
      metadata: %{"graph_title" => graph_title}
    }
  end

  defp node_event_attrs(graph_title, actor, action, node_or_id, metadata) do
    node_metadata = node_metadata(node_or_id)

    %{
      graph_title: graph_title,
      actor: actor,
      action: action,
      node_id: node_id(node_or_id),
      metadata: Map.merge(node_metadata, stringify_metadata(metadata))
    }
  end

  defp maybe_since(query, nil), do: query

  defp maybe_since(query, since) do
    where(query, [log], log.inserted_at >= ^since)
  end

  defp maybe_actions(query, nil), do: query
  defp maybe_actions(query, []), do: query

  defp maybe_actions(query, actions) when is_list(actions) do
    where(query, [log], log.action in ^actions)
  end

  defp maybe_actions(query, action) when is_binary(action) do
    where(query, [log], log.action == ^action)
  end

  defp node_metadata(node) when is_map(node) do
    content = node |> attr(:content) |> to_string()
    parents = attr(node, :parents) || []

    %{
      "node_class" => attr(node, :class),
      "node_title" => title_from_content(content),
      "content_snippet" => content_snippet(content),
      "parent_node_ids" => parent_node_ids(parents),
      "parent_node_titles" => parent_node_titles(parents)
    }
    |> reject_empty_values()
  end

  defp node_metadata(_node_or_id), do: %{}

  defp node_id(node) when is_map(node), do: attr(node, :id)
  defp node_id(node_id) when is_binary(node_id) and node_id != "", do: node_id
  defp node_id(_), do: nil

  defp parent_node_ids(parents) when is_list(parents) do
    parents
    |> Enum.map(&node_id/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parent_node_ids(_parents), do: []

  defp parent_node_titles(parents) when is_list(parents) do
    parents
    |> Enum.map(fn parent ->
      parent
      |> attr(:content)
      |> to_string()
      |> title_from_content()
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parent_node_titles(_parents), do: []

  defp attr(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp title_from_content(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.split("\n", parts: 2)
    |> List.first()
    |> to_string()
    |> String.replace(~r/^#+\s*/, "")
    |> String.trim()
    |> truncate(120)
    |> blank_to_nil()
  end

  defp title_from_content(_content), do: nil

  defp content_snippet(content) when is_binary(content) do
    content
    |> String.trim()
    |> truncate(240)
    |> blank_to_nil()
  end

  defp content_snippet(_content), do: nil

  defp truncate(nil, _max_length), do: nil

  defp truncate(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - 1) <> "…"
    else
      text
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp stringify_metadata(metadata) when is_map(metadata) do
    Map.new(metadata, fn {key, value} -> {to_string(key), stringify_metadata_value(value)} end)
  end

  defp stringify_metadata(_metadata), do: %{}

  defp stringify_metadata_value(value) when is_map(value), do: stringify_metadata(value)
  defp stringify_metadata_value(value) when is_boolean(value), do: value
  defp stringify_metadata_value(nil), do: nil
  defp stringify_metadata_value(value) when is_atom(value), do: Atom.to_string(value)

  defp stringify_metadata_value(value) when is_list(value) do
    Enum.map(value, &stringify_metadata_value/1)
  end

  defp stringify_metadata_value(value), do: value

  defp reject_empty_values(metadata) do
    Map.reject(metadata, fn {_key, value} -> value in [nil, "", []] end)
  end

  defp user_id(%User{id: id}), do: id
  defp user_id(id) when is_integer(id), do: id
  defp user_id(_), do: nil

  def actor_name(%User{} = user), do: User.display_name(user)

  def actor_name(name) when is_binary(name) do
    case String.trim(name) do
      "" -> "Someone"
      trimmed -> trimmed
    end
  end

  def actor_name(_), do: "Someone"
end
