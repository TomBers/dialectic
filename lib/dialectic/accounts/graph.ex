defmodule Dialectic.Accounts.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:title, :string, []}

  schema "graphs" do
    field :data, :map
    field :is_public, :boolean
    field :is_published, :boolean
    field :is_deleted, :boolean

    belongs_to :user, Dialectic.Accounts.User
    has_many :notes, Dialectic.Accounts.Note, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  def changeset(graph, attrs) do
    graph
    |> cast(attrs, [:title, :data, :is_public, :is_published, :is_deleted, :user_id])
    |> validate_required([:title, :data])
    |> unique_constraint(:title, name: :graphs_pkey)
  end
end
