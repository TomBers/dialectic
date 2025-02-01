defmodule DialecticWeb.GraphLiveTest do
  use DialecticWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @moduletag :graph_live

  # test "mounts live view successfully and assigns initial state", %{conn: conn} do
  #   # Prepare query parameters as expected by mount/3
  #   params = %{"graph_name" => "test_graph", "node" => "1"}

  #   {:ok, view, _html} =
  #     live_isolated(conn, DialecticWeb.GraphLive,
  #       session: %{},
  #       params: params
  #     )

  #   # Verify initial assignments set in mount/3 using view.assigns
  #   assert view.assigns.graph_id == "test_graph"
  #   # When no current user is assigned, the default is "Anon"
  #   assert view.assigns.user == "Anon"
  #   # key_buffer should be an empty string initially
  #   assert view.assigns.key_buffer == ""
  # end

  # test "processes 's' key event and shows flash message", %{conn: conn} do
  #   params = %{"graph_name" => "test_graph", "node" => "1"}

  #   {:ok, view, _html} =
  #     live_isolated(conn, DialecticWeb.GraphLive,
  #       session: %{},
  #       params: params
  #     )

  #   # Simulate the "KeyBoardInterface" event with key "s" and cmdKey true.
  #   # Use push_event/3 to trigger the event.
  #   updated_view =
  #     Phoenix.LiveViewTest.push_event(view, "KeyBoardInterface", %{"key" => "s", "cmdKey" => true})

  #   # Assert that the flash info message "Saved!" is set.
  #   assert Phoenix.LiveViewTest.get_flash(updated_view, :info) == "Saved!"
  #   # The key_buffer should be reset to an empty string after processing.
  #   assert updated_view.assigns.key_buffer == ""
  # end
end
