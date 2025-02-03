defmodule DialecticWeb.PageController do
  use DialecticWeb, :controller
  alias Dialectic.Graph.Serialise

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
end
