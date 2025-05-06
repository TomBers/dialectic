defmodule Dialectic.Linear.ThreadedConvTest do
  use ExUnit.Case, async: true
  alias Dialectic.Linear.ThreadedConv
  alias Dialectic.Graph.Vertex

  setup do
    # Create a test digraph for the tests
    graph = :digraph.new()
    
    # Setup a simple conversation structure for testing
    root = "1"
    child1 = "2"
    child2 = "3"
    grandchild = "4"
    
    # Add vertices with test data
    :digraph.add_vertex(graph, root, %Vertex{id: root, content: "Root message", class: "user", user: "user1"})
    :digraph.add_vertex(graph, child1, %Vertex{id: child1, content: "Child 1", class: "response", user: "ai"})
    :digraph.add_vertex(graph, child2, %Vertex{id: child2, content: "Child 2", class: "user", user: "user1"})
    :digraph.add_vertex(graph, grandchild, %Vertex{id: grandchild, content: "Grandchild", class: "response", user: "ai"})
    
    # Add edges to create the conversation structure
    # Root -> Child1
    # Root -> Child2
    # Child2 -> Grandchild
    :digraph.add_edge(graph, root, child1)
    :digraph.add_edge(graph, root, child2)
    :digraph.add_edge(graph, child2, grandchild)
    
    # Return the graph for use in tests
    {:ok, graph: graph}
  end

  describe "find_root_nodes/1" do
    test "identifies nodes with no incoming edges", %{graph: graph} do
      root_nodes = ThreadedConv.find_root_nodes(graph)
      assert length(root_nodes) == 1
      assert "1" in root_nodes
    end
    
    test "handles multiple root nodes" do
      graph = :digraph.new()
      
      # Add two separate conversation threads
      :digraph.add_vertex(graph, "1", %Vertex{id: "1", content: "Thread 1"})
      :digraph.add_vertex(graph, "2", %Vertex{id: "2", content: "Thread 2"})
      :digraph.add_vertex(graph, "3", %Vertex{id: "3", content: "Reply to 1"})
      
      :digraph.add_edge(graph, "1", "3")
      
      root_nodes = ThreadedConv.find_root_nodes(graph)
      assert length(root_nodes) == 2
      assert "1" in root_nodes
      assert "2" in root_nodes
    end
  end

  describe "process_thread/5" do
    test "processes a thread with correct indentation", %{graph: graph} do
      visited = MapSet.new()
      {processed, _} = ThreadedConv.process_thread(graph, "1", 0, [], visited)
      
      # Convert to a map for easier verification
      nodes_by_id = processed |> Enum.into(%{}, fn {id, indent, _} -> {id, indent} end)
      
      # Check indentation levels
      assert nodes_by_id["1"] == 0  # Root should have indent 0
      assert nodes_by_id["2"] == 1  # Child1 should have indent 1
      assert nodes_by_id["3"] == 1  # Child2 should have indent 1
      assert nodes_by_id["4"] == 2  # Grandchild should have indent 2
    end
  end

  describe "process_graph/1" do
    test "correctly processes the entire graph", %{graph: graph} do
      processed = ThreadedConv.process_graph(graph)
      
      # Should contain all nodes
      assert length(processed) == 4
      
      # Check that each node is present
      node_ids = Enum.map(processed, fn {id, _, _} -> id end) |> MapSet.new()
      assert MapSet.equal?(node_ids, MapSet.new(["1", "2", "3", "4"]))
    end
    
    test "handles empty graphs" do
      empty_graph = :digraph.new()
      processed = ThreadedConv.process_graph(empty_graph)
      assert processed == []
    end
  end

  describe "format_for_rendering/1" do
    test "formats the processed nodes for rendering", %{graph: graph} do
      processed = ThreadedConv.process_graph(graph)
      formatted = ThreadedConv.format_for_rendering(processed)
      
      # Should be in reverse order of processing (for conversation flow)
      assert length(formatted) == 4
      
      # Check the structure of the formatted data
      first = List.first(formatted)
      assert is_map(first)
      assert Map.has_key?(first, :id)
      assert Map.has_key?(first, :indent)
      assert Map.has_key?(first, :content)
      assert Map.has_key?(first, :class)
      assert Map.has_key?(first, :user)
    end
  end

  describe "prepare_conversation/1" do
    test "prepares a complete conversation from a graph", %{graph: graph} do
      conversation = ThreadedConv.prepare_conversation(graph)
      
      # Should contain all nodes in correct order
      assert length(conversation) == 4
      
      # First node should be the root (id: "1")
      root = List.first(conversation)
      assert root.id == "1"
      assert root.indent == 0
      assert root.content == "Root message"
      
      # Verify order and indentation (the exact order depends on processing but the structure should be consistent)
      # We can at least check that the grandchild comes after its parent
      grandchild_index = Enum.find_index(conversation, fn node -> node.id == "4" end)
      parent_index = Enum.find_index(conversation, fn node -> node.id == "3" end)
      assert grandchild_index > parent_index
    end
  end
end