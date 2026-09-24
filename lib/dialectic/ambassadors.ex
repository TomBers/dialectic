defmodule Dialectic.Ambassadors do
  alias Dialectic.Ambassadors.Interest
  alias Dialectic.Repo

  def change_interest(attrs \\ %{}) do
    Interest.changeset(%Interest{}, attrs)
  end

  def register_interest(attrs) do
    attrs
    |> change_interest()
    |> Repo.insert(on_conflict: :nothing, conflict_target: :email)
  end
end
