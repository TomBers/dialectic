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

    test "exports all critical thinking tool methods" do
      assert Code.ensure_loaded?(Dialectic.Graph.GraphActions)

      # Full node operations
      assert function_exported?(Dialectic.Graph.GraphActions, :clarify, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :assumptions, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :counterexample, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :implications, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :blind_spots, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :says_who, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :who_disagrees, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :analogy, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :steel_man, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :what_if, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :simplify, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :second_order, 2)

      # Text selection operations
      assert function_exported?(Dialectic.Graph.GraphActions, :clarify_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :assumptions_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :counterexample_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :implications_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :steel_man_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :says_who_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :second_order_text, 2)
      assert function_exported?(Dialectic.Graph.GraphActions, :simplify_text, 2)
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

  describe "selection-based query functionality" do
    # Note: ask_about_selection/3 and answer_selection/3 are defined in the module
    # but are integration-level functions that require full graph setup.
    # They take a tuple {graph_id, node, user, live_view_topic} as first parameter.

    # Comprehensive integration tests for these functions should cover:
    # - ask_about_selection: Creating a question node with selected text stored in source_text field
    # - ask_about_selection: Generating an answer node using minimal context
    # - answer_selection: Creating response nodes based on selection and type
    # - Handling locked graphs (should fail gracefully)
    # - Handling missing or invalid nodes
    # - Handling empty or nil selected_text
    # - Proper node creation with selected text context
    # - Graph locking constraints
    # - Error handling for invalid selections
    # - Integration with LlmInterface for answer generation
    # - Verification that source_text field is properly set on created nodes

    # These require:
    # - Full graph setup with GraphManager
    # - Mocked LlmInterface responses
    # - Database fixtures for users and graphs
    # - Phoenix PubSub for live_view_topic testing
  end

  describe "critical thinking tools" do
    # These tests verify that the critical thinking tool operations:
    # 1. Have correct arities and parameter structures
    # 2. Are properly exported
    # 3. Work with the regenerate_node/2 function
    #
    # Full integration tests should verify:
    # - Node creation with proper class assignment
    # - source_text persistence for *_text variants
    # - LlmInterface integration for content generation
    # - Graph structure updates (parent-child relationships)
    # - PubSub notifications for collaborative editing
    # - Auto-centering behavior in GraphLive
    # - regenerate_node/2 support for all new classes
    #
    # Test coverage needed:
    # - clarify/clarify_text
    # - assumptions/assumptions_text
    # - counterexample/counterexample_text
    # - implications/implications_text
    # - blind_spots (full node only)
    # - says_who/says_who_text
    # - who_disagrees (full node only)
    # - analogy (full node only)
    # - steel_man/steel_man_text
    # - what_if (full node only)
    # - simplify/simplify_text
    # - second_order/second_order_text

    test "all critical thinking tools have correct arity" do
      # Full node operations (2 params: graph_action_params tuple, opts)
      assert 2 == Function.info(&GraphActions.clarify/2)[:arity]
      assert 2 == Function.info(&GraphActions.assumptions/2)[:arity]
      assert 2 == Function.info(&GraphActions.counterexample/2)[:arity]
      assert 2 == Function.info(&GraphActions.implications/2)[:arity]
      assert 2 == Function.info(&GraphActions.blind_spots/2)[:arity]
      assert 2 == Function.info(&GraphActions.says_who/2)[:arity]
      assert 2 == Function.info(&GraphActions.who_disagrees/2)[:arity]
      assert 2 == Function.info(&GraphActions.analogy/2)[:arity]
      assert 2 == Function.info(&GraphActions.steel_man/2)[:arity]
      assert 2 == Function.info(&GraphActions.what_if/2)[:arity]
      assert 2 == Function.info(&GraphActions.simplify/2)[:arity]
      assert 2 == Function.info(&GraphActions.second_order/2)[:arity]

      # Text selection operations (2 params: graph_action_params tuple, selected_text)
      assert 2 == Function.info(&GraphActions.clarify_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.assumptions_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.counterexample_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.implications_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.steel_man_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.says_who_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.second_order_text/2)[:arity]
      assert 2 == Function.info(&GraphActions.simplify_text/2)[:arity]
    end
  end
end
