defmodule Dialectic.DbActions.Graphs do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Vertex

  import Ecto.Query

  @doc """
  Creates a new graph with the given title.
  """
  def create_new_graph(title, user \\ nil) do
    data = %{
      "nodes" => [%Vertex{id: "1", content: title}],
      "edges" => []
    }

    %Graph{}
    |> Graph.changeset(%{
      title: title,
      user_id: user && user.id,
      data: data,
      is_public: true,
      is_deleted: false,
      is_published: true
    })
    |> Repo.insert()
  end

  def list_graphs do
    # query =
    #   from p in Graph,
    #     select: p.title

    Repo.all(Graph)
  end

  def all_graphs_with_notes(search_term \\ "") do
    search_pattern = "%#{String.trim(search_term)}%"

    query =
      from g in Dialectic.Accounts.Graph,
        where: g.is_published == true,
        where: ilike(g.title, ^search_pattern),
        left_join: n in assoc(g, :notes),
        group_by: g.title,
        order_by: [desc: count(n.id)],
        select: {g, count(n.id)}

    Dialectic.Repo.all(query)
  end

  @doc """
  Retrieves a graph by its title.
  """
  def get_graph_by_title(title) do
    Repo.get_by(Graph, title: title)
  end

  @doc """
  Saves (updates) the graph data for the graph with the given title.
  Returns {:ok, graph} if successful or {:error, changeset} if not.
  If no graph is found, returns {:error, :not_found}.
  """
  def save_graph(title, data) do
    case get_graph_by_title(title) do
      nil ->
        {:error, :not_found}

      graph ->
        graph
        |> Graph.changeset(%{data: data})
        |> Repo.update()
    end
  end

  def toggle_graph_locked(graph) do
    graph
    |> Graph.changeset(%{is_public: !graph.is_public})
    |> Repo.update!()
  end
end
