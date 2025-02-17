defmodule Graph.ContextTest do
  use DialecticWeb.ConnCase, async: false

  @graph_id "What is ethics"

  setup do
    # Setup the graph, used for subsequent tests
    if !GraphManager.exists?(@graph_id) do
      GraphManager.reset_graph(@graph_id)
      Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)
    end

    :ok
  end

  describe "Context Generation" do
    test "should generate a context" do
      GraphManager.get_graph(@graph_id)
      context = GraphManager.build_context(@graph_id, %{id: "6"})
      # Ensure the context includes all of the parents
      assert context =~ "What is ethics?\n\nWhat are the principles of Ethics?"
    end
  end

  test "should generate a context with limit" do
    GraphManager.get_graph(@graph_id)
    context = GraphManager.build_context(@graph_id, %{id: "6"}, 200)
    # Ensure the context is correctly generated
    assert context =~ "What are the different principles of Ethics?"
  end
end
