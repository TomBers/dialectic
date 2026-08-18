defmodule Dialectic.LLM.GoogleProviderTest do
  use ExUnit.Case, async: true

  alias Dialectic.LLM.Providers.Google

  test "uses Gemini Flash with the fast Essential profile by default" do
    assert Google.model() == "gemini-3.5-flash-lite"

    assert Google.provider_options() == [
             google_thinking_level: "minimal",
             google_grounding: %{enable: false}
           ]
  end

  test "maps app modes to thinking and grounding profiles" do
    expectations = [
      high_school: {"minimal", false},
      university: {"low", true},
      expert: {"medium", true},
      unknown: {"low", false}
    ]

    for {mode, {thinking_level, grounding?}} <- expectations do
      assert Google.provider_options(mode) == [
               google_thinking_level: thinking_level,
               google_grounding: %{enable: grounding?}
             ]
    end
  end
end
