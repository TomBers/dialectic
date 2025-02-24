defmodule Dialectic.Graph.Siblings do
  alias Dialectic.Graph.Vertex

  def up(node) do
    new_node_or_self(node, fn node -> node.parents |> List.first() end)
  end

  def down(node) do
    new_node_or_self(node, fn node -> node.children |> List.first() end)
  end

  def left(node, graph) do
    sorted = sort_siblings(node, graph)

    {_n, indx} =
      sorted
      |> Enum.with_index()
      |> Enum.find({nil, 1}, fn {n, _} -> n.id == node.id end)

    case indx do
      0 -> List.first(sorted)
      _ -> Enum.at(sorted, indx - 1, List.first(sorted))
    end
  end

  def right(node, graph) do
    sorted = sort_siblings(node, graph)

    {_n, indx} =
      sorted
      |> Enum.with_index()
      |> Enum.find({nil, -1}, fn {n, _} -> n.id == node.id end)

    IO.inspect(indx, label: "Right Indx")
    Enum.at(sorted, indx + 1, List.last(sorted))
  end

  defp new_node_or_self(node, search_fn) do
    case search_fn.(node) do
      nil -> node
      relative -> relative
    end
  end

  def sort_siblings(node, graph) do
    node.parents
    |> Enum.map(fn p -> Vertex.add_relatives(p, graph) end)
    |> Enum.flat_map(fn p -> p.children end)
    |> sort_nodes()
  end

  defp sort_nodes(nodes) do
    Enum.sort(nodes, fn a, b ->
      case {Integer.parse(a.id), Integer.parse(b.id)} do
        # Both are pure numbers
        {{num_a, ""}, {num_b, ""}} ->
          num_a <= num_b

        # Only a is a pure number
        {{_, ""}, _} ->
          true

        # Only b is a pure number
        {_, {_, ""}} ->
          false

        # Neither is a pure number (both are strings or mixed)
        _ ->
          a <= b
      end
    end)
  end
end
