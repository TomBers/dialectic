defmodule Dialectic.Accounts.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:title, :string, []}

  schema "graphs" do
    field :data, :map
    field :is_public, :boolean
    field :is_published, :boolean
    field :is_deleted, :boolean
    field :is_locked, :boolean, default: false
    field :share_token, :string
    field :tags, {:array, :string}, default: []

    belongs_to :user, Dialectic.Accounts.User
    has_many :notes, Dialectic.Accounts.Note, on_delete: :delete_all
    has_many :shares, Dialectic.Accounts.GraphShare, foreign_key: :graph_title

    timestamps(type: :utc_datetime)
  end

  def changeset(graph, attrs) do
    graph
    |> cast(attrs, [
      :title,
      :data,
      :is_public,
      :is_published,
      :is_deleted,
      :is_locked,
      :user_id,
      :share_token,
      :tags
    ])
    |> validate_required([:title, :data])
    |> unique_constraint(:title, name: :graphs_pkey)
    |> unique_constraint(:share_token)
  end
end
