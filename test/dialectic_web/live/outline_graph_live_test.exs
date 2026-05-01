defmodule DialecticWeb.OutlineGraphLiveTest do
  use DialecticWeb.ConnCase, async: false

  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  defp sample_graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "# Collective unconscious",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" => "What makes it different from personal memory?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "3",
          "content" =>
            "It describes inherited symbolic patterns rather than individual recollection.",
          "class" => "answer",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "4",
          "content" => "Could archetypes be explained biologically?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "5",
          "content" =>
            "Maybe partially, but the concept also depends on culture and interpretation.",
          "class" => "synthesis",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        }
      ],
      "edges" => [
        %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
        %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
        %{"data" => %{"id" => "2_4", "source" => "2", "target" => "4"}},
        %{"data" => %{"id" => "4_5", "source" => "4", "target" => "5"}}
      ]
    }
  end

  defp long_title_graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "# Root prompt",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" =>
            "Please explain in detail how modern genetics and epigenetic memory might provide a physical mechanism for the transmission of Jungian archetypes across generations?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        }
      ],
      "edges" => [
        %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}}
      ]
    }
  end

  defp create_graph(data \\ sample_graph_data()) do
    unique = System.unique_integer([:positive])

    insert_graph(%{
      title: "Outline Graph Test #{unique}",
      data: data
    })
  end

  test "mounts outline view and renders the tree and detail panes", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/outline")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.graph_id == graph.title
    assert assigns.node.id == "5"
    assert assigns.compare_context.root.id == "2"
    assert Enum.map(assigns.compare_branches, & &1.id) == ["3", "4"]
    assert Enum.find(assigns.compare_branches, &(&1.id == "4")).active?
    assert has_element?(view, "#outline-layout")
    assert has_element?(view, "#outline-tree")
    assert has_element?(view, "#outline-detail")
    assert has_element?(view, "#outline-node-5")
    assert has_element?(view, "#outline-branch-compare")
    assert has_element?(view, "#branch-compare-card-3")
    refute has_element?(view, "#branch-compare-card-4")
  end

  test "node_id param selects the requested node and keeps its outline entry", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/outline?node_id=3")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.selected_node_id == "3"
    assert assigns.node.id == "3"
    assert Enum.map(assigns.selected_path, & &1.id) == ["1", "2", "3"]
    assert assigns.compare_context.root.id == "2"
    assert Enum.find(assigns.compare_branches, &(&1.id == "3")).active?
    assert has_element?(view, "#outline-node-3")
    assert has_element?(view, "#branch-compare-card-4")
    refute has_element?(view, "#branch-compare-card-3")
  end

  test "branch root merges continue and compare into one section", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/outline?node_id=2")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.selected_node_id == "2"
    assert assigns.compare_context.root.id == "2"
    assert has_element?(view, "#outline-continue")
    assert has_element?(view, "#continue-node-3")
    assert has_element?(view, "#continue-node-4")
    refute has_element?(view, "#outline-branch-compare")
  end

  test "patching to a different node pushes a scroll reset event", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/outline?node_id=2")

    view
    |> element("#continue-node-3")
    |> render_click()

    assert_patch(view, ~p"/g/#{graph.slug}/outline?node_id=3")
    assert_push_event(view, "scroll_to_top", %{})
  end

  test "selected article title shows the full node text", %{conn: conn} do
    graph = create_graph(long_title_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/outline?node_id=2")
    assigns = :sys.get_state(view.pid).socket.assigns

    full_title =
      "Please explain in detail how modern genetics and epigenetic memory might provide a physical mechanism for the transmission of Jungian archetypes across generations?"

    assert assigns.node.full_title == full_title
    assert assigns.node.title != full_title
    assert has_element?(view, "#outline-detail h2", full_title)
    refute has_element?(view, "#outline-node-2", full_title)
  end
end
