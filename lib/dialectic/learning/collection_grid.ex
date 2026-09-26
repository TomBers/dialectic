defmodule Dialectic.Learning.CollectionGrid do
  use Ecto.Schema

  schema "learning_collection_grids" do
    belongs_to :collection, Dialectic.Learning.Collection

    belongs_to :graph, Dialectic.Accounts.Graph,
      foreign_key: :graph_title,
      references: :title,
      type: :string

    timestamps(type: :utc_datetime)
  end
end
