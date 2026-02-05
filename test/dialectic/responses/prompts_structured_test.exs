defmodule Dialectic.Responses.PromptsStructuredTest do
  use ExUnit.Case, async: true
  alias Dialectic.Responses.PromptsStructured

  describe "system_preamble/1" do
    test "returns expert persona" do
      prompt = PromptsStructured.system_preamble(:expert)
      assert prompt =~ "SYSTEM"
      assert prompt =~ "Persona: A world-class subject matter expert"
      assert prompt =~ "highly technical, rigorous, and nuanced analysis"
    end

    test "returns simple persona" do
      prompt = PromptsStructured.system_preamble(:simple)
      assert prompt =~ "SYSTEM"

      assert prompt =~
               "Persona: An explainer aiming to explain concepts simply as if to a 5-year-old"
    end

    test "returns high_school persona" do
      prompt = PromptsStructured.system_preamble(:high_school)
      assert prompt =~ "SYSTEM"

      assert prompt =~
               "Persona: A clear teacher aiming to explain concepts to a high school student"
    end

    test "returns university persona (default)" do
      prompt = PromptsStructured.system_preamble()
      assert prompt =~ "SYSTEM"

      assert prompt =~
               "Persona: A precise lecturer aiming to provide a university level introduction"
    end

    test "returns university persona for :university mode" do
      prompt = PromptsStructured.system_preamble(:university)
      assert prompt =~ "SYSTEM"

      assert prompt =~
               "Persona: A precise lecturer aiming to provide a university level introduction"
    end

    test "returns university persona for unknown mode" do
      prompt = PromptsStructured.system_preamble(:unknown)
      assert prompt =~ "SYSTEM"

      assert prompt =~
               "Persona: A precise lecturer aiming to provide a university level introduction"
    end

    test "includes common structure" do
      prompt = PromptsStructured.system_preamble(:expert)
      assert prompt =~ "Markdown output contract"
      assert prompt =~ "Output ONLY valid CommonMark"
      assert prompt =~ "Style for structured mode"
      assert prompt =~ "Graph-based exploration context"
    end
  end
end
