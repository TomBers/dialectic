defmodule DialecticWeb.UserSessionControllerTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts.User

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/log_in" do
    test "returns to the selected response after an unsuccessful login and retry", %{
      conn: conn,
      user: user
    } do
      return_to = "/g/a-public-grid?node=16#reading-node-16"
      conn = get(conn, ~p"/users/log_in?#{%{return_to: return_to}}")
      assert get_session(conn, :user_return_to) == return_to

      conn =
        post(recycle(conn), ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => "wrong-password"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert get_session(conn, :user_return_to) == return_to

      conn =
        post(recycle(conn), ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == return_to
    end

    test "keeps the grid destination when switching from login to registration", %{
      conn: conn,
      user: user
    } do
      return_to = "/g/a-public-grid/graph?node=16&focus=ask"
      conn = get(conn, ~p"/users/log_in?#{%{return_to: return_to}}")
      conn = get(recycle(conn), ~p"/users/register")

      conn =
        post(recycle(conn), ~p"/users/log_in?_action=registered", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == return_to
    end

    test "ignores unsafe or unrelated return destinations", %{conn: conn} do
      for return_to <- [
            "https://example.com/g/grid",
            "//example.com/g/grid",
            "/\\example.com",
            "/users/log_out",
            "/g/grid\n",
            "/g/%2f%2fexample.com"
          ] do
        result = get(conn, ~p"/users/log_in?#{%{return_to: return_to}}")
        refute get_session(result, :user_return_to)
      end
    end

    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ "My Profile"
      refute response =~ ~s(href="/users/settings")
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_dialectic_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, user: user} do
      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "registered",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/u/#{User.effective_username(user)}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Your profile is your personal thinking homepage"
    end

    test "login following password update", %{conn: conn, user: user} do
      conn =
        conn
        |> post(~p"/users/log_in", %{
          "_action" => "password_updated",
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log_in"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
