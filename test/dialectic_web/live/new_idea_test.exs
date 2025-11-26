defmodule DialecticWeb.NewIdeaTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "New Idea Page" do
    test "renders the new idea page successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/start/new/idea")
      assert html =~ "Ask a question to get started"
    end

    test "mounts with default assigns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/start/new/idea")

      state = :sys.get_state(view.pid)
      socket = state.socket

      # Check specific assigns that are initialized in the catch-all mount/3
      assert socket.assigns.graph_id == nil
      assert socket.assigns.prompt_mode == "structured"
      assert socket.assigns.node.id == "start"
      assert socket.assigns.show_share_modal == false
      assert socket.assigns.can_edit == true
      assert socket.assigns.drawer_open == true
    end

    test "respects mode query parameter", %{conn: conn} do
      # Test creative mode
      {:ok, view, _html} = live(conn, "/start/new/idea?mode=creative")
      state = :sys.get_state(view.pid).socket
      assert state.assigns.prompt_mode == "creative"

      # Test structured mode (explicit)
      {:ok, view, _html} = live(conn, "/start/new/idea?mode=structured")
      state = :sys.get_state(view.pid).socket
      assert state.assigns.prompt_mode == "structured"

      # Test invalid mode falls back to structured
      {:ok, view, _html} = live(conn, "/start/new/idea?mode=invalid")
      state = :sys.get_state(view.pid).socket
      assert state.assigns.prompt_mode == "structured"
    end
  end
end
