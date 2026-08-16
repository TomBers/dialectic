defmodule Dialectic.LLM.GoogleProviderTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Providers.Google

  test "uses Gemini Flash with low thinking and search grounding by default" do
    assert Google.model() == "gemini-3.7-flash"

    assert Google.provider_options() == [
             google_thinking_level: "low",
             google_grounding: %{enable: true}
           ]
  end

  test "maps app modes to thinking levels while retaining search grounding" do
    expectations = [
      simple: "low",
      high_school: "low",
      university: "medium",
      expert: "high",
      unknown: "medium"
    ]

    for {mode, thinking_level} <- expectations do
      assert Google.provider_options(mode) == [
               google_thinking_level: thinking_level,
               google_grounding: %{enable: true}
             ]
    end
  end
end
