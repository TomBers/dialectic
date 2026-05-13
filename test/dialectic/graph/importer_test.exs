defmodule Dialectic.Graph.ImporterTest do
  use Dialectic.DataCase, async: true

  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Importer

  defp unique_title(prefix \\ "Imported Graph") do
    "#{prefix} #{System.unique_integer([:positive])}"
  end

  defp valid_node(id, attrs \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "content" => "Node #{id}",
        "class" => "origin",
        "user" => "",
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      },
      attrs
    )
  end

  defp valid_graph do
    %{
      "nodes" => [
        valid_node("1", %{"content" => "Root"}),
        valid_node("2", %{"content" => "Child", "class" => "premise"})
      ],
      "edges" => [
        %{"data" => %{"id" => "e1-2", "source" => "1", "target" => "2"}}
      ]
    }
  end

  defp write_json!(data) do
    path =
      Path.join(System.tmp_dir!(), "graph-importer-#{System.unique_integer([:positive])}.json")

    File.write!(path, Jason.encode!(data))
    on_exit(fn -> File.rm(path) end)
    path
  end

  describe "validate_data/1" do
    test "accepts a valid graph" do
      assert :ok = Importer.validate_data(valid_graph())
    end

    test "returns an error for non-map nodes instead of raising" do
      graph = %{valid_graph() | "nodes" => ["not-a-node"]}

      assert {:error, "Every node must be an object."} = Importer.validate_data(graph)
    end

    test "returns an error for missing node keys" do
      graph = %{valid_graph() | "nodes" => [Map.delete(valid_node("1"), "content")]}

      assert {:error, message} = Importer.validate_data(graph)
      assert message =~ "Every node must include"
    end

    test "returns an error for duplicate node ids" do
      graph = %{valid_graph() | "nodes" => [valid_node("1"), valid_node("1")]}

      assert {:error, "Node ids must be unique."} = Importer.validate_data(graph)
    end

    test "returns an error for invalid edge endpoints" do
      graph = %{
        valid_graph()
        | "edges" => [%{"data" => %{"id" => "bad", "source" => "1", "target" => "missing"}}]
      }

      assert {:error,
              "Every edge must have data.source and data.target matching existing node ids."} =
               Importer.validate_data(graph)
    end

    test "returns an error for malformed edge shape" do
      graph = %{valid_graph() | "edges" => [%{"source" => "1", "target" => "2"}]}

      assert {:error,
              "Every edge must have data.source and data.target matching existing node ids."} =
               Importer.validate_data(graph)
    end
  end

  describe "import_data/2" do
    test "inserts a raw graph and normalizes unsupported prompt modes" do
      title = unique_title()

      assert {:ok, %Graph{} = graph} =
               Importer.import_data(valid_graph(), %{
                 title: title,
                 tags: ["philosophy", " leisure "],
                 is_public: true,
                 is_published: true,
                 prompt_mode: "essay"
               })

      assert graph.title == title
      assert graph.prompt_mode == "university"
      assert graph.tags == ["philosophy", "leisure"]
      assert graph.is_public
      assert graph.is_published
      assert length(graph.data["nodes"]) == 2
      assert length(graph.data["edges"]) == 1
      assert is_binary(graph.share_token)
    end

    test "updates an existing graph while preserving share token" do
      title = unique_title()
      {:ok, inserted} = Importer.import_data(valid_graph(), %{title: title})

      updated_graph = %{
        "nodes" => [valid_node("1", %{"content" => "Updated"})],
        "edges" => []
      }

      assert {:ok, updated} =
               Importer.import_data(updated_graph, %{
                 title: title,
                 tags: ["updated"],
                 is_public: false,
                 prompt_mode: "simple"
               })

      assert updated.title == title
      assert updated.share_token == inserted.share_token
      assert updated.tags == ["updated"]
      refute updated.is_public
      assert updated.prompt_mode == "simple"
      assert [%{"content" => "Updated"}] = updated.data["nodes"]
    end
  end

  describe "import_file/2" do
    test "imports raw graph JSON from file" do
      title = unique_title("Raw File")
      path = write_json!(valid_graph())

      assert {:ok, graph} = Importer.import_file(path, title: title, prompt_mode: "high_school")

      assert graph.title == title
      assert graph.prompt_mode == "high_school"
    end

    test "imports artifact JSON from file using metadata" do
      title = unique_title("Artifact File")

      path =
        write_json!(%{
          "metadata" => %{
            "title" => title,
            "slug" => "artifact-file-#{System.unique_integer([:positive])}",
            "tags" => ["artifact", "import"],
            "is_public" => true,
            "is_published" => true,
            "prompt_mode" => "creative"
          },
          "graph" => valid_graph()
        })

      assert {:ok, graph} = Importer.import_file(path)

      assert graph.title == title
      assert graph.tags == ["artifact", "import"]
      assert graph.prompt_mode == "university"
      assert graph.is_public
      assert graph.is_published
    end

    test "returns an error for invalid JSON" do
      path =
        Path.join(
          System.tmp_dir!(),
          "graph-importer-bad-#{System.unique_integer([:positive])}.json"
        )

      File.write!(path, "not-json")
      on_exit(fn -> File.rm(path) end)

      assert {:error, message} = Importer.import_file(path, title: unique_title())
      assert message =~ "Invalid JSON"
    end
  end
end
