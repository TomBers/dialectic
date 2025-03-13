defmodule Dialectic.Converters.Mermaid do
  @moduledoc """
  Converts Erlang digraph structures directly to Mermaid.js syntax for visualization
  """

  @doc """
  Converts an Erlang digraph to Mermaid.js flowchart syntax

  ## Parameters

    * `graph` - The Erlang digraph structure
    * `opts` - Optional parameters for customization:
      * `:direction` - Direction of the flowchart (TD, LR, RL, BT), default: "TD"
      * `:node_labels` - Function that takes a vertex and returns a string label
      * `:node_styles` - Function that takes a vertex and returns style instructions

  ## Examples

      iex> graph = :digraph.new()
      iex> v1 = :digraph.add_vertex(graph, "1", %{class: "user", content: "What is freedom?"})
      iex> v2 = :digraph.add_vertex(graph, "2", %{class: "answer", content: "Freedom is..."})
      iex> :digraph.add_edge(graph, v1, v2)
      iex> GraphViz.MermaidConverter.to_mermaid(graph)
      # Returns Mermaid.js flowchart syntax as a string
  """
  def to_mermaid(graph, opts \\ []) do
    direction = Keyword.get(opts, :direction, "TD")
    node_label_fn = Keyword.get(opts, :node_labels, &default_node_label/1)
    node_style_fn = Keyword.get(opts, :node_styles, &default_node_style/1)

    # Start the Mermaid diagram
    header = "flowchart #{direction}\n"

    # Convert vertices to Mermaid node definitions
    vertices = :digraph.vertices(graph)

    nodes =
      vertices
      |> Enum.map(fn v ->
        {id, attrs} = :digraph.vertex(graph, v)

        # Format the node ID (make sure it's a valid Mermaid ID)
        node_id = format_node_id(id)

        # Get the node label using the provided function
        label = node_label_fn.({id, attrs})

        # Create the node definition
        "    #{node_id}([\"#{escape_quotes(label)}\"])"
      end)
      |> Enum.join("\n")

    # Convert edges to Mermaid edge definitions
    edges =
      :digraph.edges(graph)
      |> Enum.map(fn e ->
        {_, v1, v2, _} = :digraph.edge(graph, e)

        {source_id, _} = :digraph.vertex(graph, v1)
        {target_id, _} = :digraph.vertex(graph, v2)

        source_id = format_node_id(source_id)
        target_id = format_node_id(target_id)

        "    #{source_id} --> #{target_id}"
      end)
      |> Enum.join("\n")

    # Add styling for nodes
    styles =
      vertices
      |> Enum.map(fn v ->
        {id, attrs} = :digraph.vertex(graph, v)
        node_id = format_node_id(id)

        style = node_style_fn.({id, attrs})
        if style && style != "", do: "    style #{node_id} #{style}", else: nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    # Add click callbacks if needed
    clicks =
      vertices
      |> Enum.map(fn v ->
        {id, _} = :digraph.vertex(graph, v)
        node_id = format_node_id(id)
        "    click #{node_id} callback"
      end)
      |> Enum.join("\n")

    # Add class definitions
    class_defs = """
    classDef user fill:#d4effc,stroke:#3498db,color:#333
    classDef answer fill:#d5f5e3,stroke:#2ecc71,color:#333
    classDef thesis fill:#e8daef,stroke:#9b59b6,color:#333
    classDef antithesis fill:#fadbd8,stroke:#e74c3c,color:#333
    classDef default fill:#f5f5f5,stroke:#95a5a6,color:#333
    """

    # Find nodes by class for class assignments
    classes =
      vertices
      |> Enum.group_by(fn v ->
        {_, attrs} = :digraph.vertex(graph, v)
        Map.get(attrs, :class) || Map.get(attrs, "class", "default")
      end)
      |> Enum.map(fn {class, nodes} ->
        node_ids =
          Enum.map(nodes, fn n ->
            {id, _} = :digraph.vertex(graph, n)
            format_node_id(id)
          end)
          |> Enum.join(",")

        "class #{node_ids} #{class}"
      end)
      |> Enum.join("\n    ")

    # Combine all sections
    [
      header,
      nodes,
      edges,
      styles,
      clicks,
      class_defs,
      "    #{classes}"
    ]
    |> Enum.reject(fn s -> s == nil || s == "" end)
    |> Enum.join("\n")
  end

  # Helper functions

  # Ensure node IDs are valid for Mermaid (no spaces, special chars, etc.)
  defp format_node_id(id) when is_binary(id), do: id
  defp format_node_id(id), do: to_string(id)

  # Default function for node labels
  defp default_node_label({id, attrs}) do
    class = Map.get(attrs, :class) || Map.get(attrs, "class", "")
    content = Map.get(attrs, :content) || Map.get(attrs, "content", "")

    # Create a short preview of content
    preview =
      if content && byte_size(content) > 0 do
        if byte_size(content) > 30 do
          String.slice(content, 0..27) <> "..."
        else
          content
          "BOB"
        end
      else
        ""
      end

    if class && class != "" do
      "#{class}: #{id}"
    else
      to_string(id)
    end
  end

  # Default function for node styles
  defp default_node_style({_id, attrs}) do
    class = Map.get(attrs, :class) || Map.get(attrs, "class")

    case class do
      "user" -> "fill:#d4effc,stroke:#3498db,color:#333"
      "answer" -> "fill:#d5f5e3,stroke:#2ecc71,color:#333"
      "thesis" -> "fill:#e8daef,stroke:#9b59b6,color:#333"
      "antithesis" -> "fill:#fadbd8,stroke:#e74c3c,color:#333"
      _ -> "fill:#f5f5f5,stroke:#95a5a6,color:#333"
    end
  end

  # Escape quotes in strings for Mermaid labels
  defp escape_quotes(str) when is_binary(str) do
    String.replace(str, "\"", "\\\"")
  end

  defp escape_quotes(other), do: to_string(other)

  @doc """
  Converts a JSON representation of a graph to Mermaid.js syntax

  ## Parameters

    * `json_data` - The JSON string or decoded map representation of the graph
    * `opts` - Same options as to_mermaid/2
  """
  def json_to_mermaid(json_data, opts \\ []) when is_binary(json_data) do
    json_data
    |> Jason.decode!()
    |> json_to_mermaid(opts)
  end

  def json_to_mermaid(json_map, opts) when is_map(json_map) do
    direction = Keyword.get(opts, :direction, "TD")

    # Parse nodes and edges from the JSON structure
    nodes = json_map["nodes"] || []
    edges = json_map["edges"] || []

    # Start the Mermaid diagram
    header = "flowchart #{direction}\n"

    # Convert nodes to Mermaid syntax
    node_defs =
      nodes
      |> Enum.map(fn node ->
        id = node["id"]
        class = node["class"] || "default"
        label = "#{class}: #{id}"

        # Format the node definition
        "    #{id}([\"#{escape_quotes(label)}\"])"
      end)
      |> Enum.join("\n")

    # Convert edges to Mermaid syntax
    edge_defs =
      edges
      |> Enum.map(fn edge ->
        source = edge["data"]["source"]
        target = edge["data"]["target"]

        "    #{source} --> #{target}"
      end)
      |> Enum.join("\n")

    # Add styling based on node classes
    node_styles =
      nodes
      |> Enum.map(fn node ->
        id = node["id"]
        class = node["class"] || "default"

        style =
          case class do
            "user" -> "fill:#d4effc,stroke:#3498db,color:#333"
            "answer" -> "fill:#d5f5e3,stroke:#2ecc71,color:#333"
            "thesis" -> "fill:#e8daef,stroke:#9b59b6,color:#333"
            "antithesis" -> "fill:#fadbd8,stroke:#e74c3c,color:#333"
            _ -> "fill:#f5f5f5,stroke:#95a5a6,color:#333"
          end

        "    style #{id} #{style}"
      end)
      |> Enum.join("\n")

    # Add class definitions
    class_defs = """
    classDef user fill:#d4effc,stroke:#3498db,color:#333
    classDef answer fill:#d5f5e3,stroke:#2ecc71,color:#333
    classDef thesis fill:#e8daef,stroke:#9b59b6,color:#333
    classDef antithesis fill:#fadbd8,stroke:#e74c3c,color:#333
    classDef default fill:#f5f5f5,stroke:#95a5a6,color:#333
    """

    # Group nodes by class
    class_assignments =
      nodes
      |> Enum.group_by(fn node -> node["class"] || "default" end)
      |> Enum.map(fn {class, nodes} ->
        node_ids = Enum.map(nodes, fn n -> n["id"] end) |> Enum.join(",")
        "class #{node_ids} #{class}"
      end)
      |> Enum.join("\n    ")

    # Combine all sections
    [
      header,
      node_defs,
      edge_defs,
      node_styles,
      class_defs,
      "    #{class_assignments}"
    ]
    |> Enum.reject(fn s -> s == nil || s == "" end)
    |> Enum.join("\n")
  end
end
