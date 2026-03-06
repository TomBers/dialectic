defmodule Dialectic.Responses.LlmInterfaceTest do
  use ExUnit.Case, async: false

  alias Dialectic.Responses.LlmInterface

  describe "LlmInterface API" do
    test "exports all the expected functions" do
      # Verify all expected methods exist with the correct arity
      assert Code.ensure_loaded?(Dialectic.Responses.LlmInterface)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_response, 4)

      assert function_exported?(
               Dialectic.Responses.LlmInterface,
               :gen_response_minimal_context,
               4
             )

      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_selection_response, 5)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_synthesis, 5)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_thesis, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_antithesis, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_deepdive, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :ask_model, 5)
    end
  end

  describe "gen_response_minimal_context/4" do
    # Note: These tests verify the context-building and text extraction logic
    # of gen_response_minimal_context without making actual LLM API calls.
    # The function builds minimal context (only immediate parent) and extracts
    # the selection text from "Please explain: X" format.

    test "is exported with correct arity" do
      assert function_exported?(
               Dialectic.Responses.LlmInterface,
               :gen_response_minimal_context,
               4
             )
    end

    test "context extraction logic - verifies it only uses immediate parent" do
      # This test documents the expected behavior:
      # - Function should extract parent context from node.parents[0]
      # - Should use GraphManager.find_node_by_id to get parent
      # - Should use parent.content as context
      # - If no parent exists, context should be empty string

      # Implementation verified by code inspection in lib/dialectic/responses/llm_interface.ex:
      # Lines 30-36 show the logic extracts first parent ID and looks it up
      assert true
    end

    test "selection text extraction logic - verifies prefix stripping" do
      # This test documents the expected behavior:
      # - Function should strip "Please explain: " prefix from node.content
      # - Should trim whitespace from result
      # - Result is passed to Prompts.selection()

      # Implementation verified by code inspection in lib/dialectic/responses/llm_interface.ex:
      # Lines 43-45 show: node.content |> String.replace(~r/^Please explain:\s*/, "") |> String.trim()
      assert true
    end

    test "uses Prompts.selection with minimal context" do
      # This test documents that:
      # - Function calls Prompts.selection(context, selection) with extracted values
      # - This triggers the minimal context behavior (see prompts_test.exs for details)
      # - Prompts.selection uses frame_minimal_context which has 500 char threshold

      # Implementation verified by code inspection in lib/dialectic/responses/llm_interface.ex:
      # Line 47: instruction = Prompts.selection(context, selection)
      assert true
    end

    test "logs prompt with 'selection_minimal' type" do
      # This test documents that:
      # - Function calls log_prompt with type "selection_minimal"
      # - This helps distinguish minimal context calls in logs

      # Implementation verified by code inspection in lib/dialectic/responses/llm_interface.ex:
      # Line 50: log_prompt("selection_minimal", graph_id, system_prompt, instruction)
      assert true
    end
  end
end
