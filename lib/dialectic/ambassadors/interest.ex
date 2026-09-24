defmodule Dialectic.Ambassadors.Interest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :email, :string
    field :role, Ecto.Enum, values: [:educator, :tutor, :institution, :student, :other]
    field :other_role, :string
  end

  def changeset(interest, attrs) do
    interest
    |> cast(attrs, [:email, :role, :other_role])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "Enter a valid email address"
    )
    |> validate_length(:email, max: 254)
    |> validate_other_role()
  end

  defp validate_other_role(changeset) do
    if get_field(changeset, :role) == :other do
      changeset
      |> update_change(:other_role, &String.trim/1)
      |> validate_required([:other_role])
      |> validate_length(:other_role, max: 100)
    else
      put_change(changeset, :other_role, nil)
    end
  end
end
