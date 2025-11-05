defmodule Dialectic.Responses.ModesTest do
  use Dialectic.DataCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  alias Dialectic.Responses.Modes
  alias Dialectic.Responses.LlmInterface
  alias Dialectic.Graph.Vertex

  describe "normalize_id/1" do
    test "handles nil and unknown values by falling back to default" do
      assert Modes.normalize_id(nil) == Modes.default()
      assert Modes.normalize_id("not-a-mode") == Modes.default()
      assert Modes.normalize_id(:unknown_mode) == Modes.default()
    end

    test "accepts atoms for known modes" do
      assert Modes.normalize_id(:structured) == :structured
      assert Modes.normalize_id(:creative) == :creative
    end

    test "normalizes common string spellings and cases" do
      # exact spellings
      assert Modes.normalize_id("structured") == :structured
      assert Modes.normalize_id("creative") == :creative

      # case-insensitive
      assert Modes.normalize_id("Structured") == :structured
      assert Modes.normalize_id("CREATIVE") == :creative
    end
  end

  describe "system_prompt/1 and compose/2" do
    test "system_prompt(mode) is base_style <> two newlines <> mode_prompt(mode)" do
      for mode <- Modes.order() do
        expected = Modes.base_style() <> "\n\n" <> Modes.mode_prompt(mode)
        assert Modes.system_prompt(mode) == expected
      end
    end

    test "compose(question, mode) prefixes system prompt and preserves question verbatim" do
      question = """
      Context:
      A

      Instruction:
      Do the thing.
      """

      for mode <- Modes.order() do
        expected = Modes.system_prompt(mode) <> "\n\n" <> question
        assert Modes.compose(question, mode) == expected
      end
    end
  end

  describe "LlmInterface.ask_model/5 integration (enqueues composed prompt)" do
    test "enqueues a LocalWorker job with the fully composed prompt for a specific mode" do
      to_node = %Vertex{id: "n-123"}
      graph_id = "G-Compose-1"
      topic = "topic-x"
      mode = :creative
      question = "What is knowledge?"

      expected_prompt = Modes.compose(question, mode)

      # Use ask_model/5 directly to avoid GraphManager context building
      _ = LlmInterface.ask_model(question, to_node, graph_id, topic, mode)

      assert_enqueued(
        worker: Elixir.Dialectic.Workers.LocalWorker,
        queue: "api_request",
        args: %{
          "question" => expected_prompt,
          "to_node" => "n-123",
          "graph" => graph_id,
          "live_view_topic" => topic,
          "module" => "Elixir.Dialectic.Workers.LocalWorker"
        }
      )
    end

    test "falls back to default mode when mode is nil" do
      to_node = %Vertex{id: "n-999"}
      graph_id = "G-Compose-Default"
      topic = "topic-default"
      question = "Default mode behavior?"

      expected_prompt = Modes.compose(question, Modes.default())

      _ = LlmInterface.ask_model(question, to_node, graph_id, topic, nil)

      assert_enqueued(
        worker: Elixir.Dialectic.Workers.LocalWorker,
        queue: "api_request",
        args: %{
          "question" => expected_prompt,
          "to_node" => "n-999",
          "graph" => graph_id,
          "live_view_topic" => topic,
          "module" => "Elixir.Dialectic.Workers.LocalWorker"
        }
      )
    end

    test "accepts string mode identifiers and normalizes them" do
      to_node = %Vertex{id: "n-777"}
      graph_id = "G-Compose-StringMode"
      topic = "topic-modes"
      question = "Mode normalization works?"
      mode_string = "creative"
      normalized = Modes.normalize_id(mode_string)

      expected_prompt = Modes.compose(question, normalized)

      _ = LlmInterface.ask_model(question, to_node, graph_id, topic, mode_string)

      assert_enqueued(
        worker: Elixir.Dialectic.Workers.LocalWorker,
        queue: "api_request",
        args: %{
          "question" => expected_prompt,
          "to_node" => "n-777",
          "graph" => graph_id,
          "live_view_topic" => topic,
          "module" => "Elixir.Dialectic.Workers.LocalWorker"
        }
      )
    end
  end
end
