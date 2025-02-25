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

  def view_all(conn, _params) do
    graphs = Dialectic.DbActions.Graphs.all_graphs_with_notes()
    render(conn, :view_all, graphs: graphs)
  end

  def create(conn, %{"conversation" => usr_graph_title}) do
    title = String.replace_suffix(usr_graph_title, "?", "")

    case Graphs.create_new_graph(title, conn.assigns.current_user) do
      {:ok, _} ->
        conn
        |> redirect(to: ~p"/#{title}")

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

  def deploy_dashboard(conn, _params) do
    keys = ["ANTHROPIC_API_KEY", "DEEPSEEK_API_KEY", "GEMINI_API_KEY", "OPENAI_API_KEY"]

    seeds = Dialectic.DbActions.Init.seed()
    render(conn, :deploy_dashboard, seeds: seeds, keys: Enum.map(keys, &check_key(&1)))
  end

  def random_question(conn, _params) do
    question = Dialectic.Ideas.IdeaGenerator.run()
    json(conn, %{question: question})
  end

  defp check_key(key) do
    case System.get_env(key) do
      nil -> "Missing #{key}"
      _ -> "Found #{key}"
    end
  end

  defp encode_graph(n) do
    Serialise.load_graph(n) |> Vertex.to_cytoscape_format() |> Jason.encode!()
  end
end
