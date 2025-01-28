defmodule GraphManagerTest do
  use ExUnit.Case
  doctest GraphManager

  describe "graph creation and existence" do
    test "starts a new graph manager for a path" do
      g1 = GraphManager.get_graph("BOB")
      g2 = GraphManager.get_graph("BOB")
      assert g1 == g2
    end
  end
end
