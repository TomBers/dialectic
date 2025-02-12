defmodule Dialectic.DbActions.Graph do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Vertex

  import Ecto.Query

  @doc """
  Creates a new graph with the given title.
  """
  def create_new_graph(title, user \\ nil) do
    %Graph{}
    |> Graph.changeset(%{
      title: title,
      user_id: user && user.id,
      data: default_graph_data(title),
      is_public: true,
      is_deleted: false,
      is_published: true
    })
    |> Repo.insert()
  end

  defp default_graph_data(content) do
    %{
      "nodes" => [%Vertex{id: "1", content: content}],
      "edges" => []
    }
  end

  def list_graphs do
    query =
      from p in Graph,
        select: p.title

    Repo.all(query)
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
end
