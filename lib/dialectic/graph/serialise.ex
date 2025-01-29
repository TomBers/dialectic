defmodule Dialectic.Graph.Serialise do
  alias Dialectic.Graph.Vertex

  def save_graph(graph) do
    json = graph_to_json(graph)
    File.write!("graph.json", Jason.encode!(json))
  end

  def load_graph(file_path \\ "graph.json") do
    # json = File.read!("graph.json")
    case File.read(file_path) do
      {:ok, json} -> json |> Jason.decode!() |> json_to_graph()
      {:error, _} -> :digraph.new()
    end
  end

  def graph_to_json(graph) do
    # Get all vertices and edges from the digraph
    vertices = :digraph.vertices(graph)
    # IO.inspect(vertices, label: "Vertices")
    edges = :digraph.edges(graph)

    # Convert vertices to cytoscape nodes format
    nodes =
      Enum.map(vertices, fn vertex ->
        # Get the vertex label/data from the digraph
        {_vertex_data, data} = :digraph.vertex(graph, vertex)

        Vertex.serialize(data)
      end)

    # Convert edges to cytoscape edges format
    edges =
      Enum.map(edges, fn edge ->
        {_, v1, v2, _} = :digraph.edge(graph, edge)

        # Get vertex data for source and target
        {source_data, _} = :digraph.vertex(graph, v1)
        {target_data, _} = :digraph.vertex(graph, v2)

        # Create edge ID from source and target names
        edge_id = source_data <> target_data

        # Create cytoscape edge format
        %{
          data: %{
            id: edge_id,
            source: source_data,
            target: target_data
          }
        }
      end)

    # Combine nodes and edges into final format
    %{nodes: nodes, edges: edges}
  end

  def json_to_graph(json) do
    graph = :digraph.new()

    # Add nodes to the graph
    Enum.each(Map.get(json, "nodes"), fn node ->
      :digraph.add_vertex(graph, Map.get(node, "id"), Vertex.deserialize(node))
    end)

    # Add edges to the graph
    Enum.each(Map.get(json, "edges"), fn edge ->
      dat = Map.get(edge, "data")
      source = Map.get(dat, "source")
      target = Map.get(dat, "target")
      :digraph.add_edge(graph, source, target)
    end)

    graph
  end
end
