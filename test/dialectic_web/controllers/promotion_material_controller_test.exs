defmodule DialecticWeb.PromotionMaterialControllerTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures

  alias Dialectic.Content.PromotionMaterial
  alias Dialectic.Highlights

  test "returns promotion material for a public grid without auth", %{conn: conn} do
    graph = promotion_graph("AI Tutors Promotion Grid")
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "2",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 23,
        selected_text_snapshot: "AI tutors can personalize feedback at scale.",
        created_by_user_id: user.id
      })

    conn =
      get(
        conn,
        ~p"/api/promotion/grids/#{graph.slug}/materials",
        %{
          "platforms" => "x,linkedin",
          "utm_campaign" => "weekly_topic"
        }
      )

    response = json_response(conn, 200)

    assert response["grid"]["title"] == graph.title
    assert response["grid"]["slug"] == graph.slug
    assert response["grid"]["url"] =~ "/g/#{graph.slug}"
    assert response["raw"]["origin_question"] == "Should AI tutors teach critical thinking?"

    assert response["raw"]["follow_up_questions"] == [
             "What evidence shows AI tutors improve transfer?",
             "When does help become dependency?",
             "How should teachers audit generated explanations?"
           ]

    assert [%{"id" => highlight_id}] = response["raw"]["highlights"]
    assert highlight_id == highlight.id

    assert Enum.map(response["raw"]["key_questions"], & &1["source"]) == [
             "first_answer_follow_up",
             "first_answer_follow_up",
             "first_answer_follow_up",
             "user_question"
           ]

    assert Enum.map(response["raw"]["key_questions"], & &1["question"]) == [
             "What evidence shows AI tutors improve transfer?",
             "When does help become dependency?",
             "How should teachers audit generated explanations?",
             "What classroom evidence would change your mind about whether AI tutors actually improve independent critical thinking over a full school year?"
           ]

    asset_kinds = Enum.map(response["assets"], & &1["kind"])
    assert "grid_card" in asset_kinds
    assert "highlight_card" in asset_kinds
    assert "key_question_card" in asset_kinds

    key_question_assets = Enum.filter(response["assets"], &(&1["kind"] == "key_question_card"))
    assert length(key_question_assets) == 4

    assert Enum.any?(key_question_assets, fn asset ->
             asset["source"] == "first_answer_follow_up" and
               asset["url"] =~ "/g/#{graph.slug}/follow-up-card.svg" and
               asset["url"] =~ "question=" and
               asset["image_svg_url"] == asset["url"] and
               asset["preview_url"] == asset["url"]
           end)

    assert Enum.any?(key_question_assets, fn asset ->
             asset["source"] == "user_question" and
               asset["node_id"] == "4" and
               asset["question"] ==
                 "What classroom evidence would change your mind about whether AI tutors actually improve independent critical thinking over a full school year?"
           end)

    assert Enum.map(response["posts"], & &1["platform"]) == ["x", "linkedin"]
    assert response["posts"] |> List.first() |> Map.fetch!("body") =~ "utm_campaign=weekly_topic"
    assert response["posts"] |> List.first() |> Map.fetch!("body") =~ "What evidence shows"
  end

  test "builder returns all sections by default" do
    graph = promotion_graph("Default Include Promotion Grid")

    response = PromotionMaterial.build(graph)

    assert Map.has_key?(response, "grid")
    assert Map.has_key?(response, "raw")
    assert Map.has_key?(response, "assets")
    assert Map.has_key?(response, "posts")
  end

  test "respects include filters", %{conn: conn} do
    graph = promotion_graph("Raw Only Promotion Grid")

    conn = get(conn, ~p"/api/promotion/grids/#{graph.slug}/materials", %{"include" => "grid,raw"})

    response = json_response(conn, 200)

    assert Map.has_key?(response, "grid")
    assert Map.has_key?(response, "raw")
    refute Map.has_key?(response, "assets")
    refute Map.has_key?(response, "posts")
  end

  test "returns 404 for unknown or non-public grids", %{conn: conn} do
    private_graph = promotion_graph("Private Promotion Grid", is_public: false)

    assert %{"error" => "Grid not found"} =
             get(conn, ~p"/api/promotion/grids/missing/materials") |> json_response(404)

    conn = recycle(conn)

    assert %{"error" => "Grid not found"} =
             get(conn, ~p"/api/promotion/grids/#{private_graph.slug}/materials")
             |> json_response(404)
  end

  defp promotion_graph(title, attrs \\ []) do
    insert_graph(
      Map.merge(
        %{
          title: title,
          is_public: true,
          is_published: true,
          data: %{
            "nodes" => [
              %{
                "id" => "1",
                "content" => "## Should AI tutors teach critical thinking?",
                "class" => "origin",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "2",
                "content" =>
                  "AI tutors can personalize feedback at scale.\n\n## Follow-up questions\n1. What evidence shows AI tutors improve transfer?\n2. When does help become dependency?\n3. How should teachers audit generated explanations?",
                "class" => "answer",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "3",
                "content" => "Students may outsource the productive struggle of learning.",
                "class" => "antithesis",
                "deleted" => false,
                "compound" => false
              },
              %{
                "id" => "4",
                "content" =>
                  "What classroom evidence would change your mind about whether AI tutors actually improve independent critical thinking over a full school year?",
                "class" => "question",
                "deleted" => false,
                "compound" => false
              }
            ],
            "edges" => []
          }
        },
        Map.new(attrs)
      )
    )
  end
end
