defmodule Dialectic.Linear.ThreadedConv do
  @moduledoc """
  Provides functions to transform an Elixir :digraph structure into a threaded conversation
  with appropriate ordering and indentation levels.
  """
  @doc """
  Processes a digraph and returns a list of tuples containing:
  {node_id, indent_level, node_data}
  The list is ordered to represent a sensible conversation flow, with parent messages
  appearing before their children and appropriate indentation to show the hierarchy.
  ## Parameters
  - `graph`: The :digraph structure representing the conversation
  ## Returns
  List of {node_id, indent_level, node_data} tuples ordered for conversation display
  """
  def process_graph(graph) do
    root_nodes = find_root_nodes(graph)
    nodes_with_indent = []
    visited = MapSet.new()

    # Process each conversation thread starting from each root node
    Enum.reduce(root_nodes, {nodes_with_indent, visited}, fn root, {acc, visited_acc} ->
      process_thread(graph, root, 0, acc, visited_acc)
    end)
    # Return just the nodes list, discard the visited set
    |> elem(0)
  end

  @doc """
  Finds all root nodes in the graph (nodes with no incoming edges).
  These represent the start of conversation threads.
  """
  def find_root_nodes(graph) do
    # Get all vertices in the graph
    all_vertices = :digraph.vertices(graph)
    # Filter to find vertices with no incoming edges
    Enum.filter(all_vertices, fn vertex ->
      :digraph.in_degree(graph, vertex) == 0
    end)
  end

  @doc """
  Recursively processes a conversation thread starting from a given node.
  Adds the node and all its descendants to the accumulator with appropriate indentation.
  ## Parameters
  - `graph`: The :digraph structure
  - `node`: The current node being processed
  - `indent`: The indentation level for the current node
  - `acc`: The accumulator for storing processed nodes
  - `visited`: MapSet tracking already visited nodes to prevent duplicates
  ## Returns
  Tuple of {updated_acc, updated_visited} with the current node and its descendants added
  """
  def process_thread(graph, node, indent, acc, visited) do
    # Skip if node has already been processed
    if MapSet.member?(visited, node) do
      {acc, visited}
    else
      # Get node data from the Dialectic.Graph.Vertex structure
      node_data =
        case :digraph.vertex(graph, node) do
          {^node, %Dialectic.Graph.Vertex{} = vertex} -> vertex
          _ -> nil
        end

      # Add current node to accumulator with its indent level
      updated_acc = [{node, indent, node_data} | acc]
      # Mark node as visited
      updated_visited = MapSet.put(visited, node)

      # Get all child nodes (outgoing edges)
      children = :digraph.out_neighbours(graph, node)

      # Process each child with an increased indent level
      Enum.reduce(children, {updated_acc, updated_visited}, fn child,
                                                               {child_acc, child_visited} ->
        process_thread(graph, child, indent + 1, child_acc, child_visited)
      end)
    end
  end

  @doc """
  Formats the processed nodes into a structure suitable for rendering.
  ## Parameters
  - `processed_nodes`: List of {node_id, indent_level, node_data} tuples
  ## Returns
  List of maps with node data and indent information, in reverse order
  to maintain the conversation flow
  """
  def format_for_rendering(processed_nodes) do
    processed_nodes
    |> Enum.reverse()
    |> Enum.map(fn {node_id, indent, data} ->
      %{
        id: node_id,
        indent: indent,
        content: data && data.content,
        class: (data && data.class) || "default",
        user: data && data.user,
        deleted: data && data.deleted
      }
    end)
  end

  @doc """
  Full pipeline to process a graph and prepare it for rendering.
  ## Parameters
  - `graph`: The :digraph structure representing the conversation
  ## Returns
  List of maps with node data and indent information, ready for rendering
  """
  def prepare_conversation(graph) do
    graph
    |> process_graph()
    |> format_for_rendering()
  end
end
