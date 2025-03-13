defmodule DialecticWeb.LinearGraphLive do
  use DialecticWeb, :live_view
  alias DialecticWeb.MermaidComp

  @impl true
  def mount(%{"graph_name" => graph_id_uri}, _session, socket) do
    graph_id = URI.decode(graph_id_uri)
    {_graph_struct, graph} = GraphManager.get_graph(graph_id)
    # Load the graph data
    graph_data = load_graph_data(graph)

    {:ok,
     assign(socket,
       graph_data: graph_data,
       graph: graph,
       page_title: "Graph Visualization",
       selected_node: nil,
       show_fullscreen: false
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="graph-container fullscreen">
        <.live_component
          module={DialecticWeb.MermaidComp}
          id="main-graph"
          graph={@graph_data}
          selected_node={@selected_node}
        />
      </div>

      <div class="graph-info">
        <h2>Graph Information</h2>

        <div class="node-types">
          <h3>Node Types</h3>
          <div class="node-type-legend">
            <div class="legend-item">
              <div class="color-box user-color"></div>
              <span>User</span>
            </div>
            <div class="legend-item">
              <div class="color-box answer-color"></div>
              <span>Answer</span>
            </div>
            <div class="legend-item">
              <div class="color-box thesis-color"></div>
              <span>Thesis</span>
            </div>
            <div class="legend-item">
              <div class="color-box antithesis-color"></div>
              <span>Antithesis</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:node_selected, node}, socket) do
    # Update the selected node
    {:noreply, assign(socket, selected_node: node)}
  end

  # Load the graph data from your Erlang digraph or JSON
  defp load_graph_data(graph) do
    # For demonstration purposes, we're loading from a JSON file
    # In your actual implementation, you'd convert from your Erlang digraph
    # using the GraphViz.MermaidConverter.to_mermaid/2 function

    # Example if loading from JSON file:

    Dialectic.Converters.Mermaid.to_mermaid(graph)
  end

  # Example function to convert Erlang digraph to JSON format
  # This would be where you'd convert your existing :digraph to the format needed
  defp digraph_to_json(graph) do
    vertices = :digraph.vertices(graph)
    edges = :digraph.edges(graph)

    nodes =
      Enum.map(vertices, fn v ->
        {_, id, attrs} = :digraph.vertex(graph, v)

        # Convert atom keys to strings for JSON
        attrs =
          Map.new(attrs, fn
            {k, v} when is_atom(k) -> {Atom.to_string(k), v}
            entry -> entry
          end)

        # Ensure id is a string
        Map.put(attrs, "id", to_string(id))
      end)

    json_edges =
      Enum.map(edges, fn e ->
        {_, v1, v2, _} = :digraph.edge(graph, e)

        {_, source_id, _} = :digraph.vertex(graph, v1)
        {_, target_id, _} = :digraph.vertex(graph, v2)

        %{
          "data" => %{
            "id" => "e#{to_string(e)}",
            "source" => to_string(source_id),
            "target" => to_string(target_id)
          }
        }
      end)

    %{
      "nodes" => nodes,
      "edges" => json_edges
    }
  end
end
