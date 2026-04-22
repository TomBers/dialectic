defmodule Dialectic.Graph.Extractor do
  @moduledoc """
  Extracts graphs from the database into a concise format suitable for image generation.
  Keeps only essential information: node content, types, and relationships.

  ## Usage Examples

  ### Extract a graph by title or slug

      # By title
      {:ok, data} = Extractor.extract_for_image_generation("My Graph Title")

      # By slug
      {:ok, data} = Extractor.extract_for_image_generation("my-graph-title-abc123")

      # With a Graph struct
      graph = Dialectic.DbActions.Graphs.get_graph_by_title("My Graph")
      data = Extractor.extract_for_image_generation(graph)

  ### Extract to JSON format

      # Pretty-printed JSON (good for debugging)
      {:ok, json} = Extractor.extract_to_json("My Graph Title")
      IO.puts(json)

      # Compact JSON (good for API responses)
      {:ok, compact_json} = Extractor.extract_to_compact_json("My Graph Title")

  ## Output Format

  The extracted data contains:
  - `nodes`: List of nodes with only essential fields (id, content, class, parent if grouped, compound if group)
  - `edges`: List of edges with from/to relationships

  Example output:

      %{
        nodes: [
          %{id: "1", content: "Root question", class: "question"},
          %{id: "2", content: "First answer", class: "answer"},
          %{id: "group-1", content: "", class: "", compound: true},
          %{id: "3", content: "Grouped node", class: "thesis", parent: "group-1"}
        ],
        edges: [
          %{from: "1", to: "2"},
          %{from: "2", to: "3"}
        ]
      }

  ## What gets filtered out

  - Deleted nodes (where `deleted: true`)
  - User information
  - Note metadata (`noted_by`)
  - Timestamps
  - Source text references
  - Edges pointing to deleted or non-existent nodes
  """

  alias Dialectic.Accounts.Graph

  @doc """
  Extracts a graph from the database into a minimal format for image generation.

  Returns a map with:
  - nodes: list of %{id, content, class, parent (optional)}
  - edges: list of %{from, to}

  Filters out:
  - Deleted nodes
  - User information
  - Timestamps
  - Internal metadata

  ## Examples

      iex> graph = Dialectic.DbActions.Graphs.get_graph_by_title("My Graph")
      iex> Extractor.extract_for_image_generation(graph)
      %{
        nodes: [
          %{id: "1", content: "Root question", class: "origin"},
          %{id: "2", content: "First answer", class: "answer", parent: "group-1"}
        ],
        edges: [
          %{from: "1", to: "2"}
        ]
      }
  """
  def extract_for_image_generation(%Graph{data: data}) do
    nodes = extract_nodes(data)
    edges = extract_edges(data, nodes)

    %{
      nodes: nodes,
      edges: edges
    }
  end

  def extract_for_image_generation(identifier) when is_binary(identifier) do
    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(identifier) do
      nil -> {:error, :not_found}
      graph -> {:ok, extract_for_image_generation(graph)}
    end
  end

  @doc """
  Extracts to JSON string format, ready for passing to external tools.
  """
  def extract_to_json(%Graph{} = graph) do
    graph
    |> extract_for_image_generation()
    |> Jason.encode!(pretty: true)
  end

  def extract_to_json(identifier) when is_binary(identifier) do
    case extract_for_image_generation(identifier) do
      {:ok, data} -> {:ok, Jason.encode!(data, pretty: true)}
      error -> error
    end
  end

  @doc """
  Extracts to a compact single-line JSON format.
  """
  def extract_to_compact_json(%Graph{} = graph) do
    graph
    |> extract_for_image_generation()
    |> Jason.encode!()
  end

  def extract_to_compact_json(identifier) when is_binary(identifier) do
    case extract_for_image_generation(identifier) do
      {:ok, data} -> {:ok, Jason.encode!(data)}
      error -> error
    end
  end

  # Private functions

  defp extract_nodes(%{"nodes" => nodes}) when is_list(nodes) do
    nodes
    |> Enum.reject(&is_deleted?/1)
    |> Enum.map(&extract_node_essentials/1)
  end

  defp extract_nodes(_), do: []

  defp extract_edges(%{"edges" => edges}, nodes) when is_list(edges) do
    # Get the set of valid node IDs
    valid_node_ids = MapSet.new(nodes, & &1.id)

    edges
    |> Enum.map(&extract_edge_essentials/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&valid_edge?(&1, valid_node_ids))
  end

  defp extract_edges(_, _), do: []

  defp is_deleted?(%{"deleted" => true}), do: true
  defp is_deleted?(_), do: false

  defp extract_node_essentials(node) do
    base = %{
      id: node["id"],
      content: node["content"],
      class: node["class"]
    }

    # Add parent if it exists and is not nil/empty
    base =
      case node["parent"] do
        nil -> base
        "" -> base
        parent -> Map.put(base, :parent, parent)
      end

    # Mark compound nodes (groups)
    if node["compound"] do
      Map.put(base, :compound, true)
    else
      base
    end
  end

  defp extract_edge_essentials(%{"data" => data}) when is_map(data) do
    with source when not is_nil(source) <- data["source"],
         target when not is_nil(target) <- data["target"] do
      %{
        from: source,
        to: target
      }
    else
      _ -> nil
    end
  end

  defp extract_edge_essentials(_), do: nil

  defp valid_edge?(%{from: from, to: to}, valid_node_ids) do
    MapSet.member?(valid_node_ids, from) && MapSet.member?(valid_node_ids, to)
  end

  defp valid_edge?(_, _), do: false
end
