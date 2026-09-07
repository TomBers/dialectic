defmodule Dialectic.QuestionPages.Section do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :node_id, :string
    field :title, :string
    field :body, :string
    field :limitation, :string, default: ""
    field :source_ids, {:array, :string}, default: []
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:node_id, :title, :body, :limitation, :source_ids])
    |> update_change(:source_ids, &Enum.reject(&1, fn id -> id == "" end))
    |> validate_required([:node_id, :title, :body])
    |> validate_length(:node_id, max: 100)
    |> validate_length(:title, max: 160)
    |> validate_length(:body, max: 2000)
    |> validate_length(:limitation, max: 1200)
    |> validate_length(:source_ids, max: 20)
  end
end
