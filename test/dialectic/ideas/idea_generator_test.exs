defmodule Dialectic.Ideas.IdeaGeneratorTest do
  use ExUnit.Case, async: true
  alias Dialectic.Ideas.IdeaGenerator

  describe "generate_question/1" do
    test "returns a question with the topic interpolated" do
      topic = "Artificial Intelligence"
      question = IdeaGenerator.generate_question(topic)

      assert is_binary(question)
      assert String.contains?(question, topic)
    end

    test "returns different questions for the same topic" do
      topic = "Philosophy"
      question1 = IdeaGenerator.generate_question(topic)

      # Generate multiple questions and verify at least one is different
      different_found =
        Enum.any?(1..10, fn _ ->
          question2 = IdeaGenerator.generate_question(topic)
          question1 != question2
        end)

      assert different_found, "Failed to generate a different question after 10 attempts"
    end
  end

  describe "generate_questions/2" do
    test "returns the requested number of questions" do
      topic = "Science"
      count = 5
      questions = IdeaGenerator.generate_questions(topic, count)

      assert length(questions) == count
      assert Enum.all?(questions, &String.contains?(&1, topic))
    end

    test "returns a list of strings" do
      topic = "History"
      count = 3
      questions = IdeaGenerator.generate_questions(topic, count)

      assert Enum.all?(questions, &is_binary/1)
    end
  end

  describe "run/0" do
    test "returns a randomly generated question" do
      question = IdeaGenerator.run()

      assert is_binary(question)
      # The result should follow the format of a template with a topic inserted
      # We can verify it contains common template question markers
      assert String.contains?(question, "?") ||
               String.contains?(question, "Let's talk about") ||
               String.contains?(question, "What if")
    end
  end

  describe "all/0" do
    test "returns questions for all topics" do
      # To avoid making the test brittle, we're not checking the exact count
      # but ensuring we get a reasonable number of questions
      questions = IdeaGenerator.all()

      # There should be many topics
      assert length(questions) > 50
      assert Enum.all?(questions, &is_binary/1)
    end
  end
end
