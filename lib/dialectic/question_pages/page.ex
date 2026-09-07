defmodule Dialectic.QuestionPages.Page do
  use Ecto.Schema

  schema "question_pages" do
    field :graph_title, :string
    field :slug, :string
    field :draft, :map
    field :source, :map
    field :published, :map
    field :published_at, :utc_datetime
    field :first_published_at, :utc_datetime
    field :lock_version, :integer, default: 1
    field :editor_id, :id
    field :graph_slug, :string, virtual: true
    timestamps(type: :utc_datetime)
  end
end
