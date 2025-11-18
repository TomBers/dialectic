defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller

  alias Dialectic.Graph.{Vertex, Serialise}
  alias Dialectic.DbActions.{Notes}

  def home(conn, params) do
    top_graphs = Notes.top_graphs(5)
    recent_graphs = Notes.recent_graphs(5)
    topic = Map.get(params, "topic", "")
    # IO.inspect(stats, label: "Stats")
    render(conn, :home, top_graphs: top_graphs, recent_graphs: recent_graphs, topic: topic)
  end

  def my_graphs(conn, _params) do
    stats = Notes.get_my_stats(conn.assigns.current_user)

    # IO.inspect(stats, label: "Stats")
    render(conn, :my_graphs, stats: stats)
  end

  def view_all(conn, params) do
    search_term = Map.get(params, "search", "")
    graphs = Dialectic.DbActions.Graphs.all_graphs_with_notes(search_term)
    render(conn, :view_all, graphs: graphs, search_term: search_term)
  end

  # def graph_json(conn, %{"graph_name" => graph_id_uri}) do
  #   graph_name = URI.decode(graph_id_uri)
  #   graph = Graphs.get_graph_by_title(graph_name).data
  #   json(conn, graph)
  # end

  def graph_md(conn, %{"graph_name" => graph_id_uri}) do
    graph_name = URI.decode(graph_id_uri)
    graph_struct = Dialectic.DbActions.Graphs.get_graph_by_title(graph_name)
    graph = Dialectic.Graph.Serialise.json_to_graph(graph_struct.data)

    # Convert the graph to markdown
    markdown_content =
      Dialectic.Linear.ThreadedConv.prepare_conversation(graph)
      |> Enum.map(&(&1.content <> "\n\n"))

    # Set filename
    filename = "#{graph_name}.md"

    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("content-disposition", "attachment; filename=#{filename}")
    |> send_resp(200, markdown_content)
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
        node: "2"
      },
      %{
        graph: "branch",
        title: "Branch",
        description: "Create a thesis / antithesis (for / against) argument for a node",
        node: "2"
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
    keys = [
      "ANTHROPIC_API_KEY",
      "DEEPSEEK_API_KEY",
      "GEMINI_API_KEY",
      "OPENAI_API_KEY"
    ]

    seeds = Dialectic.DbActions.Init.seed()
    render(conn, :deploy_dashboard, seeds: seeds, keys: Enum.map(keys, &check_key(&1)))
  end

  def ideas_all(conn, _params) do
    ideas = Dialectic.Ideas.IdeaGenerator.all()
    render(conn, :ideas_all, ideas: ideas)
  end

  def random_question(conn, _params) do
    question = Dialectic.Ideas.IdeaGenerator.run()
    json(conn, %{question: question})
  end

  def guide(conn, _params) do
    render(conn, :how)
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
