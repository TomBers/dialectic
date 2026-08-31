defmodule DialecticWeb.AuthControllerTest do
  use DialecticWeb.ConnCase, async: true

  alias DialecticWeb.AuthController

  test "Google login writes the persistent remember-me cookie", %{conn: conn} do
    unique = System.unique_integer([:positive])

    auth = %{
      info: %{email: "oauth-#{unique}@example.com"},
      provider: :google,
      uid: "google-#{unique}",
      credentials: %{token: "access-token-#{unique}"}
    }

    conn =
      conn
      |> Map.replace!(:secret_key_base, DialecticWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Phoenix.Controller.fetch_flash([])
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> AuthController.callback(%{})

    assert redirected_to(conn) == ~p"/"

    assert %{max_age: 15_552_000} =
             conn.resp_cookies["_dialectic_web_user_remember_me"]

    assert Phoenix.Flash.get(conn.assigns.flash, :analytics_auth_event) == "sign_up_completed"
  end

  test "existing Google users are classified as logins", %{conn: conn} do
    unique = System.unique_integer([:positive])

    auth = %{
      info: %{email: "existing-oauth-#{unique}@example.com"},
      provider: :google,
      uid: "existing-google-#{unique}",
      credentials: %{token: "first-token"}
    }

    attrs = %{
      email: auth.info.email,
      provider: "google",
      provider_id: auth.uid,
      access_token: "first-token"
    }

    assert {:ok, _user} = Dialectic.Accounts.find_or_create_oauth_user(attrs)

    conn =
      conn
      |> Map.replace!(:secret_key_base, DialecticWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Phoenix.Controller.fetch_flash([])
      |> Plug.Conn.assign(:ueberauth_auth, auth)
      |> AuthController.callback(%{})

    assert Phoenix.Flash.get(conn.assigns.flash, :analytics_auth_event) == "login_completed"
  end
end
