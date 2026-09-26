defmodule Dialectic.Learning.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "learning_collections" do
    field :name, :string
    field :description, :string
    field :origin, Ecto.Enum, values: [:manual, :tags], default: :manual
    belongs_to :user, Dialectic.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name, :description])
    |> update_change(:name, &trim/1)
    |> update_change(:description, &trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name, name: :learning_collections_user_name_index)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
