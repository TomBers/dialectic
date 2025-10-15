defmodule Dialectic.Responses.LlmInterfaceTest do
  use ExUnit.Case, async: false

  describe "LlmInterface API" do
    test "exports all the expected functions" do
      # Verify all expected methods exist with the correct arity
      assert Code.ensure_loaded?(Dialectic.Responses.LlmInterface)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_response, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_selection_response, 5)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_synthesis, 5)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_thesis, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_antithesis, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_deepdive, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :ask_model, 4)
    end
  end
end
