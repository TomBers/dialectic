defmodule DialecticWeb.OutlineGraphLiveTest do
  use DialecticWeb.ConnCase, async: false

  alias Dialectic.Follows
  alias Dialectic.Highlights

  import Dialectic.AccountsFixtures
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

  defp highlight_graph_data do
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
          "content" => "Could archetypes be explained biologically?",
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
            "# Biological and cultural\nMaybe partially, but the concept also depends on culture and interpretation.",
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

  defp source_text_graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "# Shared memory",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" => "How does culture shape archetypes?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "3",
          "content" => "Culture gives those patterns symbols and stories.",
          "class" => "answer",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "4",
          "content" => "Could biology still matter?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false,
          "source_text" =>
            "A laboratory paper mentions synaptic tagging and epigenetic priming in memory formation."
        }
      ],
      "edges" => [
        %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
        %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
        %{"data" => %{"id" => "2_4", "source" => "2", "target" => "4"}}
      ]
    }
  end

  defp shared_leaf_graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "# Shared leaf root",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" => "Where should this argument split?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "3",
          "content" => "First branch",
          "class" => "answer",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "4",
          "content" => "Second branch",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "5",
          "content" => "# Shared endpoint\nBoth branches eventually arrive here.",
          "class" => "synthesis",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "6",
          "content" => "Second branch detail",
          "class" => "answer",
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
        %{"data" => %{"id" => "3_5", "source" => "3", "target" => "5"}},
        %{"data" => %{"id" => "4_6", "source" => "4", "target" => "6"}},
        %{"data" => %{"id" => "6_5", "source" => "6", "target" => "5"}}
      ]
    }
  end

  defp deeply_nested_graph_data do
    %{
      "nodes" => [
        %{
          "id" => "1",
          "content" => "# Root",
          "class" => "origin",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "2",
          "content" => "Where should the argument split?",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "3",
          "content" => "Short branch",
          "class" => "answer",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "4",
          "content" => "Deep branch start",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "5",
          "content" => "Deep branch level two",
          "class" => "answer",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "6",
          "content" => "Deep branch level three",
          "class" => "question",
          "user" => nil,
          "parent" => nil,
          "noted_by" => [],
          "deleted" => false,
          "compound" => false
        },
        %{
          "id" => "7",
          "content" => "Deep branch leaf",
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
        %{"data" => %{"id" => "4_5", "source" => "4", "target" => "5"}},
        %{"data" => %{"id" => "5_6", "source" => "5", "target" => "6"}},
        %{"data" => %{"id" => "6_7", "source" => "6", "target" => "7"}}
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

  test "mounts the reader at the start of the graph and renders through the next split", %{
    conn: conn
  } do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.graph_id == graph.title
    assert assigns.node.id == "1"
    assert Enum.map(assigns.reading_chain, & &1.id) == ["1", "2"]
    assert assigns.reading_terminal.id == "2"
    assert Enum.map(assigns.next_choices, & &1.id) == ["3", "4"]
    assert is_nil(assigns.compare_context)
    assert has_element?(view, "#outline-layout")
    assert has_element?(view, "#outline-scroll-shell[phx-hook='ScrollReset']")
    assert has_element?(view, "#outline-tree[phx-hook='OutlineNav']")
    assert has_element?(view, "#outline-mobile-nav")
    assert has_element?(view, "#outline-detail")
    assert has_element?(view, "#outline-node-1")
    assert has_element?(view, "#outline-node-1[data-outline-selected='true']")
    assert has_element?(view, "#outline-mobile-node-1")
    assert has_element?(view, "#reader-workspace-bar-graph")
    assert has_element?(view, "#reader-workspace-bar-graph[data-view-transition='mode-switch']")
    assert has_element?(view, "#reading-node-1")
    assert has_element?(view, "#reading-node-2")
    assert has_element?(view, "#reading-node-1 span.bg-gray-900.text-gray-100", "Origin")
    assert has_element?(view, "#reading-node-2 span.bg-sky-50.text-sky-700", "Question")
    assert has_element?(view, "#outline-next-choices")
    assert has_element?(view, "#next-choice-3")
    assert has_element?(view, "#next-choice-4")
    refute has_element?(view, "#outline-branch-compare")
  end

  test "node_id param selects the requested node and keeps its outline entry", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=3")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.selected_node_id == "3"
    assert assigns.node.id == "3"
    assert Enum.map(assigns.selected_path, & &1.id) == ["1", "2", "3"]
    assert Enum.map(assigns.reading_chain, & &1.id) == ["3"]
    assert assigns.compare_context.root.id == "2"
    assert Enum.find(assigns.compare_branches, &(&1.id == "3")).active?
    assert has_element?(view, "#outline-node-3")
    assert has_element?(view, "#reading-node-3")
    assert has_element?(view, "#outline-end-state")
    assert has_element?(view, "#branch-compare-card-4")
    refute has_element?(view, "#branch-compare-card-3")
    refute has_element?(view, "#outline-next-choices")
  end

  test "branch root renders a single choice section", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.selected_node_id == "2"
    assert Enum.map(assigns.reading_chain, & &1.id) == ["2"]
    assert assigns.compare_context.root.id == "2"
    assert Enum.map(assigns.next_choices, & &1.id) == ["3", "4"]
    assert has_element?(view, "#outline-next-choices")
    assert has_element?(view, "#next-choice-3")
    assert has_element?(view, "#next-choice-4")
    refute has_element?(view, "#outline-branch-compare")
    refute has_element?(view, "#outline-end-state")
  end

  test "reader expands a single-child path until the leaf", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=4")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert assigns.selected_node_id == "4"
    assert Enum.map(assigns.reading_chain, & &1.id) == ["4", "5"]
    assert assigns.reading_terminal.id == "5"
    assert assigns.next_choices == []
    assert assigns.compare_context.root.id == "2"
    assert has_element?(view, "#reading-node-4")
    assert has_element?(view, "#reading-node-5")
    assert has_element?(view, "#outline-end-state")
    assert has_element?(view, "#outline-end-editor-link")

    assert has_element?(
             view,
             ~s(#outline-end-editor-link[href="/g/#{graph.slug}/graph?node=5"])
           )

    assert has_element?(view, "#outline-branch-compare")
    assert has_element?(view, "#branch-compare-card-3")
    refute has_element?(view, "#outline-next-choices")
  end

  test "compare branches keep their own lead nodes when branches reconverge", %{conn: conn} do
    graph = create_graph(shared_leaf_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")
    assigns = :sys.get_state(view.pid).socket.assigns

    branch_leads =
      assigns.compare_branches
      |> Map.new(fn branch -> {branch.id, branch.lead.id} end)

    assert assigns.compare_context.root.id == "2"
    assert branch_leads["3"] == "3"
    assert branch_leads["4"] == "4"
  end

  test "patching to a different node pushes a scroll reset event", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")

    view
    |> element("#next-choice-3")
    |> render_click()

    assert_patch(view, ~p"/g/#{graph.slug}?node=3")
    assert_push_event(view, "scroll_to_top", %{})
  end

  test "deep outlines stay flat and navigable without nesting controls", %{conn: conn} do
    graph = create_graph(deeply_nested_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}")
    assert has_element?(view, "#outline-node-4")
    assert has_element?(view, "#outline-node-5")
    assert has_element?(view, "#outline-node-6")
    assert has_element?(view, "#outline-node-7")
    refute has_element?(view, "#outline-toggle-4")
    refute has_element?(view, "#outline-expand-all")
    refute has_element?(view, "#outline-reset-folds")
  end

  test "selected article title shows the full node text in the reader and outline", %{conn: conn} do
    graph = create_graph(long_title_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")
    assigns = :sys.get_state(view.pid).socket.assigns

    full_title =
      "Please explain in detail how modern genetics and epigenetic memory might provide a physical mechanism for the transmission of Jungian archetypes across generations?"

    assert assigns.node.full_title == full_title
    assert assigns.node.title != full_title
    assert has_element?(view, "#outline-detail h2", full_title)
    assert has_element?(view, "#outline-node-2", full_title)
    refute render(view) =~ "You are here:"
  end

  test "share button opens the share modal with a reader url for the current node", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")

    assert has_element?(view, "#reader-workspace-bar-share")

    view
    |> element("#reader-workspace-bar-share")
    |> render_click()

    share_url = "#{DialecticWeb.Endpoint.url()}/g/#{graph.slug}?node=2"

    assert has_element?(view, "#share-modal-hook")
    assert has_element?(view, ~s(#share-url-input[value="#{share_url}"]))
    refute render(view) =~ "Generating preview..."
  end

  test "highlight share button opens the share modal for the selected quote", %{conn: conn} do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "5",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 12,
        selected_text_snapshot: "Meaning is use.",
        created_by_user_id: user.id
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")

    view
    |> element("#highlight-share-#{highlight.id}")
    |> render_click()

    share_url = "#{DialecticWeb.Endpoint.url()}/g/#{graph.slug}?node=5&highlight=#{highlight.id}"

    assert has_element?(view, "#share-modal-hook")
    assert render(view) =~ "Share Quote"
    assert has_element?(view, ~s(#share-url-input[value="#{share_url}"]))
    assert render(view) =~ "/g/#{graph.slug}/highlights/#{highlight.id}/share-card.svg?v="
  end

  test "reader search opens from the top bar and patches to the selected result", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")

    assert has_element?(view, "#reader-workspace-bar-search")

    view
    |> element("#reader-workspace-bar-search")
    |> render_click()

    assert has_element?(view, "#outline-quick-search-panel")

    view
    |> element("#outline-quick-search-form")
    |> render_change(%{"search_term" => "biologically"})

    assert has_element?(
             view,
             "#outline-search-result-4",
             "Could archetypes be explained biologically?"
           )

    view
    |> element("#outline-search-result-4")
    |> render_click()

    assert_patch(view, ~p"/g/#{graph.slug}?node=4")
  end

  test "reader can follow and unfollow the current grid", %{conn: conn} do
    user = user_fixture()
    graph = create_graph()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/g/#{graph.slug}?node=2")

    assert has_element?(view, "#reader-follow-grid-button", "Follow")

    view
    |> element("#reader-follow-grid-button")
    |> render_click()

    assert Follows.following_graph?(user, graph)
    assert has_element?(view, "#reader-follow-grid-button", "Following")

    view
    |> element("#reader-follow-grid-button")
    |> render_click()

    refute Follows.following_graph?(user, graph)
    assert has_element?(view, "#reader-follow-grid-button", "Follow")
  end

  test "crafted unauthenticated reader unfollow event opens the login modal", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")

    html = render_click(view, "unfollow_graph")

    assert html =~ "Login Required"
  end

  test "reader search matches source text and renders a preview snippet", %{conn: conn} do
    graph = create_graph(source_text_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=2")

    view
    |> element("#reader-workspace-bar-search")
    |> render_click()

    view
    |> element("#outline-quick-search-form")
    |> render_change(%{"search_term" => "synaptic"})

    assert has_element?(view, "#outline-search-result-4", "Could biology still matter?")
    assert has_element?(view, "#outline-search-result-4", "Source")

    assert has_element?(
             view,
             "#outline-search-result-4",
             "synaptic tagging and epigenetic priming"
           )
  end

  test "reader renders a highlights drawer toggle with the current count", %{conn: conn} do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, _highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "5",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 5,
        selected_text_snapshot: "Maybe",
        created_by_user_id: user.id
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=4")

    assert has_element?(view, "#reader-workspace-bar-highlights")
    assert has_element?(view, "#reader-workspace-bar-highlights", "1")
    assert render(view) =~ "Reading key"
    assert render(view) =~ "Highlights"
  end

  test "reader loads highlight data for rendered nodes", %{conn: conn} do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "5",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 5,
        selected_text_snapshot: "Maybe",
        created_by_user_id: user.id
      })

    {:ok, _link} = Highlights.add_link(highlight, "3", "explain")

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=4")
    assigns = :sys.get_state(view.pid).socket.assigns

    assert length(assigns.highlights) == 1

    assert has_element?(
             view,
             "#reading-highlight-5[phx-hook='TextSelectionHook'][data-highlights-only='false']"
           )

    assert has_element?(view, "#reader-selection-actions-hook[phx-hook='SelectionActions']")
    assert has_element?(view, "#selection-actions button[phx-click='highlight_only']")
    refute has_element?(view, "#selection-actions button[phx-click='explain']")

    assert_push_event(view, "highlights_loaded", %{
      highlights: [%{node_id: "5", links: [%{node_id: "3", link_type: "explain"}]}]
    })
  end

  test "reader selection action creates a highlight only", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    graph = create_graph(highlight_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")

    send(view.pid, {
      :selection_action,
      %{
        action: :highlight_only,
        selected_text: "Maybe",
        node_id: "5",
        offsets: %{"start" => 0, "end" => 5},
        highlight: nil
      }
    })

    render(view)

    assert [highlight] = Highlights.list_highlights_with_links(mudg_id: graph.title)
    assert highlight.node_id == "5"
    assert highlight.selection_start == 0
    assert highlight.selection_end == 5
    assert highlight.selected_text_snapshot == "Maybe"
    assert highlight.created_by_user_id == user.id

    assert_push_event(view, "highlights_loaded", %{
      highlights: [%{id: id, node_id: "5"}]
    })

    assert id == highlight.id
  end

  test "reader selection action prompts login for signed-out users", %{conn: conn} do
    graph = create_graph(highlight_graph_data())

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")

    send(view.pid, {
      :selection_action,
      %{
        action: :highlight_only,
        selected_text: "Maybe",
        node_id: "5",
        offsets: %{"start" => 0, "end" => 5},
        highlight: nil
      }
    })

    html = render(view)

    assert html =~ "Login Required"
    assert Highlights.list_highlights_with_links(mudg_id: graph.title) == []
  end

  test "highlight link navigation patches the reader to the target node", %{conn: conn} do
    graph = create_graph()

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=4")

    render_hook(view, "navigate_to_node", %{"node_id" => "5"})

    assert_patch(view, ~p"/g/#{graph.slug}?node=5")
  end

  test "clicking a highlight on another node patches the reader with a highlight target", %{
    conn: conn
  } do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "3",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 5,
        selected_text_snapshot: "It describes",
        created_by_user_id: user.id
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=4")

    render_click(view, "highlight_clicked", %{"id" => "#{highlight.id}", "node-id" => "3"})

    assert_patch(view, ~p"/g/#{graph.slug}?node=3&highlight=#{highlight.id}")
  end

  test "clicking a highlight on an outline path node patches when its text is not mounted", %{
    conn: conn
  } do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "2",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 5,
        selected_text_snapshot: "Could",
        created_by_user_id: user.id
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")

    render_click(view, "highlight_clicked", %{"id" => "#{highlight.id}", "node-id" => "2"})

    assert_patch(view, ~p"/g/#{graph.slug}?node=2&highlight=#{highlight.id}")
  end

  test "clicking a highlight already on screen scrolls to it without patching", %{conn: conn} do
    graph = create_graph(highlight_graph_data())
    user = user_fixture()

    {:ok, highlight} =
      Highlights.create_highlight(%{
        mudg_id: graph.title,
        node_id: "5",
        text_source_type: "node",
        selection_start: 0,
        selection_end: 5,
        selected_text_snapshot: "Maybe",
        created_by_user_id: user.id
      })

    {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}?node=5")
    highlight_id = "#{highlight.id}"

    render_click(view, "highlight_clicked", %{"id" => highlight_id, "node-id" => "5"})

    assert_push_event(view, "scroll_to_highlight", %{id: ^highlight_id})
  end
end
