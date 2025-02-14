# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Dialectic.Repo.insert!(%Dialectic.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Dialectic.Repo
alias Dialectic.Accounts.Graph
alias Dialectic.Graph.Serialise

[
  "satre",
  "bob",
  "German Idealism",
  "Small is Beautiful - Schumacher",
  "The Republic - Plato",
  "branch",
  "What is ethics?",
  "narcissus",
  "What is good and what is evil?",
  "combine",
  "normative ethical theories",
  "Why do we dream?",
  "reply",
  "answer"
]
|> Enum.each(fn graph_name ->
  data = Serialise.load_graph_as_json(graph_name)

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
end)
