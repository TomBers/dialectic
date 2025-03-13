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

    # Start with the flowchart declaration
    parts = ["flowchart #{direction}"]

    # Process nodes
    vertices = :digraph.vertices(graph)

    # Add node definitions
    node_defs =
      for v <- vertices do
        {id, attrs} = :digraph.vertex(graph, v)
        node_id = format_node_id(id)
        content = Map.get(attrs, :content) || Map.get(attrs, "content", "Node #{id}")

        # Escape quotes in content and limit length if needed
        safe_content =
          if String.length(content) > 50 do
            content_part = String.slice(content, 0, 47) <> "..."
            escape_mermaid_text(content_part)
          else
            escape_mermaid_text(content)
          end

        "    #{node_id}[\"#{safe_content}\"]"
      end

    parts = parts ++ node_defs

    # Process edges
    edge_defs =
      for e <- :digraph.edges(graph) do
        {_, v1, v2, _} = :digraph.edge(graph, e)
        {source_id, _} = :digraph.vertex(graph, v1)
        {target_id, _} = :digraph.vertex(graph, v2)

        "    #{format_node_id(source_id)} --> #{format_node_id(target_id)}"
      end

    parts = parts ++ edge_defs

    # Add class definitions
    class_defs = [
      "    classDef user fill:#d4effc,stroke:#3498db,color:#333",
      "    classDef answer fill:#d5f5e3,stroke:#2ecc71,color:#333",
      "    classDef thesis fill:#e8daef,stroke:#9b59b6,color:#333",
      "    classDef antithesis fill:#fadbd8,stroke:#e74c3c,color:#333",
      "    classDef default fill:#f5f5f5,stroke:#95a5a6,color:#333"
    ]

    parts = parts ++ class_defs

    # Assign classes to nodes
    class_assignments =
      for v <- vertices do
        {id, attrs} = :digraph.vertex(graph, v)
        node_id = format_node_id(id)
        class_name = Map.get(attrs, :class) || Map.get(attrs, "class", "default")

        "    class #{node_id} #{class_name}"
      end

    parts = parts ++ class_assignments

    # Join all parts with newlines
    Enum.join(parts, "\n")
  end

  # Format IDs to be safe for Mermaid
  defp format_node_id(id) when is_binary(id), do: id
  defp format_node_id(id), do: to_string(id)

  # Escape text for Mermaid syntax
  defp escape_mermaid_text(text) when is_binary(text) do
    text
    # Replace double quotes with single quotes
    |> String.replace("\"", "'")
  end

  defp escape_mermaid_text(other), do: to_string(other)
end
