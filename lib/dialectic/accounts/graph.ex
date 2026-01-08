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
    field :slug, :string
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
      :slug,
      :tags
    ])
    |> validate_required([:title, :data])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_title_format()
    |> validate_data_size()
    |> validate_slug_format()
    |> unique_constraint(:title, name: :graphs_pkey)
    |> unique_constraint(:share_token)
    |> unique_constraint(:slug)
  end

  defp validate_title_format(changeset) do
    changeset
    |> validate_format(:title, ~r/^[a-zA-Z0-9\s\-_\.',:!?]+$/,
      message: "contains invalid characters"
    )
  end

  defp validate_data_size(changeset) do
    case get_change(changeset, :data) do
      nil ->
        changeset

      data when is_map(data) ->
        # Estimate JSON size (rough approximation)
        json_size = data |> Jason.encode!() |> byte_size()

        if json_size > 10_000_000 do
          add_error(changeset, :data, "is too large (max 10MB)")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_slug_format(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        changeset

      slug ->
        if String.match?(slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/) do
          changeset
        else
          add_error(changeset, :slug, "must be lowercase alphanumeric with hyphens")
        end
    end
  end
end
