defmodule Dialectic.DbActions.Init do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Serialise

  def seed do
    [
      "Satre",
      "Big graph",
      "German Idealism",
      "Small is Beautiful - Schumacher",
      "The Republic - Plato",
      "What is ethics",
      "Narcissus",
      "What is good and what is evil",
      "Normative ethical theories",
      "Girard - Scapegoat",
      "What is Dialectics"
    ]
    |> Enum.map(fn graph_name ->
      data = Serialise.load_graph_as_json(graph_name)

      try do
        %Graph{}
        |> Graph.changeset(%{
          title: graph_name,
          user_id: nil,
          data: data,
          is_public: false,
          is_deleted: false,
          is_published: true
        })
        |> Repo.insert!()

        {graph_name, "Inserted"}
      catch
        _error, _ ->
          {graph_name, "Already exits"}
      end
    end)
  end
end
