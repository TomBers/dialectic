defmodule GraphManagerTest do
  use ExUnit.Case
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.LlmInterface

  @test_path "test_graph"
  @test_user "test_user"

  setup do
    # Ensure graph is removed from registry before each test
    GraphManager.reset_graph(@test_path)
    :ok
  end

  describe "process management" do
    test "creates new graph process when doesn't exist" do
      # refute GraphManager.exists?(@test_path)
      graph = GraphManager.get_graph(@test_path)
      assert GraphManager.exists?(@test_path)
      assert graph == GraphManager.get_graph(@test_path)
    end

    test "reuses existing graph process" do
      graph1 = GraphManager.get_graph(@test_path)
      graph2 = GraphManager.get_graph(@test_path)
      assert graph1 == graph2
    end

    test "registry properly tracks graph processes" do
      # refute GraphManager.exists?(@test_path)
      GraphManager.get_graph(@test_path)
      assert GraphManager.exists?(@test_path)

      [{pid, _}] = Registry.lookup(GraphRegistry, @test_path)
      assert Process.alive?(pid)
    end
  end

  describe "graph operations" do
    setup do
      graph = GraphManager.get_graph(@test_path)
      {:ok, graph: graph}
    end

    test "add_node creates vertex with correct properties", %{graph: _} do
      vertex = %Vertex{content: "test content", class: "test", user: @test_user}
      new_vertex = GraphManager.add_node(@test_path, vertex)

      assert new_vertex.id == "1"
      assert new_vertex.content == "test content"
      assert new_vertex.class == "test"
      assert new_vertex.user == @test_user
    end

    test "add_edges connects vertices properly", %{graph: _} do
      # Create parent node
      parent =
        GraphManager.add_node(@test_path, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Create child node
      child =
        GraphManager.add_node(@test_path, %Vertex{
          content: "child",
          class: "test",
          user: @test_user
        })

      # Add edge
      {updated_graph, updated_child} = GraphManager.add_edges(@test_path, child, [parent])

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
        GraphManager.add_node(@test_path, %Vertex{
          content: "test",
          class: "test",
          user: @test_user
        })

      # Find the node
      {_graph, found_vertex} = GraphManager.find_node_by_id(@test_path, vertex.id)

      assert found_vertex.id == vertex.id
      assert found_vertex.content == vertex.content
    end

    test "find_node_by_id returns nil for non-existent node", %{graph: _} do
      result = GraphManager.find_node_by_id(@test_path, "non-existent")
      assert result == nil
    end

    test "add_child creates connected nodes properly", %{graph: _} do
      # Create parent
      parent =
        GraphManager.add_node(@test_path, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Add child using add_child
      {updated_graph, child} =
        GraphManager.add_child(
          @test_path,
          [parent],
          fn n -> LlmInterface.ask_model("child content", n, self()) end,
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
        GraphManager.add_node(@test_path, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      {graph_with_nodes, _child} =
        GraphManager.add_child(
          @test_path,
          [parent],
          fn n -> LlmInterface.ask_model("child content", n, self()) end,
          "child_class",
          @test_user
        )

      # Verify nodes and edges exist
      assert length(:digraph.vertices(graph_with_nodes)) > 0
      assert length(:digraph.edges(graph_with_nodes)) > 0

      # Reset graph
      GraphManager.reset_graph(@test_path)

      # Get fresh graph
      fresh_graph = GraphManager.get_graph(@test_path)

      # Verify graph is empty
      assert length(:digraph.vertices(fresh_graph)) == 0
      assert length(:digraph.edges(fresh_graph)) == 0
    end

    test "multiple children maintain correct relationships", %{graph: _} do
      # Create parent
      parent =
        GraphManager.add_node(@test_path, %Vertex{
          content: "parent",
          class: "test",
          user: @test_user
        })

      # Add multiple children
      {_graph1, child1} =
        GraphManager.add_child(
          @test_path,
          [parent],
          fn n -> LlmInterface.ask_model("child1", n, @test_path) end,
          "test",
          @test_user
        )

      {graph2, child2} =
        GraphManager.add_child(
          @test_path,
          [parent],
          fn n -> LlmInterface.ask_model("child2", n, @test_path) end,
          "test",
          @test_user
        )

      # Verify all nodes exist
      vertices = :digraph.vertices(graph2)
      assert length(vertices) == 3

      # Verify edges
      edges = :digraph.edges(graph2)
      assert length(edges) == 2

      # Verify both children have the same parent
      {_, updated_child1} = GraphManager.find_node_by_id(@test_path, child1.id)
      {_, updated_child2} = GraphManager.find_node_by_id(@test_path, child2.id)

      assert length(updated_child1.parents) == 1
      assert length(updated_child2.parents) == 1
      assert hd(updated_child1.parents).id == parent.id
      assert hd(updated_child2.parents).id == parent.id
    end
  end

  test "supervisor handles process termination" do
    # Start a graph
    GraphManager.get_graph(@test_path)
    assert GraphManager.exists?(@test_path)

    # Get the PID
    [{pid, _}] = Registry.lookup(GraphRegistry, @test_path)

    # Kill the process
    Process.exit(pid, :kill)

    # Wait a brief moment for the supervisor to restart
    Process.sleep(100)

    # Verify the process was restarted
    assert GraphManager.exists?(@test_path)
    [{new_pid, _}] = Registry.lookup(GraphRegistry, @test_path)
    assert new_pid != pid
  end
end
