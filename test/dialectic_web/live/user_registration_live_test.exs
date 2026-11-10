defmodule DialecticWeb.UserRegistrationLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create an account"
      assert html =~ "Log in"
      assert html =~ "Sign up free"
      assert html =~ "Free account. No payment details."
      assert html =~ "control who can view or edit them"
      assert has_element?(lv, "#registration-page", "Turn a question into reasoning")
      assert has_element?(lv, "#registration-home-link")
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/my/learning"}}} = live(conn, ~p"/users/register")
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Create an account"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register user" do
    test "MCP setup signup creates an account and returns to connected apps", %{conn: conn} do
      feature =
        conn |> get(~p"/features/ai-assistants") |> html_response(200) |> LazyHTML.from_document()

      [registration_url] =
        feature |> LazyHTML.query("#ai-assistants-connect") |> LazyHTML.attribute("href")

      conn = get(recycle(conn), registration_url)
      {:ok, lv, _html} = live(conn)

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/connections"

      page =
        conn
        |> recycle()
        |> get(redirected_to(conn))
        |> html_response(200)
        |> LazyHTML.from_document()

      assert page |> LazyHTML.query("#mcp-connect") |> Enum.count() == 1
      assert page |> LazyHTML.query("#mcp-account-notice") |> LazyHTML.text() =~ email
    end

    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/my/learning"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Get started in My Learning"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ "My Profile"

      assert response
             |> LazyHTML.from_document()
             |> LazyHTML.query("#account-menu #account-settings-link")
             |> LazyHTML.attribute("href") == ["/users/settings"]
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("#registration-login-link")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Log in"
    end
  end
end
