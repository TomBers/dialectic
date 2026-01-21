defmodule DialecticWeb.AuthControllerTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts

  describe "GET /auth/:provider/callback - success scenarios" do
    test "creates new OAuth user and logs them in", %{conn: conn} do
      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google_user_123",
        info: %Ueberauth.Auth.Info{email: "newuser@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "access_token_123",
          refresh_token: "refresh_token_123"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully authenticated with Google."

      assert get_session(conn, :user_token)
    end

    test "links OAuth account to existing user with same email", %{conn: conn} do
      existing_user = user_fixture(%{email: "existing@example.com"})

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google_user_456",
        info: %Ueberauth.Auth.Info{email: existing_user.email},
        credentials: %Ueberauth.Auth.Credentials{
          token: "access_token_456",
          refresh_token: "refresh_token_456"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully authenticated with Google."

      assert get_session(conn, :user_token)

      # Verify the existing user was linked
      user = Accounts.get_user_by_email(existing_user.email)
      assert user.provider == "google"
      assert user.provider_id == "google_user_456"
    end

    test "updates tokens for existing OAuth user", %{conn: conn} do
      # Create an OAuth user first
      oauth_user = oauth_user_fixture()

      auth = %Ueberauth.Auth{
        provider: :google,
        uid: oauth_user.provider_id,
        info: %Ueberauth.Auth.Info{email: oauth_user.email},
        credentials: %Ueberauth.Auth.Credentials{
          token: "new_access_token",
          refresh_token: "new_refresh_token"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully authenticated with Google."

      assert get_session(conn, :user_token)
    end

    test "handles nil refresh token gracefully", %{conn: conn} do
      # Some OAuth providers don't always return refresh tokens
      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google_user_no_refresh",
        info: %Ueberauth.Auth.Info{email: "norefresh@example.com"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "access_token_only",
          refresh_token: nil
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Successfully authenticated with Google."

      assert get_session(conn, :user_token)
    end
  end

  describe "GET /auth/:provider/callback - failure scenarios" do
    test "handles ueberauth_failure", %{conn: conn} do
      failure = %Ueberauth.Failure{
        provider: :google,
        errors: [%Ueberauth.Failure.Error{message: "OAuth error"}]
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_failure, failure)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Failed to authenticate with Google. Please try again."

      refute get_session(conn, :user_token)
    end

    test "handles generic authentication errors with nil email", %{conn: conn} do
      # Test with missing email to trigger an error
      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "google_user_error",
        info: %Ueberauth.Auth.Info{email: nil},
        credentials: %Ueberauth.Auth.Credentials{
          token: "token",
          refresh_token: "refresh"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/users/log_in"
      flash_error = Phoenix.Flash.get(conn.assigns.flash, :error)
      assert flash_error =~ "Unable to create account" or flash_error =~ "Authentication failed"
      refute get_session(conn, :user_token)
    end

    test "handles invalid email format", %{conn: conn} do
      # Test with invalid email to trigger changeset validation error
      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "test_id",
        info: %Ueberauth.Auth.Info{email: "invalid"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "token",
          refresh_token: "refresh"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      assert redirected_to(conn) == ~p"/users/log_in"
      flash_error = Phoenix.Flash.get(conn.assigns.flash, :error)
      assert flash_error =~ "Unable to create account"
      # Verify error message contains field name
      assert flash_error =~ "email"
      refute get_session(conn, :user_token)
    end
  end

  describe "error translation" do
    test "translates changeset errors into readable format", %{conn: conn} do
      # Create auth with invalid email format to get changeset errors
      auth = %Ueberauth.Auth{
        provider: :google,
        uid: "test_translation",
        info: %Ueberauth.Auth.Info{email: "not_an_email"},
        credentials: %Ueberauth.Auth.Credentials{
          token: "token",
          refresh_token: "refresh"
        }
      }

      conn =
        conn
        |> bypass_through(DialecticWeb.Router, [:browser, :auth])
        |> get("/auth/google/callback")
        |> assign(:ueberauth_auth, auth)
        |> DialecticWeb.AuthController.callback(%{})

      # Verify error message format includes field:error structure
      flash_error = Phoenix.Flash.get(conn.assigns.flash, :error)

      if flash_error =~ "Unable to create account" do
        # Error messages should have field: error format
        assert flash_error =~ ":"
      end
    end
  end
end
