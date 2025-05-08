defmodule Dialectic.Responses.BaseAPIWorkerTest do
  use ExUnit.Case, async: false
  
  describe "BaseAPIWorker behavior" do
    test "defines the required callbacks" do
      # Verify that the behavior defines the expected callbacks
      callbacks = Dialectic.Workers.BaseAPIWorker.behaviour_info(:callbacks)
      
      # Map callbacks to just the names
      callback_names = Enum.map(callbacks, &elem(&1, 0))
      
      # Check each expected callback exists
      assert :api_key in callback_names
      assert :request_url in callback_names
      assert :headers in callback_names
      assert :build_request_body in callback_names
      assert :parse_chunk in callback_names
      assert :handle_result in callback_names
    end
  end
end