defmodule Dialectic.Responses.GuidedLearningTarget do
  @moduledoc false

  @non_answers ["question", "origin", "user", "learning_plan"]

  def select(node, lookup) do
    target = nearest_answer([node], lookup, MapSet.new(), 64) || node
    selection = if node.class == "question", do: Map.get(node, :source_text)

    content =
      if is_binary(selection) and String.trim(selection) != "",
        do: selection,
        else: target.content

    %{
      node_id: target.id,
      title:
        if(content != target.content,
          do: "Selected passage from: #{title(target.content)}",
          else: title(target.content)
        ),
      content: content,
      source_hash: fingerprint(target.content)
    }
  end

  def normalize(target) when is_map(target) do
    values =
      Map.new(
        [:node_id, :title, :content, :source_hash],
        &{&1, Map.get(target, &1, Map.get(target, Atom.to_string(&1)))}
      )

    if Enum.all?(values, fn {_key, value} -> is_binary(value) and String.trim(value) != "" end) and
         Regex.match?(~r/\A[0-9a-f]{64}\z/, values.source_hash) do
      {:ok, values}
    else
      {:error, :invalid_target}
    end
  end

  def normalize(_target), do: {:error, :invalid_target}

  def resolve(target, lookup) do
    with {:ok, target} <- normalize(target),
         %{} = node <- lookup.(target.node_id),
         true <- node.id == target.node_id,
         false <- Map.get(node, :deleted, false),
         true <- fingerprint(node.content) == target.source_hash do
      {:ok, Map.put(node, :content, target.content)}
    else
      _ -> {:error, :target_changed}
    end
  end

  defp nearest_answer([], _lookup, _visited, _remaining), do: nil
  defp nearest_answer(_nodes, _lookup, _visited, 0), do: nil

  defp nearest_answer([node | rest], lookup, visited, remaining) do
    node = if is_map(node), do: node, else: lookup.(node)

    cond do
      !is_map(node) ->
        nearest_answer(rest, lookup, visited, remaining - 1)

      MapSet.member?(visited, node.id) ->
        nearest_answer(rest, lookup, visited, remaining - 1)

      Map.get(node, :deleted, false) ->
        nearest_answer(rest, lookup, visited, remaining - 1)

      node.class not in @non_answers and String.trim(node.content || "") != "" ->
        node

      true ->
        parents =
          Enum.map(Map.get(node, :parents, []), fn parent ->
            lookup.(if is_map(parent), do: parent.id, else: parent)
          end)

        nearest_answer(rest ++ parents, lookup, MapSet.put(visited, node.id), remaining - 1)
    end
  end

  defp title(content) do
    content
    |> String.split("\n", trim: true)
    |> List.first("")
    |> String.trim_leading("#")
    |> String.trim()
    |> String.slice(0, 140)
  end

  defp fingerprint(content),
    do: :crypto.hash(:sha256, content || "") |> Base.encode16(case: :lower)
end
