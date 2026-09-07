defmodule Dialectic.QuestionPages.Source do
  alias Dialectic.LLM.Grounding

  def hash(graph),
    do:
      :crypto.hash(:sha256, :erlang.term_to_binary(graph.data, [:deterministic]))
      |> Base.encode16(case: :lower)

  def nodes(graph) do
    (graph.data["nodes"] || [])
    |> Enum.filter(fn node ->
      is_binary(node["id"]) and node["deleted"] != true and node["compound"] != true and
        node["class"] != "learning_plan" and is_binary(node["content"]) and
        String.trim(node["content"]) != ""
    end)
    |> Enum.map(fn node ->
      %{
        "id" => node["id"],
        "title" =>
          node["content"]
          |> String.split("\n", parts: 2)
          |> hd()
          |> String.trim_leading("#")
          |> String.trim()
          |> String.slice(0, 160),
        "content" => node["content"],
        "class" => node["class"],
        "sources" =>
          Grounding.sources(node["grounding_metadata"])
          |> Enum.with_index(1)
          |> Enum.map(fn {source, index} ->
            %{"id" => to_string(index), "url" => source.url, "title" => source.title}
          end)
      }
    end)
  end

  def capture(graph, selection) do
    answer = selection["answer"]
    evidence = selection["evidence"] || []
    paths = selection["paths"] || []
    nodes = nodes(graph)

    if is_binary(answer) and is_list(evidence) and is_list(paths) and
         length(evidence) in 1..3 and length(paths) in 1..3 and
         length(Enum.uniq(evidence)) == length(evidence) and
         length(Enum.uniq(paths)) == length(paths) and
         Enum.all?([answer | evidence ++ paths], fn id -> Enum.any?(nodes, &(&1["id"] == id)) end) do
      selected = Enum.filter(nodes, &(&1["id"] in [answer | evidence ++ paths]))

      if Enum.sum(Enum.map(selected, &String.length(&1["content"]))) <= 60_000 do
        {:ok,
         %{
           "hash" => hash(graph),
           "revision" => graph.data_revision,
           "graph_title" => graph.title,
           "selection" => %{"answer" => answer, "evidence" => evidence, "paths" => paths},
           "nodes" => selected
         }}
      else
        {:error, :selection_too_large}
      end
    else
      {:error, :invalid_selection}
    end
  end

  def validate_references(content, source) do
    valid? =
      Enum.all?([:evidence, :paths], fn role ->
        sections = Map.fetch!(content, role)
        expected = source["selection"][Atom.to_string(role)]

        Enum.sort(Enum.map(sections, & &1.node_id)) == Enum.sort(expected) and
          Enum.all?(sections, fn section ->
            node = Enum.find(source["nodes"], &(&1["id"] == section.node_id))

            node &&
              Enum.all?(section.source_ids, fn id ->
                Enum.any?(node["sources"], &(&1["id"] == id))
              end)
          end)
      end)

    if valid?, do: :ok, else: {:error, :invalid_references}
  end
end
