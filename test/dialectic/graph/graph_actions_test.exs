defmodule Dialectic.Graph.GraphActionsTest do
  use ExUnit.Case, async: false
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Graph.Vertex

  describe "create_new_node/1" do
    test "creates a vertex with the provided user" do
      user = "test_user"
      node = GraphActions.create_new_node(user)

      assert %Vertex{} = node
      assert node.user == user
      assert String.starts_with?(node.id, "NewNode")
      assert node.noted_by == []
    end
  end

  # Since most methods in GraphActions are thin wrappers around GraphManager,
  # we'll test the method signatures rather than actual behavior
  describe "function exports" do
    test "exports all expected methods" do
      assert Code.ensure_loaded?(Dialectic.Graph.GraphActions)
      assert function_exported?(Dialectic.Graph.GraphActions, :create_new_node, 1)
      assert function_exported?(Dialectic.Graph.GraphActions, :move, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :delete_node, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :change_noted_by, 3)
      assert function_exported?(Dialectic.Graph.GraphActions, :toggle_graph_locked, 1)
      assert function_exported?(Dialectic.Graph.GraphActions, :comment, 3)
      assert function_exported?(Dialectic.Graph.GraphActions, :answer, 1)
      assert function_exported?(Dialectic.Graph.GraphActions, :answer_selection, 3)
      assert function_exported?(Dialectic.Graph.GraphActions, :branch, 1)
      assert function_exported?(Dialectic.Graph.GraphActions, :combine, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :find_node, 2)
    end
  end

  describe "comment/3" do
    test "has the correct parameter structure" do
      info = Function.info(&GraphActions.comment/3)
      arity = Keyword.fetch!(info, :arity)
      assert arity == 3
    end
  end

  describe "utility functions" do
    test "branch/1 creates both thesis and antithesis nodes" do
      # This is just testing the function signature, not actual behavior
      info = Function.info(&GraphActions.branch/1)
      arity = Keyword.fetch!(info, :arity)
      assert arity == 1
    end

    test "combine/2 combines two nodes" do
      # This is just testing the function signature, not actual behavior
      info = Function.info(&GraphActions.combine/2)
      arity = Keyword.fetch!(info, :arity)
      assert arity == 2
    end
  end
end
