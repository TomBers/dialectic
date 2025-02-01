defmodule DialecticWeb.GraphLiveTest do
  use DialecticWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  describe "mount/3" do
    test "assigns necessary values on mount with a current user", %{conn: conn} do
      graph_id = "satre"

      # Ensure you have the proper session set up:
      conn =
        conn
        |> log_in_user(user_fixture(%{email: "tester@example.com"}))

      # Use the correct route/path that matches your LiveView route.
      {:ok, view, _html} = live(conn, ~p"/#{graph_id}?node=1")

      # Use :sys.get_state to access the underlying LiveView socket.
      state = :sys.get_state(view.pid)
      socket = state.socket
      assert socket.assigns.graph_id == graph_id
      assert socket.assigns.user == "tester@example.com"

      # Other assertions, e.g.:
      assert socket.assigns.key_buffer == ""
      refute socket.assigns.show_combine
    end
  end
end
