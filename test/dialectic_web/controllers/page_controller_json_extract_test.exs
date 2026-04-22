defmodule DialecticWeb.PageControllerJsonExtractTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.DbActions.Graphs
  alias Dialectic.AccountsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    other_user = AccountsFixtures.user_fixture()

    {:ok, public_graph} = Graphs.create_new_graph("Public Test Graph", user)

    # Update with test data
    test_data = %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "Root question",
          "class" => "question",
          "deleted" => false
        },
        %{
          "id" => "2",
          "content" => "First answer",
          "class" => "answer",
          "deleted" => false
        },
        %{
          "id" => "3",
          "content" => "Deleted node",
          "class" => "premise",
          "deleted" => true
        }
      ],
      "edges" => [
        %{"data" => %{"source" => "1", "target" => "2"}},
        %{"data" => %{"source" => "2", "target" => "3"}}
      ]
    }

    Graphs.save_graph(public_graph.title, test_data)
    public_graph = Graphs.get_graph_by_title(public_graph.title)

    # Create private graph
    {:ok, private_graph} = Graphs.create_new_graph("Private Test Graph", user)

    private_graph =
      private_graph
      |> Dialectic.Accounts.Graph.changeset(%{is_public: false})
      |> Dialectic.Repo.update!()

    {:ok,
     user: user,
     other_user: other_user,
     public_graph: public_graph,
     private_graph: private_graph}
  end

  describe "GET /api/graphs/json/:graph_name" do
    test "returns JSON extract for public graph by slug", %{conn: conn, public_graph: graph} do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

      disposition = get_resp_header(conn, "content-disposition")
      assert disposition != []
      assert String.contains?(hd(disposition), "attachment")
      assert String.contains?(hd(disposition), ".json")

      json_response = Jason.decode!(response(conn, 200))

      assert %{"nodes" => nodes, "edges" => edges} = json_response
      assert is_list(nodes)
      assert is_list(edges)
      # Should have 2 nodes (deleted node filtered out)
      assert length(nodes) == 2
      # Should have 1 edge (edge to deleted node filtered out)
      assert length(edges) == 1

      # Verify node structure
      assert Enum.all?(nodes, fn node ->
               Map.has_key?(node, "id") &&
                 Map.has_key?(node, "content") &&
                 Map.has_key?(node, "class")
             end)

      # Verify edge structure
      assert Enum.all?(edges, fn edge ->
               Map.has_key?(edge, "from") && Map.has_key?(edge, "to")
             end)
    end

    test "returns JSON extract for public graph by title", %{conn: conn, public_graph: graph} do
      conn = get(conn, ~p"/api/graphs/json/#{URI.encode(graph.title)}")

      assert response(conn, 200)
      json_response = Jason.decode!(response(conn, 200))

      assert %{"nodes" => nodes, "edges" => _edges} = json_response
      assert length(nodes) == 2
    end

    test "filters out user metadata and internal fields", %{conn: conn, public_graph: graph} do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")
      json_response = Jason.decode!(response(conn, 200))

      # Verify that internal fields are not present
      nodes = json_response["nodes"]

      Enum.each(nodes, fn node ->
        refute Map.has_key?(node, "user")
        refute Map.has_key?(node, "noted_by")
        refute Map.has_key?(node, "source_text")
        refute Map.has_key?(node, "deleted")
      end)
    end

    test "returns 404 for non-existent graph", %{conn: conn} do
      conn = get(conn, ~p"/api/graphs/json/non-existent-graph-12345")

      assert response(conn, 404)
      json_response = Jason.decode!(response(conn, 404))
      assert %{"error" => "Grid not found"} = json_response
    end

    test "returns 403 for private graph without authentication", %{
      conn: conn,
      private_graph: graph
    } do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")

      assert response(conn, 403)
      json_response = Jason.decode!(response(conn, 403))
      assert %{"error" => _message} = json_response
    end

    test "returns JSON for private graph when authenticated as owner", %{
      conn: conn,
      user: user,
      private_graph: graph
    } do
      conn = log_in_user(conn, user)
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")

      assert response(conn, 200)
      json_response = Jason.decode!(response(conn, 200))
      assert %{"nodes" => _nodes, "edges" => _edges} = json_response
    end

    test "returns 403 for private graph when authenticated as different user", %{
      conn: conn,
      other_user: other_user,
      private_graph: graph
    } do
      conn = log_in_user(conn, other_user)
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")

      assert response(conn, 403)
    end

    test "returns JSON for private graph with valid share token", %{
      conn: conn,
      private_graph: graph
    } do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}?token=#{graph.share_token}")

      assert response(conn, 200)
      json_response = Jason.decode!(response(conn, 200))
      assert %{"nodes" => _nodes, "edges" => _edges} = json_response
    end

    test "returns 403 for private graph with invalid share token", %{
      conn: conn,
      private_graph: graph
    } do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}?token=invalid-token")

      assert response(conn, 403)
    end

    test "sets correct filename in content-disposition header", %{
      conn: conn,
      public_graph: graph
    } do
      conn = get(conn, ~p"/api/graphs/json/#{graph.slug}")

      disposition = get_resp_header(conn, "content-disposition")
      assert disposition != []
      assert String.contains?(hd(disposition), "#{graph.slug}.json")
    end

    test "sanitizes filename for graphs with special characters", %{conn: conn, user: user} do
      {:ok, special_graph} = Graphs.create_new_graph("Test / Graph: Special! Chars", user)

      conn = get(conn, ~p"/api/graphs/json/#{special_graph.slug}")

      assert response(conn, 200)
      disposition = get_resp_header(conn, "content-disposition")
      assert disposition != []

      # Filename should be sanitized
      filename = hd(disposition)
      refute String.contains?(filename, "/")
      refute String.contains?(filename, ":")
      refute String.contains?(filename, "!")
    end

    test "handles graphs with grouped nodes correctly", %{conn: conn, user: user} do
      {:ok, grouped_graph} = Graphs.create_new_graph("Grouped Test Graph", user)

      grouped_data = %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "Root",
            "class" => "question",
            "deleted" => false
          },
          %{
            "id" => "group-1",
            "content" => "",
            "class" => "",
            "compound" => true,
            "deleted" => false
          },
          %{
            "id" => "2",
            "content" => "Grouped node",
            "class" => "thesis",
            "parent" => "group-1",
            "deleted" => false
          }
        ],
        "edges" => [
          %{"data" => %{"source" => "1", "target" => "2"}}
        ]
      }

      Graphs.save_graph(grouped_graph.title, grouped_data)
      grouped_graph = Graphs.get_graph_by_title(grouped_graph.title)

      conn = get(conn, ~p"/api/graphs/json/#{grouped_graph.slug}")

      assert response(conn, 200)
      json_response = Jason.decode!(response(conn, 200))

      # Find the grouped node
      grouped_node =
        Enum.find(json_response["nodes"], fn n -> n["id"] == "2" end)

      assert grouped_node["parent"] == "group-1"

      # Find the compound node
      compound_node =
        Enum.find(json_response["nodes"], fn n -> n["id"] == "group-1" end)

      assert compound_node["compound"] == true
    end

    test "returns empty graph correctly", %{conn: conn, user: user} do
      {:ok, empty_graph} = Graphs.create_new_graph("Empty Test Graph", user)

      empty_data = %{
        "nodes" => [],
        "edges" => []
      }

      Graphs.save_graph(empty_graph.title, empty_data)
      empty_graph = Graphs.get_graph_by_title(empty_graph.title)

      conn = get(conn, ~p"/api/graphs/json/#{empty_graph.slug}")

      assert response(conn, 200)
      json_response = Jason.decode!(response(conn, 200))
      assert %{"nodes" => [], "edges" => []} = json_response
    end
  end
end
