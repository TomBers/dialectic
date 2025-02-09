defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller
  alias Dialectic.Graph.{Vertex, Serialise}

  def home(conn, _params) do
    graphs = File.ls!("priv/static/graphs") |> Enum.map(&Path.basename(&1, ".json"))
    render(conn, :home, graphs: graphs, layout: false)
  end

  def create(conn, %{"conversation" => conversation}) do
    Serialise.save_new_graph(conversation)

    conn
    # |> put_flash(:info, "Conversation processed successfully!")
    # Update this path to match your routes
    |> redirect(to: ~p"/#{conversation}")
  end

  def graph(conn, %{"graph_name" => graph_name}) do
    graph = Serialise.load_graph_as_json(graph_name)
    json(conn, graph)
  end

  def what(conn, _params) do
    r = [
      %{
        graph: "reply",
        title: "Respond",
        description: "Add a response to any node",
        url: "/reply?node=2"
      },
      %{
        graph: "answer",
        title: "Answer",
        description: "The system will respond to the node",
        url: "/answer?node=3"
      },
      %{
        graph: "branch",
        title: "Branch",
        description: "Create a thesis / antithesis (for / against) argument for a node",
        url: "/branch?node=1"
      },
      %{
        graph: "combine",
        title: "Combine",
        description: "Create a synthesis from 2 nodes",
        url: "/combine?node=4"
      }
    ]

    graphs = r |> Enum.map(fn g -> %{g | graph: encode_graph(g.graph)} end)
    render(conn, :what, instructions: graphs, layout: false)
  end

  defp encode_graph(n) do
    Serialise.load_graph(n) |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end
end
