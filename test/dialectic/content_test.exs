defmodule Dialectic.ContentTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures

  alias Dialectic.Content
  alias Dialectic.Content.DraftGenerator
  alias Dialectic.GraphFixtures
  alias Dialectic.Highlights

  describe "promotion material" do
    test "lists public candidate graphs and hides private graphs" do
      public_graph = GraphFixtures.insert_graph(%{title: "Public Content Candidate"})

      _private_graph =
        GraphFixtures.insert_graph(%{title: "Private Content Candidate", is_public: false})

      results = Content.list_candidate_graphs("Content Candidate")
      titles = Enum.map(results, fn {graph, _node_count, _author} -> graph.title end)

      assert public_graph.title in titles
      refute "Private Content Candidate" in titles
    end

    test "candidate graph node count handles missing or non-array nodes" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Malformed Nodes Content Candidate",
          data: %{"nodes" => %{"not" => "a list"}, "edges" => []}
        })

      assert [{listed_graph, 0, _author}] = Content.list_candidate_graphs(graph.title)
      assert listed_graph.title == graph.title
    end

    test "template generator creates threads without optional sections" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Sparse Thread Candidate",
          data: %{
            "nodes" => [
              %{"id" => "1", "content" => "## What is wisdom?", "class" => "origin"}
            ],
            "edges" => []
          }
        })

      assert {:ok, [%{body: body}]} =
               DraftGenerator.generate_pack(graph,
                 platforms: ["threads"],
                 url: "https://rationalgrid.com/g/wisdom"
               )

      assert body =~ "1/ A question worth mapping"
      assert body =~ "2/ What perspective"
      refute body =~ "false"
    end

    test "template generator defaults to no platforms" do
      graph = GraphFixtures.insert_graph(%{title: "No Default Platforms"})

      assert {:ok, []} =
               DraftGenerator.generate_pack(graph,
                 url: "https://rationalgrid.com/g/no-default-platforms"
               )
    end

    test "template generator uses highlights and supplied follow-up questions without an LLM" do
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
                "content" => "Personalized feedback can help students notice mistakes.",
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

      assert {:ok, posts} =
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

      assert Enum.map(posts, & &1.platform) == ["x", "linkedin", "substack"]
      assert Enum.all?(posts, &(&1.metadata["source"] == "template"))

      x_body = posts |> Enum.find(&(&1.platform == "x")) |> Map.fetch!(:body)
      linkedin_body = posts |> Enum.find(&(&1.platform == "linkedin")) |> Map.fetch!(:body)
      substack_body = posts |> Enum.find(&(&1.platform == "substack")) |> Map.fetch!(:body)

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

      nodes =
        graph
        |> Content.graph_nodes()
        |> Enum.reject(&(Map.get(&1, "deleted") == true or Map.get(&1, "compound") == true))
        |> Enum.map(&Content.node_summary/1)
        |> Enum.sort_by(fn node -> {node.sort_class, node.title} end)

      assert Enum.map(nodes, & &1.id) == ["1", "2"]
      assert hd(nodes).title == "Main Question"
    end
  end
end
