defmodule Dialectic.ContentTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures

  alias Dialectic.Content
  alias Dialectic.Content.DraftGenerator
  alias Dialectic.GraphFixtures
  alias Dialectic.Highlights

  describe "content drafts" do
    test "creates, lists, and marks drafts as used" do
      graph = GraphFixtures.insert_graph(%{title: "Content Draft Graph"})
      user = user_fixture()

      {:ok, draft} =
        Content.create_draft(
          %{
            graph_title: graph.title,
            platform: "x",
            format: "short_post",
            title: "Question hook",
            body: "What perspective is missing?",
            status: "draft",
            utm_source: "x",
            utm_campaign: "content_studio",
            metadata: %{"post_type" => "question_hook"}
          },
          user
        )

      assert draft.created_by_id == user.id
      assert draft.graph_title == graph.title

      assert [listed] = Content.list_drafts(graph_title: graph.title)
      assert listed.id == draft.id
      assert listed.graph.title == graph.title

      {:ok, used} = Content.mark_draft_used(draft)
      assert used.status == "used"
      assert used.published_at
    end

    test "lists public candidate graphs and hides private graphs" do
      public_graph = GraphFixtures.insert_graph(%{title: "Public Content Candidate"})

      _private_graph =
        GraphFixtures.insert_graph(%{title: "Private Content Candidate", is_public: false})

      results = Content.list_candidate_graphs("Content Candidate")
      titles = Enum.map(results, fn {graph, _node_count, _author} -> graph.title end)

      assert public_graph.title in titles
      refute "Private Content Candidate" in titles
    end

    test "template generator uses highlights without an LLM" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "AI Tutors and Critical Thinking",
          data: %{
            "nodes" => [
              %{
                "id" => "1",
                "content" => "## Can AI tutors teach critical thinking?",
                "class" => "origin",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "2",
                "content" =>
                  "Personalized feedback can help students notice mistakes.\n\n## Follow-up questions\n1. What kinds of feedback build independence?\n2. When does assistance become dependence?\n3. How should teachers audit AI explanations?",
                "class" => "answer",
                "deleted" => false,
                "compound" => false
              }
            ],
            "edges" => []
          }
        })

      user = user_fixture()

      {:ok, _highlight} =
        Highlights.create_highlight(%{
          mudg_id: graph.title,
          node_id: "2",
          text_source_type: "node",
          selection_start: 0,
          selection_end: 21,
          selected_text_snapshot: "Personalized feedback can help students notice mistakes.",
          created_by_user_id: user.id
        })

      assert {:ok, drafts} =
               DraftGenerator.generate_pack(graph,
                 platforms: ["x", "linkedin", "substack"],
                 post_type: "quote_excerpt",
                 follow_up_questions: [
                   "What kinds of feedback build independence?",
                   "When does assistance become dependence?",
                   "How should teachers audit AI explanations?"
                 ],
                 url: "https://rationalgrid.com/g/ai-tutors",
                 utm_campaign: "test_campaign"
               )

      assert Enum.map(drafts, & &1.platform) == ["x", "linkedin", "substack"]
      assert Enum.all?(drafts, &(&1.metadata["source"] == "template"))

      x_body = drafts |> Enum.find(&(&1.platform == "x")) |> Map.fetch!(:body)
      linkedin_body = drafts |> Enum.find(&(&1.platform == "linkedin")) |> Map.fetch!(:body)
      substack_body = drafts |> Enum.find(&(&1.platform == "substack")) |> Map.fetch!(:body)

      assert x_body =~ "What kinds of feedback build independence?"
      assert x_body =~ "utm_source=x"
      assert linkedin_body =~ "The key follow-up questions are"
      assert linkedin_body =~ "When does assistance become dependence?"
      assert substack_body =~ "What kinds of feedback build independence?"
      assert substack_body =~ "Highlighted lines"
    end

    test "summarizes graph nodes without deleted or compound nodes" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Node Summary Candidate",
          data: %{
            "nodes" => [
              %{"id" => "1", "content" => "## Main Question", "class" => "origin"},
              %{"id" => "2", "content" => "A useful answer", "class" => "answer"},
              %{"id" => "3", "content" => "Hidden", "class" => "answer", "deleted" => true},
              %{"id" => "4", "content" => "Group", "class" => "origin", "compound" => true}
            ],
            "edges" => []
          }
        })

      nodes = Content.list_graph_nodes(graph)

      assert Enum.map(nodes, & &1.id) == ["1", "2"]
      assert hd(nodes).title == "Main Question"
    end
  end
end
