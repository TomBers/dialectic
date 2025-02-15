defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller

  alias Dialectic.Graph.{Vertex, Serialise}
  alias Dialectic.DbActions.{Notes, Graphs}

  def home(conn, _params) do
    stats = Notes.get_my_stats(conn.assigns.current_user)
    top_graphs = Notes.top_graphs()
    # IO.inspect(stats, label: "Stats")
    render(conn, :home, stats: stats, top_graphs: top_graphs)
  end

  def create(conn, %{"conversation" => conversation}) do
    case Graphs.create_new_graph(conversation, conn.assigns.current_user) do
      {:ok, _} ->
        conn
        |> redirect(to: ~p"/#{conversation}")

      _ ->
        conn |> put_flash(:error, "Graph already exits") |> redirect(to: ~p"/")
    end
  end

  def graph(conn, %{"graph_name" => graph_name}) do
    graph = Graphs.get_graph_by_title(graph_name).data
    json(conn, graph)
  end

  def what(conn, _params) do
    r = [
      %{
        graph: "reply",
        title: "Answer",
        description: "Add a response to any node",
        node: "2"
      },
      %{
        graph: "answer",
        title: "Reply",
        description: "The system will reply to the node",
        node: "3"
      },
      %{
        graph: "branch",
        title: "Branch",
        description: "Create a thesis / antithesis (for / against) argument for a node",
        node: "1"
      },
      %{
        graph: "combine",
        title: "Combine",
        description: "Create a synthesis from 2 nodes",
        node: "4"
      }
    ]

    graphs = r |> Enum.map(fn g -> %{g | graph: encode_graph(g.graph)} end)
    render(conn, :what, instructions: graphs, layout: false)
  end

  defp encode_graph(n) do
    Serialise.load_graph(n) |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end
end
