defmodule Dialectic.AmbassadorsTest do
  use Dialectic.DataCase, async: true

  alias Dialectic.Ambassadors
  alias Dialectic.Ambassadors.Interest

  test "saves normalized email and audience for measuring interest" do
    assert {:ok, interest} =
             Ambassadors.register_interest(%{email: "  Teacher@Example.com  ", role: "educator"})

    saved = Repo.get!(Interest, interest.id)
    assert saved.email == "teacher@example.com"
    assert saved.role == :educator
    assert saved.inserted_at
  end

  test "repeat signups are successful without duplicating or changing the original interest" do
    assert {:ok, _} = Ambassadors.register_interest(%{email: "tutor@example.com", role: "tutor"})

    assert {:ok, _} =
             Ambassadors.register_interest(%{email: "TUTOR@example.com", role: "student"})

    assert [%{role: :tutor}] = Repo.all(Interest)
  end

  test "invalid emails and roles do not create leads" do
    assert {:error, changeset} =
             Ambassadors.register_interest(%{email: "not-an-email", role: "invented"})

    assert errors_on(changeset).email == ["Enter a valid email address"]
    assert errors_on(changeset).role == ["is invalid"]
    assert Repo.aggregate(Interest, :count) == 0
  end

  test "both email and role are required" do
    assert {:error, changeset} = Ambassadors.register_interest(%{})
    assert errors_on(changeset).email == ["can't be blank"]
    assert errors_on(changeset).role == ["can't be blank"]
  end

  test "rejects oversized email addresses" do
    assert {:error, changeset} =
             Ambassadors.register_interest(%{
               email: String.duplicate("a", 250) <> "@example.com",
               role: "student"
             })

    assert "should be at most 254 character(s)" in errors_on(changeset).email
    assert Repo.aggregate(Interest, :count) == 0
  end
end
