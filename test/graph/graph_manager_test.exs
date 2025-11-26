defmodule GraphManagerTest do
  use DialecticWeb.ConnCase, async: false
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  @graph_id "TestGraph"
  @test_user "test_user"

  setup do
    # Ensure graph is removed from registry before each test
    GraphManager.reset_graph(@graph_id)
    Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)
    :ok
  end

  describe "process management" do
    test "creates new graph process when doesn't exist" do
      # refute GraphManager.exists?(@graph_id)
      graph = GraphManager.get_graph(@graph_id)
      assert GraphManager.exists?(@graph_id)
      assert graph == GraphManager.get_graph(@graph_id)
    end

    test "reuses existing graph process" do
      graph1 = GraphManager.get_graph(@graph_id)
      graph2 = GraphManager.get_graph(@graph_id)
      assert graph1 == graph2
    end

    test "registry properly tracks graph processes" do
      # refute GraphManager.exists?(@graph_id)
      GraphManager.get_graph(@graph_id)
      assert GraphManager.exists?(@graph_id)

      pid = :global.whereis_name({:graph, @graph_id})
      assert Process.alive?(pid)
    end
  end

  describe "graph operations" do
    setup do
      graph = GraphManager.get_graph(@graph_id)
      {:ok, graph: graph}
    end

    test "add_node creates vertex with correct properties", %{graph: _} do
      vertex = %Vertex{content: "test content", class: "test", user: @test_user}
      new_vertex = GraphManager.add_node(@graph_id, vertex)

      assert new_vertex.id == "1"
      assert new_vertex.content == "test content"
      assert new_vertex.class == "test"
      assert new_vertex.user == @test_user
    end

    test "add_edges connects vertices properly", %{graph: _} do
      # Create parent node
      parent =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Create child node
      child =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "child",
          class: "test",
          user: @test_user
        })

      # Add edge
      updated_child = GraphManager.add_edges(@graph_id, child, [parent])
      {_, updated_graph} = GraphManager.get_graph(@graph_id)

      # Verify edge exists
      edges = :digraph.edges(updated_graph)
      assert length(edges) == 1

      # Verify parent-child relationship
      [edge] = edges
      {_, v1, v2, _} = :digraph.edge(updated_graph, edge)
      assert v1 == parent.id
      assert v2 == child.id

      # Verify child's parents list is updated
      assert length(updated_child.parents) == 1
      [parent_in_list] = updated_child.parents
      assert parent_in_list.id == parent.id
    end

    test "find_node_by_id returns correct node", %{graph: _} do
      # Add a node
      vertex =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "test",
          class: "test",
          user: @test_user
        })

      # Find the node
      found_vertex = GraphManager.find_node_by_id(@graph_id, vertex.id)

      assert found_vertex.id == vertex.id
      assert found_vertex.content == vertex.content
    end

    test "find_node_by_id returns nil for non-existent node", %{graph: _} do
      result = GraphManager.find_node_by_id(@graph_id, "non-existent")
      assert result == nil
    end

    test "add_child creates connected nodes properly", %{graph: _} do
      # Create parent
      parent =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Add child using add_child
      child =
        GraphManager.add_child(
          @graph_id,
          [parent],
          fn n -> LlmInterface.ask_model("child content", "SYSTEM", n, @graph_id, nil) end,
          "child_class",
          @test_user
        )

      # Verify node properties
      # assert child.content == "child content"
      # TODO - How to test the streaming function?
      assert child.content == ""
      assert child.class == "child_class"
      assert child.user == @test_user

      # Verify edge exists
      {_, updated_graph} = GraphManager.get_graph(@graph_id)
      edges = :digraph.edges(updated_graph)
      assert length(edges) == 1

      # Verify parent-child relationship
      [edge] = edges
      {_, v1, v2, _} = :digraph.edge(updated_graph, edge)
      assert v1 == parent.id
      assert v2 == child.id
    end

    test "reset_graph clears all vertices and edges", %{graph: _} do
      # Add some nodes and edges
      parent =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      _child =
        GraphManager.add_child(
          @graph_id,
          [parent],
          fn n -> LlmInterface.ask_model("child content", "SYSTEM", n, @graph_id, nil) end,
          "child_class",
          @test_user
        )

      # Verify nodes and edges exist
      {_, graph_with_nodes} = GraphManager.get_graph(@graph_id)
      assert length(:digraph.vertices(graph_with_nodes)) > 0
      assert length(:digraph.edges(graph_with_nodes)) > 0

      # Reset graph
      GraphManager.reset_graph(@graph_id)

      # Get fresh graph
      {graph_struct, fresh_graph} = GraphManager.get_graph(@graph_id)

      assert graph_struct.title == @graph_id
      assert graph_struct.is_public == true
      assert graph_struct.is_deleted == false
      assert graph_struct.is_published == true
      assert graph_struct.is_locked == false

      # Verify graph is empty
      assert length(:digraph.vertices(fresh_graph)) == 0
      assert length(:digraph.edges(fresh_graph)) == 0
    end

    test "multiple children maintain correct relationships", %{graph: _} do
      # Create parent
      parent =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Add multiple children
      child1 =
        GraphManager.add_child(
          @graph_id,
          [parent],
          fn n -> LlmInterface.ask_model("child content", "SYSTEM", n, @graph_id, nil) end,
          "test",
          @test_user
        )

      child2 =
        GraphManager.add_child(
          @graph_id,
          [parent],
          fn n -> LlmInterface.ask_model("child content", "SYSTEM", n, @graph_id, nil) end,
          "test",
          @test_user
        )

      # Verify all nodes exist
      {_, graph2} = GraphManager.get_graph(@graph_id)
      vertices = :digraph.vertices(graph2)
      assert length(vertices) == 3

      # Verify edges
      edges = :digraph.edges(graph2)
      assert length(edges) == 2

      # Verify both children have the same parent
      updated_child1 = GraphManager.find_node_by_id(@graph_id, child1.id)
      updated_child2 = GraphManager.find_node_by_id(@graph_id, child2.id)

      assert length(updated_child1.parents) == 1
      assert length(updated_child2.parents) == 1
      assert hd(updated_child1.parents).id == parent.id
      assert hd(updated_child2.parents).id == parent.id
    end

    test "child nodes inherit parent group membership", %{graph: _} do
      # Create a group node
      group_title = "test_group"

      # Create a node that will be part of the group
      parent =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "parent in group",
          class: "test",
          user: @test_user
        })

      # Add the node to a group
      GraphManager.create_group(@graph_id, group_title, [parent.id])

      # Refresh parent node to get updated parent field
      updated_parent = GraphManager.find_node_by_id(@graph_id, parent.id)
      assert updated_parent.parent == group_title

      # Create a child node from the parent (should inherit group)
      child =
        GraphManager.add_child(
          @graph_id,
          [updated_parent],
          fn _ -> "child content" end,
          "test",
          @test_user
        )

      # Verify child inherits parent's group
      updated_child = GraphManager.find_node_by_id(@graph_id, child.id)
      assert updated_child.parent == group_title

      # Create a node not in any group
      standalone =
        GraphManager.add_node(@graph_id, %Vertex{
          content: "standalone",
          class: "test",
          user: @test_user
        })

      # Create a child from both a grouped and non-grouped parent
      mixed_child =
        GraphManager.add_child(
          @graph_id,
          [updated_parent, standalone],
          fn _ -> "mixed parentage" end,
          "test",
          @test_user
        )

      # Child should still be part of the group (inherits from at least one parent)
      updated_mixed_child = GraphManager.find_node_by_id(@graph_id, mixed_child.id)
      assert updated_mixed_child.parent == group_title
    end
  end

  test "supervisor handles process termination" do
    # Start a graph
    GraphManager.get_graph(@graph_id)
    assert GraphManager.exists?(@graph_id)

    # Get the PID
    pid = :global.whereis_name({:graph, @graph_id})

    # Kill the process
    Process.exit(pid, :kill)

    # Wait a brief moment for the supervisor to restart
    Process.sleep(100)

    # Verify the process was restarted
    assert GraphManager.exists?(@graph_id)
    new_pid = :global.whereis_name({:graph, @graph_id})
    assert new_pid != pid
  end
end
