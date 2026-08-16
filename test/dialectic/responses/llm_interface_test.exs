defmodule Dialectic.Responses.LlmInterfaceTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  import Ecto.Query

  alias Dialectic.Graph.Vertex
  alias Dialectic.Repo
  alias Dialectic.Responses.{LlmInterface, ModeServer, Prompts, PromptsStructured}
  alias Dialectic.Workers.LocalWorker

  describe "LlmInterface API" do
    test "exports all the expected functions" do
      assert Code.ensure_loaded?(LlmInterface)
      assert function_exported?(LlmInterface, :gen_response, 4)
      assert function_exported?(LlmInterface, :gen_initial_response, 4)
      assert function_exported?(LlmInterface, :gen_response_minimal_context, 4)
      assert function_exported?(LlmInterface, :gen_selection_response, 5)
      assert function_exported?(LlmInterface, :gen_synthesis, 5)
      assert function_exported?(LlmInterface, :gen_thesis, 4)
      assert function_exported?(LlmInterface, :gen_antithesis, 4)
      assert function_exported?(LlmInterface, :ask_model, 5)
    end

    test "exports curated critical thinking tool functions" do
      assert Code.ensure_loaded?(LlmInterface)

      thinking_tools = [
        :gen_clarify,
        :gen_assumptions,
        :gen_counterexample,
        :gen_implications,
        :gen_blind_spots,
        :gen_says_who,
        :gen_who_disagrees,
        :gen_steel_man,
        :gen_what_if
      ]

      for tool <- thinking_tools do
        assert function_exported?(LlmInterface, tool, 4),
               "Function #{tool}/4 not exported"

        assert function_exported?(LlmInterface, tool, 5),
               "Function #{tool}/5 not exported (with content_override)"
      end
    end
  end

  describe "response-level snapshot" do
    test "uses the level captured on the child even if the graph mode changes" do
      {graph_id, _containing_node, question_node} = setup_context_graph()
      :ok = ModeServer.set_mode(graph_id, :simple)
      on_exit(fn -> ModeServer.delete_mode(graph_id) end)

      child = %{child_vertex("snapshotted") | response_level: "expert"}

      assert {:ok, job} = LlmInterface.gen_response(question_node, child, graph_id, "topic")

      persisted_job = Repo.get!(Oban.Job, job.id)
      assert persisted_job.args["system_prompt"] =~ "Complexity level: Expert"
      assert persisted_job.args["response_level"] == "expert"
      assert persisted_job.args["max_tokens"] == PromptsStructured.max_output_tokens(:expert)
    end
  end

  describe "gen_response_minimal_context/4" do
    test "routes Please explain commands to the selection prompt with containing text" do
      {graph_id, _containing_node, question_node} =
        setup_context_graph(
          "Please explain: selected phrase",
          "selected phrase",
          "selection_explain_question"
        )

      child = child_vertex("minimal-explain")

      assert {:ok, _job} =
               LlmInterface.gen_response_minimal_context(
                 question_node,
                 child,
                 graph_id,
                 "topic"
               )

      expected_prompt = Prompts.selection("Containing node text", "selected phrase")

      assert_enqueued(
        worker: LocalWorker,
        args: %{
          "question" => expected_prompt,
          "to_node" => child.id,
          "graph" => graph_id
        }
      )
    end

    test "routes custom questions with stored selected text and question content" do
      question = "Please explain: why does this distinction matter?"

      {graph_id, _containing_node, question_node} =
        setup_context_graph(question, "selected phrase", "selection_question_input")

      child = child_vertex("minimal-question")

      assert {:ok, _job} =
               LlmInterface.gen_response_minimal_context(
                 question_node,
                 child,
                 graph_id,
                 "topic"
               )

      expected_prompt =
        Prompts.selection_question("Containing node text", "selected phrase", question)

      assert_enqueued(
        worker: LocalWorker,
        args: %{
          "question" => expected_prompt,
          "to_node" => child.id,
          "graph" => graph_id
        }
      )
    end
  end

  describe "selected-text context routing" do
    test "keeps context surrounding a selection late in a long containing node" do
      containing_text =
        String.duplicate("Earlier unrelated material. ", 60) <>
          "Nearby context before selected phrase and useful context after it."

      {graph_id, _containing_node, question_node} =
        setup_context_graph(
          "Please explain: selected phrase",
          "selected phrase",
          "selection_explain_question",
          containing_text
        )

      child = child_vertex("late-selection")

      assert {:ok, _job} =
               LlmInterface.gen_response_minimal_context(
                 question_node,
                 child,
                 graph_id,
                 "topic"
               )

      worker = Oban.Worker.to_string(LocalWorker)
      job = Repo.one!(from job in Oban.Job, where: job.worker == ^worker)

      assert job.args["question"] =~ "Nearby context before selected phrase"
      assert job.args["question"] =~ "useful context after it"
    end

    test "direct selection strips the explain command and puts containing text first" do
      {graph_id, containing_node, _question_node} = setup_context_graph()
      child = child_vertex("direct-selection")

      assert {:ok, _job} =
               LlmInterface.gen_selection_response(
                 containing_node,
                 child,
                 graph_id,
                 "Please explain: selected phrase",
                 "topic"
               )

      expected_prompt =
        Prompts.selection("Containing node text\n\nAncestor context", "selected phrase")

      assert_enqueued(
        worker: LocalWorker,
        args: %{
          "question" => expected_prompt,
          "to_node" => child.id,
          "graph" => graph_id
        }
      )
    end

    test "thinking tools and related ideas put containing text before ancestors" do
      {graph_id, containing_node, _question_node} = setup_context_graph()
      clarify_child = child_vertex("clarify-selection")
      ideas_child = child_vertex("ideas-selection")

      assert {:ok, _job} =
               LlmInterface.gen_clarify(
                 containing_node,
                 clarify_child,
                 graph_id,
                 "topic",
                 "selected phrase"
               )

      assert {:ok, _job} =
               LlmInterface.gen_related_ideas(
                 containing_node,
                 ideas_child,
                 graph_id,
                 "topic",
                 "selected phrase"
               )

      context = "Containing node text\n\nAncestor context"

      assert_enqueued(
        worker: LocalWorker,
        args: %{
          "question" => Prompts.clarify_selection(context, "selected phrase"),
          "to_node" => clarify_child.id,
          "graph" => graph_id
        }
      )

      assert_enqueued(
        worker: LocalWorker,
        args: %{
          "question" => Prompts.related_ideas_selection(context, "selected phrase"),
          "to_node" => ideas_child.id,
          "graph" => graph_id
        }
      )
    end
  end

  defp setup_context_graph(
         question_content \\ "Placeholder question",
         source_text \\ nil,
         prompt_kind \\ nil,
         containing_content \\ "Containing node text"
       ) do
    graph_id = "LLM context #{System.unique_integer([:positive])}"

    Dialectic.GraphFixtures.insert_graph(%{
      title: graph_id,
      data: %{
        "nodes" => [
          graph_node("1", "Ancestor context", "origin"),
          graph_node("2", containing_content, "answer"),
          graph_node("3", question_content, "question", source_text, prompt_kind)
        ],
        "edges" => [
          %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
          %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}}
        ]
      }
    })

    GraphManager.get_graph(graph_id)
    graph_manager = :global.whereis_name({:graph, graph_id})

    on_exit(fn ->
      if is_pid(graph_manager) and Process.alive?(graph_manager) do
        DynamicSupervisor.terminate_child(GraphSupervisor, graph_manager)
      end
    end)

    {
      graph_id,
      GraphManager.find_node_by_id(graph_id, "2"),
      GraphManager.find_node_by_id(graph_id, "3")
    }
  end

  defp graph_node(id, content, class, source_text \\ nil, prompt_kind \\ nil) do
    %{
      "id" => id,
      "content" => content,
      "class" => class,
      "user" => nil,
      "parent" => nil,
      "noted_by" => [],
      "deleted" => false,
      "compound" => false,
      "source_text" => source_text,
      "prompt_kind" => prompt_kind
    }
  end

  defp child_vertex(label) do
    %Vertex{
      id: "#{label}-#{System.unique_integer([:positive])}",
      class: "answer",
      user: "tester@example.com"
    }
  end
end
