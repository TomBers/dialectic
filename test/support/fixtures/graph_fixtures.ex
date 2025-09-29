defmodule Dialectic.GraphFixtures do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Serialise

  def insert_graph_fixture(graph_name) do
    Serialise.load_graph_as_json(graph_name) |> insert_data(graph_name)
  end

  def insert_data(data, title) do
    graph =
      %Graph{}
      |> Graph.changeset(%{
        title: title,
        user_id: nil,
        data: data,
        is_public: true,
        is_deleted: false,
        is_published: true
      })
      |> Repo.insert!()

    {:ok, graph}
  end
end
