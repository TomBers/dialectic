defmodule Dialectic.Graph.ExtractorTest do
  use DialecticWeb.ConnCase, async: true
  alias Dialectic.Graph.Extractor
  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs

  describe "extract_for_image_generation/1 with Graph struct" do
    test "extracts basic graph with nodes and edges" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Root question",
              "class" => "origin",
              "deleted" => false
            },
            %{
              "id" => "2",
              "content" => "First answer",
              "class" => "answer",
              "deleted" => false
            }
          ],
          "edges" => [
            %{
              "data" => %{
                "source" => "1",
                "target" => "2"
              }
            }
          ]
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: nodes, edges: edges} = result
      assert length(nodes) == 2
      assert length(edges) == 1

      assert %{id: "1", content: "Root question", class: "origin"} in nodes
      assert %{id: "2", content: "First answer", class: "answer"} in nodes
      assert %{from: "1", to: "2"} in edges
    end

    test "filters out deleted nodes" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Active node",
              "class" => "origin",
              "deleted" => false
            },
            %{
              "id" => "2",
              "content" => "Deleted node",
              "class" => "answer",
              "deleted" => true
            },
            %{
              "id" => "3",
              "content" => "Another active",
              "class" => "premise",
              "deleted" => false
            }
          ],
          "edges" => [
            %{
              "data" => %{
                "source" => "1",
                "target" => "2"
              }
            },
            %{
              "data" => %{
                "source" => "1",
                "target" => "3"
              }
            }
          ]
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: nodes, edges: edges} = result
      assert length(nodes) == 2
      # Only edge to node 3 should remain
      assert length(edges) == 1
      assert %{from: "1", to: "3"} in edges
      refute Enum.any?(nodes, fn n -> n.id == "2" end)
    end

    test "includes parent field for grouped nodes" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Root",
              "class" => "origin",
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
              "content" => "Child in group",
              "class" => "answer",
              "parent" => "group-1",
              "deleted" => false
            }
          ],
          "edges" => []
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: nodes} = result
      child_node = Enum.find(nodes, fn n -> n.id == "2" end)
      assert child_node.parent == "group-1"

      group_node = Enum.find(nodes, fn n -> n.id == "group-1" end)
      assert group_node.compound == true
    end

    test "excludes parent field when not set" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "No parent",
              "class" => "origin",
              "parent" => nil,
              "deleted" => false
            },
            %{
              "id" => "2",
              "content" => "Empty parent",
              "class" => "answer",
              "parent" => "",
              "deleted" => false
            }
          ],
          "edges" => []
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: nodes} = result

      Enum.each(nodes, fn node ->
        refute Map.has_key?(node, :parent)
      end)
    end

    test "handles empty graph" do
      graph = %Graph{
        title: "Empty Graph",
        data: %{
          "nodes" => [],
          "edges" => []
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: [], edges: []} = result
    end

    test "handles graph with missing edges" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Single node",
              "class" => "origin",
              "deleted" => false
            }
          ]
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: [%{id: "1"}], edges: []} = result
    end

    test "filters edges with invalid source or target" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Node 1",
              "class" => "origin",
              "deleted" => false
            },
            %{
              "id" => "2",
              "content" => "Node 2",
              "class" => "answer",
              "deleted" => false
            }
          ],
          "edges" => [
            %{
              "data" => %{
                "source" => "1",
                "target" => "2"
              }
            },
            %{
              "data" => %{
                "source" => "1",
                "target" => "999"
              }
            },
            %{
              "data" => %{
                "source" => "999",
                "target" => "2"
              }
            }
          ]
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{edges: edges} = result
      assert length(edges) == 1
      assert %{from: "1", to: "2"} in edges
    end
  end

  describe "extract_for_image_generation/1 with string identifier" do
    setup do
      user = Dialectic.AccountsFixtures.user_fixture()
      {:ok, graph} = Graphs.create_new_graph("Test Extraction Graph", user)

      # Update with some test data
      test_data = %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "Test content",
            "class" => "origin",
            "deleted" => false
          }
        ],
        "edges" => []
      }

      Graphs.save_graph(graph.title, test_data)

      updated_graph = Graphs.get_graph_by_title(graph.title)
      {:ok, graph: updated_graph}
    end

    test "extracts graph by title", %{graph: graph} do
      result = Extractor.extract_for_image_generation(graph.title)

      assert {:ok, %{nodes: nodes, edges: _edges}} = result
      assert length(nodes) == 1
    end

    test "extracts graph by slug", %{graph: graph} do
      result = Extractor.extract_for_image_generation(graph.slug)

      assert {:ok, %{nodes: nodes, edges: _edges}} = result
      assert length(nodes) == 1
    end

    test "returns error for non-existent graph" do
      result = Extractor.extract_for_image_generation("non-existent-graph-12345")

      assert {:error, :not_found} = result
    end
  end

  describe "extract_to_json/1" do
    test "returns pretty-printed JSON string" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Test",
              "class" => "origin",
              "deleted" => false
            }
          ],
          "edges" => []
        }
      }

      {:ok, json_string} = Extractor.extract_to_json(graph)

      assert is_binary(json_string)
      assert String.contains?(json_string, "\n")

      decoded = Jason.decode!(json_string)
      assert %{"nodes" => [%{"id" => "1"}], "edges" => []} = decoded
    end

    test "returns error tuple for string identifier when not found" do
      result = Extractor.extract_to_json("non-existent")

      assert {:error, :not_found} = result
    end
  end

  describe "extract_to_compact_json/1" do
    test "returns compact JSON string without whitespace" do
      graph = %Graph{
        title: "Test Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Test",
              "class" => "origin",
              "deleted" => false
            }
          ],
          "edges" => []
        }
      }

      {:ok, json_string} = Extractor.extract_to_compact_json(graph)

      assert is_binary(json_string)
      refute String.contains?(json_string, "\n  ")

      decoded = Jason.decode!(json_string)
      assert %{"nodes" => [%{"id" => "1"}], "edges" => []} = decoded
    end
  end

  describe "complex graph structure" do
    test "handles graph with multiple node types and hierarchies" do
      graph = %Graph{
        title: "Complex Graph",
        data: %{
          "nodes" => [
            %{
              "id" => "1",
              "content" => "Original question",
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
              "content" => "Thesis",
              "class" => "thesis",
              "deleted" => false
            },
            %{
              "id" => "4",
              "content" => "Antithesis",
              "class" => "antithesis",
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
              "id" => "5",
              "content" => "Synthesis",
              "class" => "synthesis",
              "parent" => "group-1",
              "deleted" => false
            },
            %{
              "id" => "6",
              "content" => "Deleted node",
              "class" => "premise",
              "deleted" => true
            }
          ],
          "edges" => [
            %{"data" => %{"source" => "1", "target" => "2"}},
            %{"data" => %{"source" => "2", "target" => "3"}},
            %{"data" => %{"source" => "2", "target" => "4"}},
            %{"data" => %{"source" => "3", "target" => "5"}},
            %{"data" => %{"source" => "4", "target" => "5"}},
            %{"data" => %{"source" => "5", "target" => "6"}}
          ]
        }
      }

      {:ok, result} = Extractor.extract_for_image_generation(graph)

      assert %{nodes: nodes, edges: edges} = result

      # Should have 6 nodes (excluding deleted node)
      assert length(nodes) == 6

      # Should exclude edge to deleted node
      assert length(edges) == 5

      # Verify node types are preserved
      assert Enum.any?(nodes, fn n -> n.class == "question" end)
      assert Enum.any?(nodes, fn n -> n.class == "thesis" end)
      assert Enum.any?(nodes, fn n -> n.class == "synthesis" end)

      # Verify grouped node has parent
      synthesis = Enum.find(nodes, fn n -> n.id == "5" end)
      assert synthesis.parent == "group-1"

      # Verify compound node is marked
      group = Enum.find(nodes, fn n -> n.id == "group-1" end)
      assert group.compound == true
    end
  end
end
