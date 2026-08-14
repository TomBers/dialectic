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
  end
end
