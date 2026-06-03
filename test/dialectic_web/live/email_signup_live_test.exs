defmodule DialecticWeb.EmailSignupLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.Notifications

  test "renders the signup form", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/updates")

    assert html =~ "Follow RationalGrid as it grows"
    assert html =~ "email-signup-form"
  end

  test "submits an email signup", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/updates")

    html =
      view
      |> form("#email-signup-form", subscriber: %{email: "person@example.com"})
      |> render_submit()

    assert html =~ "email-signup-submitted"
    assert Notifications.get_email_subscriber_by_email("person@example.com")
  end

  test "shows validation errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/updates")

    html =
      view
      |> form("#email-signup-form", subscriber: %{email: "not valid"})
      |> render_submit()

    assert html =~ "must have the @ sign and no spaces"
  end
end
