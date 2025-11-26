defmodule Dialectic.DbActions.GraphsTest do
  use DialecticWeb.ConnCase, async: false

  alias Dialectic.DbActions.Graphs
  alias Dialectic.Accounts.Graph
  alias Dialectic.Repo
  alias Dialectic.Graph.Vertex

  import Dialectic.AccountsFixtures

  defp unique_title(prefix \\ "graph") do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end

  defp insert_graph!(title, user \\ nil) do
    {:ok, graph} = Graphs.create_new_graph(title, user)
    graph
  end

  describe "create_new_graph/2" do
    test "creates a graph with defaults and an origin node" do
      title = unique_title()
      {:ok, graph} = Graphs.create_new_graph(title)

      assert %Graph{title: ^title} = graph
      assert graph.is_public == true
      assert graph.is_locked == false
      assert graph.is_deleted == false
      assert graph.is_published == true

      nodes = graph.data["nodes"]
      assert is_list(nodes)
      assert length(nodes) == 1

      first_node = hd(nodes)
      assert %Vertex{} = first_node
      assert first_node.class == "origin"
      assert first_node.content == "## " <> title
    end

    test "sets user_id when a user is provided" do
      user = user_fixture()
      title = unique_title("with-user")
      {:ok, graph} = Graphs.create_new_graph(title, user)
      assert graph.user_id == user.id
    end
  end

  describe "get_graph_by_title/1" do
    test "returns the graph when it exists" do
      title = unique_title("get")
      insert_graph!(title)
      assert %Graph{title: ^title} = Graphs.get_graph_by_title(title)
    end

    test "returns nil when the graph does not exist" do
      refute Graphs.get_graph_by_title("no-such-title-#{System.unique_integer([:positive])}")
    end
  end

  describe "save_graph/2" do
    test "updates data for an existing graph" do
      title = unique_title("save")
      insert_graph!(title)

      new_data = %{"nodes" => [], "edges" => []}
      assert {:ok, %Graph{} = updated} = Graphs.save_graph(title, new_data)
      assert updated.data == new_data
    end

    test "returns {:error, :not_found} when graph is missing" do
      assert {:error, :not_found} =
               Graphs.save_graph("missing-#{System.unique_integer([:positive])}", %{})
    end
  end

  describe "toggle_graph_locked/1" do
    test "flips is_locked flag" do
      title = unique_title("toggle-lock")
      graph = insert_graph!(title)
      assert graph.is_locked == false

      updated = Graphs.toggle_graph_locked(graph)
      assert updated.is_locked

      # Flip back for completeness
      updated_again = Graphs.toggle_graph_locked(updated)
      refute updated_again.is_locked
    end
  end

  describe "toggle_graph_public/1" do
    test "flips is_public flag" do
      title = unique_title("toggle-public")
      graph = insert_graph!(title)
      assert graph.is_public == true

      updated = Graphs.toggle_graph_public(graph)
      refute updated.is_public

      updated_again = Graphs.toggle_graph_public(updated)
      assert updated_again.is_public
    end
  end

  describe "list_graphs/0" do
    test "returns all graphs" do
      title1 = unique_title("list-a")
      title2 = unique_title("list-b")
      g1 = insert_graph!(title1)
      g2 = insert_graph!(title2)

      titles =
        Graphs.list_graphs()
        |> Enum.map(& &1.title)

      assert title1 in titles
      assert title2 in titles
      # basic sanity
      assert Enum.any?(titles)
      assert Enum.uniq(titles) == titles
      assert Enum.member?(titles, g1.title)
      assert Enum.member?(titles, g2.title)
    end
  end

  describe "all_graphs_with_notes/1" do
    test "returns only published graphs with counts and supports search filtering" do
      # Create two published graphs
      pub_title1 = unique_title("pub-one")
      pub_title2 = unique_title("pub-two")
      g1 = insert_graph!(pub_title1)
      g2 = insert_graph!(pub_title2)

      # Create an unpublished graph (should be excluded)
      unpub_title = unique_title("unpub")

      {:ok, _unpub} =
        %Graph{}
        |> Graph.changeset(%{
          title: unpub_title,
          data: %{
            "nodes" => [%Vertex{id: "1", content: "## " <> unpub_title, class: "origin"}],
            "edges" => []
          },
          is_public: true,
          is_locked: false,
          is_deleted: false,
          is_published: false
        })
        |> Repo.insert()

      # 1) No search term: should include only published graphs and counts should be 0
      results = Graphs.all_graphs_with_notes("")
      result_titles = Enum.map(results, fn {g, _count} -> g.title end)

      assert g1.title in result_titles
      assert g2.title in result_titles
      refute unpub_title in result_titles

      Enum.each(results, fn {_g, count} -> assert count == 0 end)

      # 2) Search term matches only one of the published graphs
      only_one =
        Graphs.all_graphs_with_notes("pub-one")
        |> Enum.map(fn {g, c} -> {g.title, c} end)

      assert only_one == [{pub_title1, 0}]
    end

    test "excludes private graphs" do
      public_title = unique_title("public-graph")
      private_title = unique_title("private-graph")

      insert_graph!(public_title)

      # Insert private graph
      {:ok, _private} =
        %Graph{}
        |> Graph.changeset(%{
          title: private_title,
          data: %{
            "nodes" => [%Vertex{id: "1", content: "## " <> private_title, class: "origin"}],
            "edges" => []
          },
          is_public: false,
          is_published: true,
          is_locked: false,
          is_deleted: false
        })
        |> Repo.insert()

      results = Graphs.all_graphs_with_notes("")
      result_titles = Enum.map(results, fn {g, _count} -> g.title end)

      assert public_title in result_titles
      refute private_title in result_titles
    end
  end
end
