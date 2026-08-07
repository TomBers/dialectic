defmodule Dialectic.Test.LLMGenerator do
  @moduledoc false

  def generate(prompt, opts) do
    if test_pid = Application.get_env(:dialectic, :llm_generator_test_pid) do
      send(test_pid, {:llm_generate, prompt, opts})
    end

    {:error, :test_request_complete}
  end
end
