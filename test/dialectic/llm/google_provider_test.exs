defmodule Dialectic.LLM.GoogleProviderTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Providers.Google

  test "uses Gemini Flash with low thinking and search grounding" do
    assert Google.model() == "gemini-3.7-flash"

    assert Google.provider_options() == [
             google_thinking_level: "low",
             google_grounding: %{enable: true}
           ]
  end
end
