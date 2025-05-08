defmodule Dialectic.Responses.LlmInterfaceTest do
  use ExUnit.Case, async: false
  
  describe "LlmInterface API" do
    test "exports all the expected functions" do
      # Verify all expected methods exist with the correct arity
      assert Code.ensure_loaded?(Dialectic.Responses.LlmInterface)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_response, 3)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_selection_response, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_synthesis, 4)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_thesis, 3)
      assert function_exported?(Dialectic.Responses.LlmInterface, :gen_antithesis, 3)
      assert function_exported?(Dialectic.Responses.LlmInterface, :ask_model, 3)
    end
  end
end