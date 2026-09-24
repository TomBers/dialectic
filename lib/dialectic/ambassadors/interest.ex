defmodule Dialectic.Ambassadors.Interest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ambassador_interests" do
    field :email, :string
    field :role, Ecto.Enum, values: [:educator, :tutor, :institution, :student]

    timestamps(type: :utc_datetime)
  end

  def changeset(interest, attrs) do
    interest
    |> cast(attrs, [:email, :role])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "Enter a valid email address"
    )
    |> validate_length(:email, max: 254)
    |> unique_constraint(:email)
  end
end
