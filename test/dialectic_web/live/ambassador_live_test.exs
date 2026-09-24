defmodule DialecticWeb.AmbassadorLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Dialectic.Ambassadors
  alias Dialectic.Ambassadors.Interest
  alias Dialectic.Repo

  test "public landing page has a signup form and clear programme information", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    assert has_element?(view, "#amb-hero-title")
    assert has_element?(view, "#amb-hero-join[href='#join-programme']")
    assert has_element?(view, "#how-it-works")
    assert has_element?(view, "#student-referrals")
    assert has_element?(view, "#ambassador-interest-form #interest_email[type='email']")
    assert has_element?(view, "#ambassador-interest-form #interest_role")
    assert has_element?(view, "#amb-faq-earnings", "Rates, eligibility, and payment terms")
    assert has_element?(view, "#amb-faq-launch", "A launch date hasn’t been set yet")
    refute has_element?(view, "#userHeader")
  end

  test "submitting interest persists it and displays confirmation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form",
      interest: %{email: "educator@example.com", role: "educator"}
    )
    |> render_submit()

    assert has_element?(view, "#ambassador-success[role='status']")
    refute has_element?(view, "#ambassador-interest-form")
    assert %{role: :educator} = Repo.get_by!(Interest, email: "educator@example.com")
  end

  test "invalid submissions stay editable and do not persist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form", interest: %{email: "invalid", role: "tutor"})
    |> render_submit()

    assert has_element?(view, "#ambassador-interest-form p", "Enter a valid email address")
    refute has_element?(view, "#ambassador-success")
    assert Repo.aggregate(Interest, :count) == 0

    view
    |> form("#ambassador-interest-form", interest: %{email: "tutor@example.com", role: "tutor"})
    |> render_change()

    refute has_element?(view, "#ambassador-interest-form p", "Enter a valid email address")
  end

  test "student referral action selects the student audience and preserves entered email", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form", interest: %{email: "student@example.com", role: "tutor"})
    |> render_change()

    view |> element("#amb-student-join") |> render_click()

    assert has_element?(view, "#interest_role option[value='student'][selected]")
    assert has_element?(view, "#interest_email[value='student@example.com']")

    view |> form("#ambassador-interest-form") |> render_submit()
    assert %{role: :student} = Repo.get_by!(Interest, email: "student@example.com")
  end

  test "existing signups get the same confirmation without being duplicated", %{conn: conn} do
    {:ok, _} =
      Ambassadors.register_interest(%{email: "existing@example.com", role: "institution"})

    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form",
      interest: %{email: "EXISTING@example.com", role: "tutor"}
    )
    |> render_submit()

    assert has_element?(view, "#ambassador-success")
    assert [%{role: :institution}] = Repo.all(Interest)
  end

  test "repeated attempts are limited with a recoverable error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    for _ <- 1..6 do
      view
      |> form("#ambassador-interest-form", interest: %{email: "invalid", role: "educator"})
      |> render_submit()
    end

    assert has_element?(view, "#ambassador-submit-error[role='alert']", "wait a minute")
    assert has_element?(view, "#ambassador-interest-form")
    assert Repo.aggregate(Interest, :count) == 0
  end
end
