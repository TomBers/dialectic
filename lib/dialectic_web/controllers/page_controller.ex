defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller
  alias Dialectic.Graph.{Vertex, Serialise}

  def home(conn, _params) do
    stats = Dialectic.DbActions.Notes.get_my_stats(conn.assigns.current_user)
    top_graphs = Dialectic.DbActions.Notes.top_graphs()
    # IO.inspect(stats, label: "Stats")
    render(conn, :home, stats: stats, top_graphs: top_graphs, layout: false)
  end

  def create(conn, %{"conversation" => conversation}) do
    Dialectic.DbActions.Graphs.create_new_graph(conversation, conn.assigns.current_user)

    conn
    # |> put_flash(:info, "Conversation processed successfully!")
    # Update this path to match your routes
    |> redirect(to: ~p"/#{conversation}")
  end

  def graph(conn, %{"graph_name" => graph_name}) do
    graph = Dialectic.DbActions.Graphs.get_graph_by_title(graph_name).data
    json(conn, graph)
  end

  def what(conn, _params) do
    r = [
      %{
        graph: "reply",
        title: "Answer",
        description: "Add a response to any node",
        url: "/reply?node=2",
        node: "2"
      },
      %{
        graph: "answer",
        title: "Reply",
        description: "The system will reply to the node",
        url: "/answer?node=3",
        node: "3"
      },
      %{
        graph: "branch",
        title: "Branch",
        description: "Create a thesis / antithesis (for / against) argument for a node",
        url: "/branch?node=1",
        node: "1"
      },
      %{
        graph: "combine",
        title: "Combine",
        description: "Create a synthesis from 2 nodes",
        url: "/combine?node=4",
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
