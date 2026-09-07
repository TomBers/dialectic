defmodule Dialectic.QuestionPages.Content do
  use Ecto.Schema
  import Ecto.Changeset
  alias Dialectic.QuestionPages.Section

  @fields [:title, :summary, :interpretation, :uncertainty, :exercise_question, :exercise_answer]
  @primary_key false
  embedded_schema do
    field :title, :string
    field :summary, :string
    field :interpretation, :string
    field :uncertainty, :string
    field :exercise_question, :string
    field :exercise_answer, :string
    embeds_many :evidence, Section, on_replace: :delete
    embeds_many :paths, Section, on_replace: :delete
  end

  def changeset(content, attrs) do
    changeset =
      content
      |> cast(attrs, @fields)
      |> validate_required(@fields)
      |> validate_length(:title, max: 160)
      |> cast_embed(:evidence, required: true, with: &evidence_changeset/2)
      |> cast_embed(:paths, required: true)
      |> validate_length(:evidence, min: 1, max: 3)
      |> validate_length(:paths, min: 1, max: 3)

    Enum.reduce(@fields -- [:title], changeset, &validate_length(&2, &1, max: 3000))
  end

  def load(map), do: Ecto.embedded_load(__MODULE__, map, :json)

  def dump(content),
    do: content |> Ecto.embedded_dump(:json) |> Jason.encode!() |> Jason.decode!()

  defp evidence_changeset(section, attrs) do
    section |> Section.changeset(attrs) |> validate_required([:limitation])
  end
end
