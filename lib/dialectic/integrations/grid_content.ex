defmodule Dialectic.Integrations.GridContent do
  import Ecto.Query
  alias Dialectic.Integrations.{GridAction, GridSnapshot}
  alias Dialectic.Repo

  def serialize(data, title, revision \\ nil) do
    data = Jason.decode!(Jason.encode!(data))
    operations = Repo.all(from operation in GridAction, where: operation.graph_title == ^title)

    statuses =
      Map.new(operations, fn operation ->
        status =
          cond do
            operation.completed_revision && revision && operation.completed_revision <= revision ->
              "completed"

            operation.completed_revision && revision ->
              "queued"

            true ->
              operation.status
          end

        {operation.answer_node_id || operation.node_id, status}
      end)

    statuses =
      if is_nil(revision),
        do: Map.merge(statuses, Dialectic.Responses.RequestQueue.active_node_statuses(title)),
        else: statuses

    nodes = Enum.reject(data["nodes"] || [], &(&1["deleted"] == true))
    ids = MapSet.new(nodes, & &1["id"])

    edges =
      Enum.flat_map(data["edges"] || [], fn
        %{"data" => %{"source" => source, "target" => target}} ->
          if MapSet.member?(ids, source) and MapSet.member?(ids, target),
            do: [%{from: source, to: target}],
            else: []

        _ ->
          []
      end)
      |> Enum.uniq()
      |> Enum.sort_by(&{&1.from, &1.to})

    parents_by_node = Enum.group_by(edges, & &1.to, & &1.from)

    nodes =
      Enum.map(nodes, fn node ->
        status = statuses[node["id"]]
        node(node, Map.get(parents_by_node, node["id"], []), status)
      end)
      |> Enum.sort_by(&sort_id(&1.id))

    %{nodes: nodes, edges: edges}
  end

  def node(raw, parents, status) do
    parents = Enum.sort(parents)

    raw =
      if is_struct(raw, Dialectic.Graph.Vertex),
        do: Dialectic.Graph.Vertex.serialize(raw),
        else: raw

    raw = Jason.decode!(Jason.encode!(raw))
    content = raw["content"] || ""

    base = %{
      id: raw["id"],
      content: content,
      content_hash: content_hash(content),
      class: raw["class"] || "",
      parent_node_id: List.first(parents),
      parent_node_ids: parents,
      sources: Dialectic.LLM.Grounding.sources(raw["grounding_metadata"]),
      generation_status: status,
      content_status: content_status(content, status)
    }

    base =
      case Dialectic.Responses.GuidedLearningPlan.normalize(raw["guided_plan"]) do
        {:ok, plan} -> Map.put(base, :learning_plan, plan)
        _ -> base
      end

    base =
      if is_map(raw["source_reference"]),
        do:
          Map.put(
            base,
            :source_reference,
            Map.put(raw["source_reference"], "text", raw["source_text"])
          ),
        else: base

    base = if raw["parent"] in [nil, ""], do: base, else: Map.put(base, :parent, raw["parent"])
    if raw["compound"], do: Map.put(base, :compound, true), else: base
  end

  def content_hash(content),
    do: :crypto.hash(:sha256, content || "") |> Base.encode16(case: :lower)

  def at_revision(graph, nil), do: {:ok, graph.data, graph.data_revision}

  def at_revision(graph, revision) when revision == graph.data_revision,
    do: {:ok, graph.data, revision}

  def at_revision(graph, revision) do
    case Repo.get_by(GridSnapshot, graph_title: graph.title, revision: revision) do
      nil -> {:error, :stale_snapshot}
      snapshot -> {:ok, snapshot.data, snapshot.revision}
    end
  end

  def content_status(content, status) do
    cond do
      status == "failed" -> "failed"
      status == "unknown" -> "unknown"
      status in ["queued", "generating"] and String.trim(content) == "" -> "placeholder"
      status in ["queued", "generating"] -> "partial"
      status == "completed" and String.trim(content) == "" -> "completed_empty"
      String.trim(content) == "" -> "empty"
      true -> "complete"
    end
  end

  defp sort_id(id) do
    case Integer.parse(id) do
      {number, ""} -> {0, number, id}
      _ -> {1, 0, id}
    end
  end
end
