defmodule Dialectic.DbActions.Graphs do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Vertex

  import Ecto.Query

  @doc """
  Creates a new graph with the given title.
  """
  def create_new_graph(title, user \\ nil) do
    {data, ans_node} = default_graph_data(title)

    graph =
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

    spawn(fn ->
      Dialectic.Responses.RequestQueue.add(title, ans_node, title)
    end)

    graph
  end

  defp default_graph_data(content) do
    ans_node = %Vertex{id: "2", content: "", class: "answer"}

    data = %{
      "nodes" => [%Vertex{id: "1", content: content}, ans_node],
      "edges" => [
        %{
          data: %{
            id: "12",
            source: "1",
            target: "2"
          }
        }
      ]
    }

    {data, ans_node}
  end

  def list_graphs do
    # query =
    #   from p in Graph,
    #     select: p.title

    Repo.all(Graph)
  end

  def all_graphs_with_notes() do
    query =
      from g in Dialectic.Accounts.Graph,
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
end
