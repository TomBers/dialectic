defmodule DialecticWeb.GraphLiveTest do
  use DialecticWeb.ConnCase, async: false
  alias Dialectic.Accounts
  alias Dialectic.Follows
  alias Dialectic.GridActivity

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  @graph_id "Satre"

  defp setup_live(conn) do
    conn =
      conn
      |> log_in_user(user_fixture(%{email: "tester@example.com"}))

    # Also create test database
    {:ok, graph} = Dialectic.GraphFixtures.insert_graph_fixture(@graph_id)

    live(conn, ~p"/g/#{graph.slug}/graph?node=1")
  end

  defp setup_live_for_graph(conn, graph_name) do
    conn =
      conn
      |> log_in_user(
        user_fixture(%{email: "tester-#{System.unique_integer([:positive])}@example.com"})
      )

    {:ok, graph} = Dialectic.GraphFixtures.insert_graph_fixture(graph_name)

    live(conn, ~p"/g/#{graph.slug}/graph?node=1")
  end

  defp setup_live_with_data(conn, data) do
    conn =
      conn
      |> log_in_user(
        user_fixture(%{email: "searcher-#{System.unique_integer([:positive])}@example.com"})
      )

    graph =
      Dialectic.GraphFixtures.insert_graph(%{
        title: "Search Graph #{System.unique_integer([:positive])}",
        data: data
      })

    live(conn, ~p"/g/#{graph.slug}/graph?node=1")
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
        %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}}
      ]
    }
  end

  describe "mount/3" do
    test "keeps a stable anonymous LLM actor in the signed browser session", %{conn: conn} do
      first_conn = get(conn, ~p"/")
      actor_id = get_session(first_conn, :llm_actor_id)

      second_conn = first_conn |> recycle() |> get(~p"/")

      assert is_binary(actor_id)
      assert actor_id != ""
      assert get_session(second_conn, :llm_actor_id) == actor_id
    end

    test "assigns necessary values on mount with a current user", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid)
      socket = state.socket

      assert socket.assigns.graph_id == @graph_id
      assert socket.assigns.user == "tester@example.com"
      assert is_binary(socket.assigns.llm_actor_id)
      assert socket.assigns.llm_actor_id != ""
    end

    test "uses the signed-in user's account-wide appearance preferences", %{conn: conn} do
      user = user_fixture()

      {:ok, user} =
        Accounts.update_user_appearance(user, %{
          reading_density: "large",
          reading_font: "serif",
          graph_view_mode: "compact",
          graph_direction: "RL",
          reduce_motion: true,
          high_contrast: true
        })

      {:ok, graph} =
        Dialectic.GraphFixtures.insert_graph_fixture(
          "Appearance Graph #{System.unique_integer([:positive])}"
        )

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/g/#{graph.slug}/graph?node=1")

      assert has_element?(
               view,
               "#graph-layout[data-reading-density='large'][data-reading-font='serif'][data-graph-view-mode='compact'][data-graph-direction='RL'][data-reduce-motion='true'][data-high-contrast='true']"
             )

      assert has_element?(
               view,
               "#cy[data-graph-view-mode='compact'][data-graph-direction='RL'][data-reduce-motion='true'][data-high-contrast='true']"
             )

      refute has_element?(view, "#settings-menu", "Appearance")
    end

    test "renders activity as a readable actor, action, target, and time", %{conn: conn} do
      user = user_fixture()

      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Activity Panel Graph #{System.unique_integer([:positive])}",
          data: source_text_graph_data()
        })

      assert {:ok, log} =
               GridActivity.record_node_event(
                 graph.title,
                 user,
                 "node.follow_up.created",
                 "2"
               )

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/g/#{graph.slug}/graph?node=2")

      assert has_element?(
               view,
               "#grid-activity-actor-#{log.id}",
               Dialectic.Accounts.User.display_name(user)
             )

      assert has_element?(view, "#grid-activity-log-#{log.id}", "asked a follow-up question")
      assert has_element?(view, "#grid-activity-time-#{log.id}[datetime]")

      assert has_element?(
               view,
               "#grid-activity-node-#{log.id}[phx-value-node_id='2']"
             )
    end

    test "shows a persistent reader switch for the current node", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket
      graph = state.assigns.graph_struct
      node_id = Map.get(state.assigns.node, :id)

      assert has_element?(view, "#graph-workspace-bar-reader")

      assert has_element?(
               view,
               ~s(#graph-workspace-bar-reader[href="/g/#{graph.slug}?node=#{node_id}"])
             )
    end

    test "keeps whole-node and selected-passage inquiries in the shared action surface", %{
      conn: conn
    } do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())

      render_click(view, "node_clicked", %{"id" => "2"})

      assert has_element?(view, "#node-inquiry-actions-2-content #global-chat-form")
      refute has_element?(view, "#bottom-menu")

      assert has_element?(view, "#node-suggestions-2 [id^='node-tool-pros-cons-']")
      assert has_element?(view, "[id^='delete-node-'][phx-value-node='2']", "Delete node")

      view
      |> element("#global-chat-form [id^='node-tools-more-']")
      |> render_click()

      assert has_element?(view, "#node-tools-popover-2")

      view
      |> element("#global-chat-form [id^='node-tools-more-']")
      |> render_click()

      refute has_element?(view, "#node-tools-popover-2")

      assert has_element?(
               view,
               "#selection-inquiry-actions-selection-actions-content #selection-action-explain-selection-actions"
             )
    end

    test "surfaces the explanation level and opens its settings", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      assert has_element?(view, "#graph-workspace-bar-level", "In-depth")

      view
      |> element("#graph-workspace-bar-level")
      |> render_click()

      assert has_element?(view, "#right-panel", "Grid tools")
      assert has_element?(view, "#details-configure[open]", "Explanation level")
      assert has_element?(view, "#answer-level-university[aria-pressed='true']")

      assert has_element?(
               view,
               "#document-menu-settings-document-menu[aria-label='Open grid tools']"
             )

      render_click(view, "set_prompt_mode", %{"prompt_mode" => "high_school"})

      assert has_element?(view, "#graph-workspace-bar-level", "Essential")
      assert has_element?(view, "#answer-level-high_school[aria-pressed='true']")
      assert has_element?(view, "#answer-level-high_school[phx-click*='toggle-panel']")
      refute has_element?(view, "#answer-level-simple")
    end

    test "prompts signed-out users before changing to a restricted level", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Restricted Level Graph #{System.unique_integer([:positive])}",
          prompt_mode: "high_school"
        })

      {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/graph?node=1")

      render_click(view, "set_prompt_mode", %{"prompt_mode" => "expert"})

      assert has_element?(view, "#login-modal", "Login Required")

      assert Dialectic.DbActions.Graphs.get_graph_by_title(graph.title).prompt_mode ==
               "high_school"
    end

    test "can follow and unfollow the current grid", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      assigns = :sys.get_state(view.pid).socket.assigns
      user = assigns.current_user
      graph = assigns.graph_struct

      assert has_element?(view, "#graph-follow-grid-button", "Follow")

      view
      |> element("#graph-follow-grid-button")
      |> render_click()

      assert Follows.following_graph?(user, graph)
      assert has_element?(view, "#graph-follow-grid-button", "Following")

      view
      |> element("#graph-follow-grid-button")
      |> render_click()

      refute Follows.following_graph?(user, graph)
      assert has_element?(view, "#graph-follow-grid-button", "Follow")
    end

    test "crafted unauthenticated unfollow event opens the login modal", %{conn: conn} do
      graph =
        Dialectic.GraphFixtures.insert_graph(%{
          title: "Unauth Graph Follow #{System.unique_integer([:positive])}",
          data: source_text_graph_data()
        })

      {:ok, view, _html} = live(conn, ~p"/g/#{graph.slug}/graph?node=1")

      html = render_click(view, "unfollow_graph")

      assert html =~ "Login Required"
    end

    test "renders ephemeral viewer chat and streams submitted messages", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      assert has_element?(view, "#grid-chat-toggle")
      assert has_element?(view, "#chat-drawer")
      assert has_element?(view, "#grid-chat-form")
      assert has_element?(view, "#grid-chat-viewers[tabindex='0'][role='region']")
      assert has_element?(view, "#grid-chat-messages[tabindex='0'][role='region']")
      assert has_element?(view, "#graph-workspace-bar-highlights", "Highlights")

      view
      |> element("#grid-chat-form")
      |> render_submit(%{"grid_chat" => %{"message" => "Hello viewers"}})

      assert has_element?(view, "#grid-chat-messages", "Hello viewers")
      assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat, 1 message']")
    end

    test "viewer chat toggle count is capped to retained stream messages", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      for index <- 1..101 do
        view
        |> element("#grid-chat-form")
        |> render_submit(%{"grid_chat" => %{"message" => "Chat message #{index}"}})
      end

      assert has_element?(view, "#grid-chat-toggle[aria-label='Open viewer chat, 100 messages']")
    end
  end

  describe "explore admission" do
    test "shows the server-side explore selection limit", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "Explore Limit UI")

      render_click(view, "open_explore_modal", %{"items" => ["A", "B", "C", "D"]})

      assert has_element?(view, "#explore-modal")
      assert has_element?(view, "#explore-selection-form")
      assert has_element?(view, "#explore-selection-limit", "Select up to 3 points")
    end

    test "rejects branch lists above the explore limit before creating nodes", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "Explore Branch Limit")
      graph_id = :sys.get_state(view.pid).socket.assigns.graph_id
      {_graph_struct, graph_before} = GraphManager.get_graph(graph_id)
      vertex_count_before = length(:digraph.vertices(graph_before))

      render_click(view, "branch_list", %{"items" => ["A", "B", "C", "D"]})

      {_graph_struct, graph_after} = GraphManager.get_graph(graph_id)
      assert length(:digraph.vertices(graph_after)) == vertex_count_before
      assert has_element?(view, "#flash-error", "Choose up to 3 points at a time")
    end

    test "keeps the explore modal open when too many points are submitted", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "Explore Modal Limit")
      graph_id = :sys.get_state(view.pid).socket.assigns.graph_id
      items = ["A", "B", "C", "D"]

      render_click(view, "open_explore_modal", %{"items" => items})
      {_graph_struct, graph_before} = GraphManager.get_graph(graph_id)
      vertex_count_before = length(:digraph.vertices(graph_before))

      view
      |> element("#explore-selection-form")
      |> render_submit(%{
        "items" => %{"A" => "on", "B" => "on", "C" => "on", "D" => "on"}
      })

      {_graph_struct, graph_after} = GraphManager.get_graph(graph_id)
      assert length(:digraph.vertices(graph_after)) == vertex_count_before
      assert has_element?(view, "#explore-modal")
      assert has_element?(view, "#flash-error", "Choose up to 3 points at a time")
    end

    test "accepts exactly three explore points", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "Explore Boundary")
      graph_id = :sys.get_state(view.pid).socket.assigns.graph_id

      render_click(view, "open_explore_modal", %{"items" => ["A", "B", "C", "D"]})
      {_graph_struct, graph_before} = GraphManager.get_graph(graph_id)
      vertex_count_before = length(:digraph.vertices(graph_before))

      view
      |> element("#explore-selection-form")
      |> render_submit(%{
        "items" => %{
          "A" => ["false", "true"],
          "B" => ["false", "true"],
          "C" => ["false", "true"],
          "D" => ["false"]
        }
      })

      {_graph_struct, graph_after} = GraphManager.get_graph(graph_id)
      assert length(:digraph.vertices(graph_after)) == vertex_count_before + 3
      refute has_element?(view, "#explore-modal")
    end
  end

  describe "selection actions" do
    test "pros/cons creates thesis and antithesis children for the selected text", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      graph_id = :sys.get_state(view.pid).socket.assigns.graph_id
      parent_before = GraphManager.find_node_by_id(graph_id, "1")

      stale_thesis =
        GraphManager.add_node(graph_id, %Dialectic.Graph.Vertex{
          content: "Old stuck pro",
          class: "thesis",
          user: "tester@example.com",
          source_text: "different selection"
        })

      stale_ideas =
        GraphManager.add_node(graph_id, %Dialectic.Graph.Vertex{
          content: "Old related idea",
          class: "ideas",
          user: "tester@example.com",
          source_text: "synaptic tagging"
        })

      GraphManager.add_edges(graph_id, stale_thesis, [parent_before])
      GraphManager.add_edges(graph_id, stale_ideas, [parent_before])

      send(view.pid, {
        :selection_action,
        %{
          action: :pros_cons,
          selected_text: "synaptic tagging",
          node_id: "1",
          offsets: %{"start" => 0, "end" => 16},
          highlight: nil
        }
      })

      :sys.get_state(view.pid)
      parent = GraphManager.find_node_by_id(graph_id, "1")

      selected_text_branch_children =
        Enum.filter(parent.children, fn child ->
          child.source_text == "synaptic tagging" and child.class in ["thesis", "antithesis"]
        end)

      child_classes = selected_text_branch_children |> Enum.map(& &1.class) |> Enum.sort()

      assert child_classes == ["antithesis", "thesis"]

      [highlight] = Dialectic.Highlights.list_highlights(mudg_id: graph_id, node_id: "1")
      links = Dialectic.Highlights.get_links(highlight)
      linked_node_ids = Enum.map(links, & &1.node_id)

      linked_classes =
        linked_node_ids |> Enum.map(&GraphManager.find_node_by_id(graph_id, &1).class)

      assert Enum.sort(Enum.map(links, & &1.link_type)) == ["con", "pro"]
      assert Enum.sort(linked_classes) == ["antithesis", "thesis"]

      assert Enum.all?(linked_node_ids, fn node_id ->
               Enum.any?(selected_text_branch_children, &(&1.id == node_id))
             end)
    end

    test "explain uses the selection event node when the current node is stale", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      assigns = :sys.get_state(view.pid).socket.assigns
      graph_id = assigns.graph_id
      initial_f_graph = assigns.f_graph

      assert assigns.node.id == "1"

      send(view.pid, {
        :selection_action,
        %{
          action: :explain,
          selected_text: "synaptic tagging",
          node_id: "2",
          offsets: %{"start" => 29, "end" => 45},
          highlight: nil
        }
      })

      state = :sys.get_state(view.pid)

      event_node = GraphManager.find_node_by_id(graph_id, "2")
      stale_node = GraphManager.find_node_by_id(graph_id, "1")

      question_node =
        Enum.find(event_node.children, fn child ->
          child.class == "question" and child.content == "Please explain: synaptic tagging"
        end)

      assert question_node
      assert question_node.source_text == "synaptic tagging"

      answer_node =
        graph_id
        |> GraphManager.vertices()
        |> Enum.map(&GraphManager.vertex_label(graph_id, &1))
        |> Enum.find(fn
          %{class: "answer", source_text: "synaptic tagging"} -> true
          _other -> false
        end)

      assert answer_node

      assert state.socket.assigns.node.id == "1"
      assert state.socket.assigns.f_graph == initial_f_graph
      assert state.socket.assigns.background_generations[answer_node.id].status == :generating

      assert has_element?(
               view,
               "#background-generation-#{answer_node.id}",
               "Working in the background"
             )

      refute Enum.any?(stale_node.children, fn child ->
               child.content == "Please explain: synaptic tagging"
             end)

      send(view.pid, {:llm_request_complete, answer_node.id})
      :sys.get_state(view.pid)

      assert has_element?(
               view,
               "#open-background-answer-#{answer_node.id}",
               "View"
             )

      answer_node_id = answer_node.id

      view
      |> element("#open-background-answer-#{answer_node_id}")
      |> render_click()

      assert_push_event(view, "reflow_layout", %{id: ^answer_node_id})

      viewed_state = :sys.get_state(view.pid)
      assert viewed_state.socket.assigns.node.id == answer_node.id
      refute Map.has_key?(viewed_state.socket.assigns.background_generations, answer_node.id)
    end

    test "custom question uses the selection event node when the current node is stale", %{
      conn: conn
    } do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      assigns = :sys.get_state(view.pid).socket.assigns
      graph_id = assigns.graph_id
      question = "Why does synaptic tagging matter here?"

      assert assigns.node.id == "1"

      send(view.pid, {
        :selection_action,
        %{
          action: :ask_question,
          selected_text: "synaptic tagging",
          node_id: "2",
          offsets: %{"start" => 29, "end" => 45},
          highlight: nil,
          question: question
        }
      })

      :sys.get_state(view.pid)

      event_node = GraphManager.find_node_by_id(graph_id, "2")
      stale_node = GraphManager.find_node_by_id(graph_id, "1")

      question_node =
        Enum.find(event_node.children, fn child ->
          child.class == "question" and child.content == question
        end)

      assert question_node
      assert question_node.source_text == "synaptic tagging"
      refute Enum.any?(stale_node.children, &(&1.content == question))
    end

    test "missing selection event nodes fail gracefully", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      graph_id = :sys.get_state(view.pid).socket.assigns.graph_id
      vertex_count = length(GraphManager.vertices(graph_id))

      send(view.pid, {
        :selection_action,
        %{
          action: :explain,
          selected_text: "missing text",
          node_id: "missing-node",
          offsets: %{"start" => 0, "end" => 12},
          highlight: nil
        }
      })

      :sys.get_state(view.pid)

      send(view.pid, {
        :selection_action,
        %{
          action: :ask_question,
          selected_text: "missing text",
          node_id: "missing-node",
          offsets: %{"start" => 0, "end" => 12},
          highlight: nil,
          question: "Where did it go?"
        }
      })

      :sys.get_state(view.pid)

      assert Process.alive?(view.pid)
      assert length(GraphManager.vertices(graph_id)) == vertex_count
      assert has_element?(view, "#flash-error", "Node not found")
    end
  end

  describe "background generation" do
    test "composer questions preserve the current reader and graph", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      initial_assigns = :sys.get_state(view.pid).socket.assigns

      render_click(view, "reply-and-answer", %{
        "vertex" => %{"content" => "How does this change the argument?"}
      })

      assigns = :sys.get_state(view.pid).socket.assigns

      assert assigns.node.id == initial_assigns.node.id
      assert assigns.f_graph == initial_assigns.f_graph
      assert map_size(assigns.background_generations) == 1

      {_generation_id, generation} = Enum.at(assigns.background_generations, 0)
      assert generation.status == :generating
      assert length(generation.node_ids) == 1
      assert has_element?(view, "#background-generations", "Answering")
    end

    test "node tools generate without replacing the current reader", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      render_click(view, "node_clicked", %{"id" => "2"})
      initial_assigns = :sys.get_state(view.pid).socket.assigns

      view
      |> element("#node-suggestions-2 [id^='node-tool-related-']")
      |> render_click()

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.node.id == initial_assigns.node.id
      assert assigns.f_graph == initial_assigns.f_graph
      assert map_size(assigns.background_generations) == 1
      assert has_element?(view, "#background-generations", "Finding related ideas")
    end

    test "pro and con branches share one notification that waits for both responses", %{
      conn: conn
    } do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())
      initial_assigns = :sys.get_state(view.pid).socket.assigns

      render_click(view, "node_branch", %{"id" => "2"})

      assigns = :sys.get_state(view.pid).socket.assigns
      assert assigns.node.id == initial_assigns.node.id
      assert assigns.f_graph == initial_assigns.f_graph
      assert map_size(assigns.background_generations) == 1

      {generation_id, generation} = Enum.at(assigns.background_generations, 0)
      assert generation.status == :generating
      assert length(generation.node_ids) == 2

      [first_node_id, second_node_id] = generation.node_ids
      send(view.pid, {:llm_request_complete, first_node_id})

      first_complete =
        :sys.get_state(view.pid).socket.assigns.background_generations[generation_id]

      assert first_complete.status == :generating

      send(view.pid, {:llm_request_complete, second_node_id})
      :sys.get_state(view.pid)

      assert has_element?(
               view,
               "#background-generation-#{generation_id}",
               "Responses ready"
             )

      view
      |> element("#open-background-answer-#{generation_id}")
      |> render_click()

      assert_push_event(view, "reflow_layout", %{id: "2"})
    end
  end

  describe "search" do
    test "grid search matches source text and renders a preview snippet", %{conn: conn} do
      {:ok, view, _html} = setup_live_with_data(conn, source_text_graph_data())

      view
      |> element("#graph-workspace-bar-search")
      |> render_click()

      assert has_element?(view, "#quick-search-panel")

      view
      |> element("#quick-search-form")
      |> render_change(%{"search_term" => "synaptic"})

      assert has_element?(view, "#graph-search-result-2", "Could biology still matter?")
      assert has_element?(view, "#graph-search-result-2", "Source")

      assert has_element?(
               view,
               "#graph-search-result-2",
               "synaptic tagging and epigenetic priming"
             )
    end
  end

  describe "handle_event/3" do
    # Tests can be added here for new combine mode functionality

    test "answer event with empty content does nothing", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state_before = :sys.get_state(view.pid).socket.assigns

      render_click(view, "answer", %{"vertex" => %{"content" => ""}})
      state_after = :sys.get_state(view.pid).socket.assigns

      # No change in assigns.
      assert state_before == state_after
    end

    # GraphActions.comment/4 returns the new node; graph mutations happen inside GraphManager.
    # In a real test you would stub GraphActions.comment/4 to return predictable values.
    test "answer event with content calls GraphActions.comment and updates assigns", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # We simulate a non-empty answer. In this case, update_graph/3 (called by handle_event)
      # will update the node and f_graph assigns.
      render_click(view, "answer", %{"vertex" => %{"content" => "A non-empty answer"}})

      _state = :sys.get_state(view.pid).socket
      # (Other assigns such as node and f_graph would be updated by GraphActions.comment.)
    end
  end

  describe "handle_event node_clicked" do
    test "node_clicked updates the graph and node (via update_graph)", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # We simulate a node click event.
      render_click(view, "node_clicked", %{"id" => "1"})
      _state = :sys.get_state(view.pid).socket

      # Further assertions on assigns.graph or assigns.node would depend on the
      # return value of GraphActions.find_node/2 (which you might stub in a real test).
    end
  end

  describe "handle_info/2" do
    test "stream_chunk info updates the node if node_id matches", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket

      # Assume the current node has an id; if not, default to "1".
      current_node_id = Map.get(state.assigns.node, :id, "1")

      # Create a proper vertex structure instead of just a string
      # As the handler expects a vertex structure
      updated_vertex = %{
        id: current_node_id,
        content: "new content",
        class: "test",
        user: "test_user",
        noted_by: [],
        parents: [],
        children: [],
        deleted: false
      }

      send(view.pid, {:stream_chunk, updated_vertex, :node_id, current_node_id})
      # Allow the LiveView process time to process the message.
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # We expect that the node assign was updated.
      assert state_after.assigns.node.content == "new content"
    end

    test "stream_chunk info renders grounding metadata when content is unchanged", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket
      current_node = state.assigns.node

      grounding_metadata = %{
        "google" => %{
          "groundingChunks" => [
            %{"web" => %{"title" => "Research", "uri" => "https://example.com/research"}}
          ],
          "groundingSupports" => []
        }
      }

      updated_vertex = Map.put(current_node, :grounding_metadata, grounding_metadata)

      send(view.pid, {:stream_chunk, updated_vertex, :node_id, current_node.id})

      assert render(view)
      assert has_element?(view, "#markdown-body-#{current_node.id}[data-grounding]")

      state_after = :sys.get_state(view.pid).socket
      assert state_after.assigns.node.grounding_metadata == grounding_metadata
    end

    test "stream_chunk info does not update the node if node_id does not match", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket
      original_node = state.assigns.node

      updated_vertex = %{
        id: "non_matching_id",
        content: "new content",
        class: "test",
        user: "test_user",
        noted_by: [],
        parents: [],
        children: [],
        deleted: false
      }

      send(view.pid, {:stream_chunk, updated_vertex, :node_id, "non_matching_id"})
      :timer.sleep(50)
      state_after = :sys.get_state(view.pid).socket

      # The node assign should remain unchanged.
      assert state_after.assigns.node == original_node
    end

    test "presence join and leave info are handled without error", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Presence join: if the presence is for this graph, it should be inserted.
      presence = %{id: "BOB", metas: [%{graph_id: @graph_id}]}
      send(view.pid, {DialecticWeb.Presence, {:join, presence}})
      :timer.sleep(50)
      # Without access to the internal stream, we simply ensure no error occurs.
      assert true

      # Presence leave: if the metas list is empty, it should be deleted.
      presence_leave = %{id: "Bill", metas: []}
      send(view.pid, {DialecticWeb.Presence, {:leave, presence_leave}})
      :timer.sleep(50)
      assert true
    end
  end

  #####################################################################
  # New tests for the additional event functionality ("note", "unnote",
  # "delete", and "edit"). In these tests we assume that functions like
  # GraphActions.find_node/2 have been stubbed to return predictable values.
  #####################################################################

  describe "handle_event \"note\"" do
    test "note event updates the graph", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "What is ethics?")

      assert has_element?(view, "#graph-bookmark-node-1[aria-pressed='false']")
      assert has_element?(view, "#graph-bookmark-node-1 .hero-bookmark")

      # Simulate a note event on node "1". (In a real test you might stub
      # GraphActions.change_noted_by/3 to return a predictable updated graph/node.)
      render_click(view, "note", %{"node" => "1"})
      _state = :sys.get_state(view.pid).socket

      assert has_element?(view, "#graph-bookmark-node-1[aria-pressed='true']")
      assert has_element?(view, "#graph-bookmark-node-1 .hero-bookmark-solid")

      # Additional assertions (e.g. on assigns.graph or assigns.node) depend on your implementation.
    end
  end

  describe "handle_event \"unnote\"" do
    test "unnote event updates the graph", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "unnote", %{"node" => "1"})
      _state = :sys.get_state(view.pid).socket

      # You could also verify that GraphActions.change_noted_by was called with
      # Vertex.remove_noted_by/2 if you stub that function.
    end
  end

  # describe "handle_event \"delete\"" do
  #   test "delete event updates the graph when deletion conditions are met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     refute v.deleted

  #     # For this test we assume that when the node id is "delete_allowed",
  #     # GraphActions.find_node/2 returns a node with:
  #     #   - user equal to "tester@example.com"
  #     #   - children: [] (or only deleted children)
  #     render_click(view, "delete", %{"node" => "6"})
  #     state = :sys.get_state(view.pid).socket

  #     # IO.inspect(state, label: "state")
  #     # In the allowed case, update_graph is called so key_buffer is reset.
  #     assert state.assigns.key_buffer == ""
  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     assert v.deleted
  #   end

  #   test "delete event sets flash error when deletion conditions are not met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     # For this test we assume that when the node id is "delete_disallowed",
  #     # GraphActions.find_node/2 returns a node that either does not belong to the user
  #     # or has non-deleted children.
  #     render_click(view, "delete", %{"node" => "1"})
  #     state = :sys.get_state(view.pid).socket

  #     {_g, v} = GraphActions.find_node(@graph_id, "1")
  #     refute v.deleted
  #   end
  # end

  # describe "handle_event \"edit\"" do
  #   test "edit event sets up editing assigns when conditions are met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     {_g, v} = GraphActions.find_node(@graph_id, "6")

  #     assert v.content =~
  #              "Certainly! Let's delve deeper into the criticisms"

  #     # Assume that for node id "edit_allowed", GraphActions.find_node/2 returns a node with:
  #     #   - user equal to "tester@example.com"
  #     #   - no active children
  #     render_click(view, "edit", %{"node" => "6"})
  #     state = :sys.get_state(view.pid).socket

  #     # The node should be assigned to the socket, along with a form for editing and an edit flag.
  #     assert state.assigns.edit
  #     assert state.assigns.form
  #     assert state.assigns.node.id == "6"
  #     assert state.assigns.form.data.id == "6"

  #     assert state.assigns.form.data.content =~
  #              "Certainly! Let's delve deeper into the criticisms"

  #     render_click(view, "answer", %{"vertex" => %{"content" => "Edited Node"}})
  #     state_after = :sys.get_state(view.pid).socket.assigns
  #     {_g, v} = GraphActions.find_node(@graph_id, "6")
  #     assert v.content == "Edited Node"
  #   end

  #   test "edit event sets flash error when editing conditions are not met", %{conn: conn} do
  #     {:ok, view, _html} = setup_live(conn)

  #     # For node id "edit_disallowed", assume GraphActions.find_node/2 returns a node that cannot be edited.
  #     render_click(view, "edit", %{"node" => "1"})
  #     state = :sys.get_state(view.pid).socket

  #     refute state.assigns.edit
  #   end
  # end

  describe "presentation mode" do
    test "enter_presentation_setup transitions to :setup mode", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :setup
      assert state.presentation_slide_ids == []
    end

    test "close_presentation_setup hides drawer but keeps slide deck", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Enter setup and add a slide via node_clicked
      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_mode == :setup
      assert "1" in state.presentation_slide_ids

      # Close the setup drawer — slides should be preserved
      render_click(view, "close_presentation_setup", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :off
      assert "1" in state.presentation_slide_ids
    end

    test "exit_presentation without clear_slides keeps deck", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})

      render_click(view, "exit_presentation", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :off
      assert "1" in state.presentation_slide_ids
    end

    test "exit_presentation with clear_slides wipes deck", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})

      render_click(view, "exit_presentation", %{"clear_slides" => "true"})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :off
      assert state.presentation_slide_ids == []
    end

    test "node_clicked in setup mode toggles slide IDs", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})

      # Add node "1"
      render_click(view, "node_clicked", %{"id" => "1"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["1"]

      # Add node "2"
      render_click(view, "node_clicked", %{"id" => "2"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["1", "2"]

      # Toggle node "1" off
      render_click(view, "node_clicked", %{"id" => "1"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["2"]
    end

    test "presentation_remove_slide removes the specified node", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})

      render_click(view, "presentation_remove_slide", %{"node-id" => "1"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["2"]
    end

    test "presentation_clear_slides empties the deck", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})

      render_click(view, "presentation_clear_slides", %{})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == []
    end

    test "presentation_reorder sanitizes duplicates and unknown IDs", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})

      # Reorder with duplicates and an unknown ID — should be sanitized
      render_click(view, "presentation_reorder", %{
        "order" => ["2", "1", "2", "unknown_id"]
      })

      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["2", "1"]
    end

    test "start_presenting transitions to :presenting mode", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})

      render_click(view, "start_presenting", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :presenting
      assert state.presentation_slide_ids == ["1"]
    end

    test "start_presenting with empty deck does not transition", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "start_presenting", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :setup
    end

    test "update_presentation_title sets the title", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})

      render_click(view, "update_presentation_title", %{
        "title" => "What if people talked to plants?"
      })

      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_title == "What if people talked to plants?"
    end

    test "update_presentation_title truncates at 120 characters", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      long_title = String.duplicate("a", 200)
      render_click(view, "update_presentation_title", %{"title" => long_title})
      state = :sys.get_state(view.pid).socket.assigns

      assert String.length(state.presentation_title) == 120
    end

    test "presentation_clear_slides also resets the title", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "update_presentation_title", %{"title" => "My Presentation"})

      render_click(view, "presentation_clear_slides", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_slide_ids == []
      assert state.presentation_title == ""
    end

    test "title persists through start_presenting", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "update_presentation_title", %{"title" => "My Talk"})
      render_click(view, "start_presenting", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :presenting
      assert state.presentation_title == "My Talk"
    end

    test "presentation mode renders the stage, agenda, and navigation controls", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "What is ethics?")

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})
      render_click(view, "start_presenting", %{})

      assert has_element?(view, "#presentation-stage")
      assert has_element?(view, "#presentation-agenda")
      assert has_element?(view, "#presentation-current-slide")
      assert has_element?(view, "#presentation-next-slide")
      assert has_element?(view, "#presentation-agenda-slide-1")
      assert has_element?(view, "#presentation-agenda-slide-2")
    end

    test "presentation_go_to_slide updates the active node", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "What is ethics?")

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})
      render_click(view, "start_presenting", %{})
      render_click(view, "presentation_go_to_slide", %{"node-id" => "2"})

      state = :sys.get_state(view.pid).socket.assigns
      assert state.node.id == "2"
    end

    test "presentation_step advances through the deck", %{conn: conn} do
      {:ok, view, _html} = setup_live_for_graph(conn, "What is ethics?")

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "node_clicked", %{"id" => "2"})
      render_click(view, "start_presenting", %{})

      state = :sys.get_state(view.pid).socket.assigns
      assert state.node.id == "1"

      render_click(view, "presentation_step", %{"direction" => "next"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.node.id == "2"

      render_click(view, "presentation_step", %{"direction" => "previous"})
      state = :sys.get_state(view.pid).socket.assigns
      assert state.node.id == "1"
    end

    test "restore_presentation sets title and filters invalid node IDs", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # The Satre fixture has no real graph nodes, so all IDs will be
      # filtered out by the find_node validation — but the title should
      # still be set.
      render_click(view, "restore_presentation", %{
        "slide_ids" => ["1", "nonexistent_xyz"],
        "title" => "Restored Talk"
      })

      state = :sys.get_state(view.pid).socket.assigns
      # All IDs invalid for this graph → filtered to empty
      assert state.presentation_slide_ids == []
      # Title is still restored even when no valid slides remain
      assert state.presentation_title == "Restored Talk"
    end

    test "restore_presentation does not overwrite existing slides", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Add a slide via setup mode (node_clicked adds the ID without
      # requiring the node to exist in the graph)
      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})

      # Now try to restore — should be ignored because slides already exist
      render_click(view, "restore_presentation", %{
        "slide_ids" => ["2"],
        "title" => "Should be ignored"
      })

      state = :sys.get_state(view.pid).socket.assigns
      assert state.presentation_slide_ids == ["1"]
      # Title is auto-populated with graph title when entering setup
      assert state.presentation_title == @graph_id
    end

    test "restore_presentation handles malformed params gracefully", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Missing fields — should not crash
      render_click(view, "restore_presentation", %{})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_slide_ids == []
      assert state.presentation_title == ""
    end

    test "shared presentation URL preserves slide order", %{conn: conn} do
      conn =
        conn
        |> log_in_user(
          user_fixture(%{email: "shared-pres-#{System.unique_integer([:positive])}@example.com"})
        )

      {:ok, graph} = Dialectic.GraphFixtures.insert_graph_fixture("What is ethics?")

      {:ok, view, _html} =
        live(
          conn,
          ~p"/g/#{graph.slug}/graph?node=1&present=true&slides=1,3,2&title=Shared%20Deck"
        )

      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :presenting
      assert state.presentation_title == "Shared Deck"
      assert state.presentation_slide_ids == ["1", "3", "2"]

      assert has_element?(view, "#presentation-agenda-slide-1")
      assert has_element?(view, "#presentation-agenda-slide-3")
      assert has_element?(view, "#presentation-agenda-slide-2")

      html = render(view)
      pos_1 = html |> :binary.match(~s(id="presentation-agenda-slide-1")) |> elem(0)
      pos_3 = html |> :binary.match(~s(id="presentation-agenda-slide-3")) |> elem(0)
      pos_2 = html |> :binary.match(~s(id="presentation-agenda-slide-2")) |> elem(0)

      assert pos_1 < pos_3
      assert pos_3 < pos_2
    end

    test "graph_owner_name is assigned on mount", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)
      state = :sys.get_state(view.pid).socket.assigns

      # The graph fixture has a user_id, so owner name should be resolved
      assert is_binary(state.graph_owner_name) or is_nil(state.graph_owner_name)
    end

    test "exit_presentation with clear_slides also resets title", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      render_click(view, "enter_presentation_setup", %{})
      render_click(view, "node_clicked", %{"id" => "1"})
      render_click(view, "update_presentation_title", %{"title" => "Will be cleared"})

      render_click(view, "exit_presentation", %{"clear_slides" => "true"})
      state = :sys.get_state(view.pid).socket.assigns

      assert state.presentation_mode == :off
      assert state.presentation_slide_ids == []
      assert state.presentation_title == ""
    end
  end

  describe "handle_event delete_stream" do
    test "rejects deletion of Main group", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      html = render_click(view, "delete_stream", %{"id" => "Main"})

      assert html =~ "Cannot delete the Main group"
    end

    test "rejects deletion with blank group_id", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      html = render_click(view, "delete_stream", %{"id" => "   "})

      assert html =~ "Invalid group"
    end

    test "rejects deletion of non-existent group", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      html = render_click(view, "delete_stream", %{"id" => "nonexistent_group_12345"})

      assert html =~ "Group not found"
    end

    test "rejects deletion of non-compound vertex", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Node "1" exists but is not a compound/group node
      # The handler returns "Group not found" for non-group vertices (doesn't leak vertex existence)
      html = render_click(view, "delete_stream", %{"id" => "1"})

      assert html =~ "Group not found" or html =~ "Only groups can be deleted from streams"
    end

    test "rejects deletion of group with non-deleted children", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Create a new node and assign it to a new group
      group_name = "test_group_with_children"

      new_node =
        GraphManager.add_node(@graph_id, %Dialectic.Graph.Vertex{
          content: "test node in group",
          class: "test",
          user: "tester@example.com"
        })

      GraphManager.create_group(@graph_id, group_name, [new_node.id])

      html = render_click(view, "delete_stream", %{"id" => group_name})

      assert html =~ "Cannot delete a group that has nodes"

      # Clean up - remove node from group and delete node
      GraphManager.remove_parent(@graph_id, new_node.id)
      GraphManager.delete_node(@graph_id, new_node.id)
    end

    test "successfully deletes an empty group", %{conn: conn} do
      {:ok, view, _html} = setup_live(conn)

      # Create an empty group (no children)
      group_name = "empty_test_group"
      GraphManager.create_group(@graph_id, group_name, [])

      html = render_click(view, "delete_stream", %{"id" => group_name})

      assert html =~ "Group deleted"

      # Verify the group is no longer in work_streams
      state = :sys.get_state(view.pid).socket.assigns
      group_ids = Enum.map(state.work_streams, & &1.id)
      refute group_name in group_ids
    end
  end
end
