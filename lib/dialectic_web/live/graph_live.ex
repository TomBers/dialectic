defmodule DialecticWeb.GraphLive do
  use DialecticWeb, :live_view

  # =========================================================================
  # Critical Thinking Tools Configuration
  # =========================================================================
  # Maps tool names to their GraphActions function names and whether they support text selection
  @critical_thinking_tools %{
    clarify: %{function: :clarify, text_function: :clarify_text, supports_text: true},
    assumptions: %{function: :assumptions, text_function: :assumptions_text, supports_text: true},
    counterexample: %{
      function: :counterexample,
      text_function: :counterexample_text,
      supports_text: true
    },
    implications: %{
      function: :implications,
      text_function: :implications_text,
      supports_text: true
    },
    blind_spots: %{function: :blind_spots, text_function: :blind_spots_text, supports_text: true},
    says_who: %{function: :says_who, text_function: :says_who_text, supports_text: true},
    who_disagrees: %{
      function: :who_disagrees,
      text_function: :who_disagrees_text,
      supports_text: true
    },
    steel_man: %{function: :steel_man, text_function: :steel_man_text, supports_text: true},
    what_if: %{function: :what_if, text_function: :what_if_text, supports_text: true}
  }

  @critical_thinking_operations @critical_thinking_tools
                                |> Map.keys()
                                |> Enum.map(&Atom.to_string/1)
  @node_creation_operations [
                              "start_stream",
                              "comment",
                              "answer",
                              "branch",
                              "combine",
                              "ideas",
                              "explain",
                              "selection_question",
                              "regenerate"
                            ] ++ @critical_thinking_operations
  @structural_graph_operations ["delete" | @node_creation_operations]
  @max_explore_items 3
  use DialecticWeb.GraphStreaming, preload_highlight_links: true

  alias Dialectic.Graph.{Vertex, GraphActions, Siblings}
  alias Dialectic.Responses.GuidedLearningPlan
  alias Dialectic.Accounts.User
  alias DialecticWeb.GridChat
  alias DialecticWeb.NodeComp
  alias DialecticWeb.GraphHelpers
  alias DialecticWeb.HighlightShare
  alias DialecticWeb.NodeSearch

  import DialecticWeb.GraphPresentation
  import DialecticWeb.GridChatComp, only: [grid_chat_drawer: 1, grid_chat_toggle: 1]
  import DialecticWeb.PresentationStageComp, only: [presentation_stage: 1]

  alias DialecticWeb.Utils.UserUtils
  alias DialecticWeb.Utils.NodeTitleHelper
  alias Dialectic.Highlights
  alias Dialectic.Follows
  alias Dialectic.GridActivity
  alias Dialectic.Repo

  alias Phoenix.PubSub

  import Ecto.Query

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  # ── handle_params: auto-start presentation from URL query params ──
  # Called after mount on initial page load and on every live_patch.
  # Detects ?present=true&slides=1,2,3&title=... and boots directly into
  # presenting mode so shared links open the presentation automatically.
  @impl true
  def handle_params(%{"present" => "true", "slides" => slides_str} = params, _uri, socket) do
    slide_ids =
      slides_str
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(&to_string/1)

    # Filter out IDs for nodes that no longer exist in the graph so that
    # stale shared links degrade gracefully (correct slide count, no gaps
    # in badge numbering, and an empty-slides fallback when all are gone).
    graph_id = socket.assigns.graph_id
    socket = assign_reader_path(socket, params["path"])

    valid_slide_ids =
      Enum.filter(slide_ids, fn id ->
        GraphActions.find_node(graph_id, id) != nil
      end)

    title =
      case Map.get(params, "title") do
        nil -> socket.assigns.graph_struct.title
        "" -> socket.assigns.graph_struct.title
        t -> t
      end

    if length(valid_slide_ids) > 0 and connected?(socket) do
      socket =
        socket
        |> assign(
          presentation_mode: :presenting,
          presentation_slide_ids: valid_slide_ids,
          presentation_title: title
        )
        |> push_event("presentation_clear_slides", %{})
        |> push_event("toggle_site_header", %{visible: false})

      {:noreply, socket}
    else
      # No valid slides remain (all deleted) or static render — stay in
      # normal mode so the user sees the full graph instead of a blank screen.
      {:noreply,
       socket
       |> assign(
         presentation_slide_ids: valid_slide_ids,
         presentation_title: title
       )}
    end
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign_reader_path(socket, params["path"])}
  end

  @impl true
  def mount(%{"graph_name" => graph_id_uri} = params, session, socket) do
    graph_id = URI.decode(graph_id_uri)
    user = UserUtils.current_identity(socket.assigns)
    socket = assign(socket, :llm_actor_id, session["llm_actor_id"] || "graph:#{graph_id}")

    case fetch_graph(socket.assigns[:current_user], graph_id, params) do
      {:ok, {graph_struct, _}, graph_db} ->
        # Use the actual title for all internal operations
        graph_title = graph_db.title

        _ =
          Dialectic.Responses.ModeServer.set_mode(
            graph_title,
            graph_db.prompt_mode || "university"
          )

        # Ensure a main group exists
        _ = ensure_main_group(graph_title)

        {node_id, initial_highlight_id} = resolve_target_node(graph_title, params)

        node =
          case GraphManager.best_node(graph_title, node_id) do
            nil -> default_node()
            v -> v
          end

        socket =
          socket
          |> assign_defaults()
          |> subscribe_to_topics(graph_title)
          |> assign_graph_data(graph_db, graph_struct, node, graph_title, user)
          |> assign(token: params["token"])
          |> handle_initial_highlight(initial_highlight_id)

        {:ok, socket}

      {:error, error_message} ->
        socket =
          socket
          |> put_flash(:error, error_message)
          |> redirect(to: ~p"/")

        {:ok, socket}
    end
  end

  defp default_node do
    GraphHelpers.default_node()
  end

  @impl true
  def handle_event("send_grid_chat", %{"grid_chat" => %{"message" => message}}, socket) do
    {:noreply, GridChat.send_message(socket, message)}
  end

  def handle_event("open_grid_chat", _params, socket) do
    {:noreply, GridChat.open(socket)}
  end

  def handle_event("open_prompt_settings", _params, socket) do
    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      open_section: "configure"
    )

    {:noreply, socket}
  end

  def handle_event("set_prompt_mode", %{"prompt_mode" => mode}, socket) do
    graph_id = socket.assigns.graph_id

    normalized =
      case String.downcase(to_string(mode)) do
        "expert" -> :expert
        "high_school" -> :high_school
        "simple" -> :high_school
        _ -> :university
      end

    mode_str = Atom.to_string(normalized)

    if normalized in [:university, :expert] and is_nil(socket.assigns[:current_user]) do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      if is_binary(graph_id) do
        _ = Dialectic.Responses.ModeServer.set_mode(graph_id, normalized)

        case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
          nil ->
            :noop

          graph ->
            graph
            |> Dialectic.Accounts.Graph.changeset(%{prompt_mode: mode_str})
            |> Dialectic.Repo.update()
        end
      end

      send_update(
        DialecticWeb.RightPanelComp,
        id: "right-panel-comp",
        prompt_mode: mode_str
      )

      {:noreply, assign(socket, prompt_mode: mode_str)}
    end
  end

  def handle_event("set_reader_path", %{"id" => path_endpoint}, socket) do
    {:noreply, assign_reader_path(socket, path_endpoint)}
  end

  def handle_event("clear_reader_path", _params, socket) do
    {:noreply, assign(socket, reader_path_endpoint: nil, reader_path_ids: [])}
  end

  def handle_event("node:join_group", %{"node" => nid, "parent" => gid}, socket) do
    _graph = GraphManager.set_parent(socket.assigns.graph_id, nid, gid)
    GraphManager.save_graph(socket.assigns.graph_id)

    {:noreply,
     socket
     |> assign(
       f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
       graph_operation: "join_group"
     )}
  end

  def handle_event("node:leave_group", %{"node" => nid}, socket) do
    # Server-side guard: do not allow leaving if it would leave the group empty
    case GraphManager.vertex_label(socket.assigns.graph_id, nid) do
      %{} = v ->
        parent_id = Map.get(v, :parent)

        if is_binary(parent_id) do
          children_count =
            GraphManager.vertices(socket.assigns.graph_id)
            |> Enum.count(fn vid ->
              case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                %{} = lbl -> Map.get(lbl, :parent) == parent_id
                _ -> false
              end
            end)

          if children_count <= 1 do
            # Block leaving the last child; no-op
            {:noreply, socket}
          else
            _graph = GraphManager.remove_parent(socket.assigns.graph_id, nid)
            GraphManager.save_graph(socket.assigns.graph_id)

            {:noreply,
             socket
             |> assign(
               f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
               graph_operation: "leave_group"
             )}
          end
        else
          {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  # Handle form submission and change events
  def handle_event("search_nodes", params, socket) do
    search_term = params["search_term"] || params["value"] || ""

    if search_term == "" do
      {:noreply,
       socket
       |> assign(search_term: "", search_results: [])
       |> push_event("clear_search_highlights", %{})}
    else
      search_results =
        try do
          GraphManager.vertices(socket.assigns.graph_id)
          |> Enum.reduce([], fn vid, acc ->
            case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
              %{} = vertex ->
                if valid_search_node(vertex) do
                  case NodeSearch.annotate_result(vertex, search_term) do
                    %{search_rank: rank} = result ->
                      [{rank, vertex.id, result} | acc]

                    nil ->
                      acc
                  end
                else
                  acc
                end

              _ ->
                acc
            end
          end)
          |> Enum.sort()
          |> Enum.map(fn {_, _, vertex} -> vertex end)
          |> Enum.take(10)
        rescue
          _ -> []
        catch
          :exit, _reason -> []
        end

      matching_ids = Enum.map(search_results, & &1.id)

      {:noreply,
       socket
       |> assign(search_term: search_term, search_results: search_results)
       |> push_event("highlight_search_results", %{ids: matching_ids})}
    end
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     socket
     |> assign(search_term: "", search_results: [])
     |> push_event("clear_search_highlights", %{})}
  end

  def handle_event("open_search_overlay_click", _params, socket) do
    {:noreply, assign(socket, show_search_overlay: true)}
  end

  def handle_event("open_search_overlay", params, socket) do
    meta = params["metaKey"] in [true, "true"]
    cmd = params["cmdKey"] in [true, "true"]
    editable = params["isEditable"] in [true, "true"]

    if (meta || cmd) && !editable do
      {:noreply, assign(socket, show_search_overlay: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_search_overlay", _, socket) do
    {:noreply,
     socket
     |> assign(show_search_overlay: false, search_term: "", search_results: [])
     |> push_event("clear_search_highlights", %{})}
  end

  def handle_event("toggle_ask_question", _, socket) do
    {:noreply, assign(socket, ask_question: !socket.assigns.ask_question)}
  end

  def handle_event("toggle_lock_graph", _, socket) do
    graph_struct = GraphActions.toggle_graph_locked(graph_action_params(socket))
    can_edit = !graph_struct.is_locked

    {:noreply,
     socket
     |> assign(graph_struct: graph_struct, can_edit: can_edit)
     |> push_event("analytics", %{
       event: "access_settings_changed",
       params: %{setting: "editing", enabled: to_string(can_edit)}
     })}
  end

  def handle_event("toggle_public_graph", _, socket) do
    graph_struct = GraphActions.toggle_graph_public(graph_action_params(socket))

    {:noreply,
     socket
     |> assign(graph_struct: graph_struct)
     |> push_event("analytics", %{
       event: "access_settings_changed",
       params: %{
         setting: "visibility",
         visibility: if(graph_struct.is_public, do: "public", else: "private")
       }
     })}
  end

  def handle_event("follow_graph", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:noreply, assign(socket, show_login_modal: true)}

      user ->
        case Follows.follow_graph(user, socket.assigns.graph_struct) do
          {:ok, _follow} ->
            {:noreply,
             socket
             |> assign(:following_graph?, true)
             |> put_flash(:info, "Grid followed.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not follow this grid.")}
        end
    end
  end

  def handle_event("unfollow_graph", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:noreply, assign(socket, show_login_modal: true)}

      user ->
        {:ok, _count} = Follows.unfollow_graph(user, socket.assigns.graph_struct)

        {:noreply,
         socket
         |> assign(:following_graph?, false)
         |> put_flash(:info, "Grid unfollowed.")}
    end
  end

  def handle_event("note", %{"node" => node_id}, socket) do
    case GraphHelpers.handle_note(socket, node_id, :note) do
      {:noreply, socket} -> {:noreply, socket}
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
    end
  end

  def handle_event("toggle_node_menu", _, socket) do
    {:noreply,
     socket
     |> assign(:node_menu_visible, !socket.assigns.node_menu_visible)}
  end

  def handle_event("unnote", %{"node" => node_id}, socket) do
    case GraphHelpers.handle_note(socket, node_id, :unnote) do
      {:noreply, socket} -> {:noreply, socket}
      {:ok, graph_result, operation} -> update_graph(socket, graph_result, operation)
    end
  end

  def handle_event("delete_node", %{"node" => node_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      if socket.assigns.current_user == nil do
        {:noreply, assign(socket, show_login_modal: true)}
      else
        case GraphActions.find_node(socket.assigns.graph_id, node_id) do
          nil ->
            {:noreply, socket |> put_flash(:error, "Node not found")}

          node ->
            children = Map.get(node, :children, [])

            owns = UserUtils.owner?(node, socket.assigns)

            cond do
              not owns ->
                {:noreply, socket |> put_flash(:error, "You can only delete nodes you created")}

              Enum.any?(children, fn ch -> not Map.get(ch, :deleted, false) end) ->
                {:noreply,
                 socket |> put_flash(:error, "Cannot delete a node that has non-deleted children")}

              true ->
                # Remove any highlight links that point to this node
                alias Dialectic.Highlights.HighlightLink

                Repo.delete_all(
                  from l in HighlightLink,
                    where: l.node_id == ^node_id
                )

                next_node =
                  GraphActions.delete_node(graph_action_params(socket), node_id)

                _ =
                  GridActivity.record_node_deleted_async(
                    socket.assigns.graph_id,
                    activity_actor(socket),
                    node
                  )

                GraphManager.save_graph(socket.assigns.graph_id)
                {_, _graph2} = GraphManager.get_graph(socket.assigns.graph_id)

                # Ensure we navigate to a valid, non-deleted node.
                # If no parent exists or it's invalid/deleted, pick the first non-deleted node in the graph.
                selected_node =
                  cond do
                    is_map(next_node) and not Map.get(next_node, :deleted, false) ->
                      # Resolve via manager to ensure relatives and current graph state
                      GraphActions.find_node(socket.assigns.graph_id, next_node.id)

                    true ->
                      fallback =
                        GraphManager.vertices(socket.assigns.graph_id)
                        |> Enum.find_value(fn vid ->
                          case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                            %{} = v ->
                              if not Map.get(v, :deleted, false), do: v, else: nil

                            _ ->
                              nil
                          end
                        end)

                      if fallback do
                        GraphActions.find_node(socket.assigns.graph_id, fallback.id)
                      else
                        default_node()
                      end
                  end

                {:noreply, updated_socket} =
                  update_graph(socket, {nil, selected_node}, "delete")

                {:noreply, updated_socket |> put_flash(:info, "Node deleted")}
            end
        end
      end
    end
  end

  def handle_event("branch_list", %{"items" => items}, socket) do
    items = items |> normalize_explore_selected() |> Enum.uniq()

    cond do
      !socket.assigns.can_edit ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}

      items == [] ->
        {:noreply, socket |> put_flash(:error, "Please select at least one point")}

      length(items) > @max_explore_items ->
        {:noreply, put_explore_limit_flash(socket)}

      true ->
        nodes =
          Enum.map(items, fn item ->
            GraphActions.answer_selection(
              graph_action_params(socket, socket.assigns.node),
              "Please explain: #{item}",
              "explain"
            )
          end)

        begin_background_generations(
          socket,
          nodes,
          "explain",
          explore_generation_label(items),
          target_node_id: explore_target_node_id(nodes, socket.assigns.node.id)
        )
    end
  end

  def handle_event("submit_guided_paths", params, socket) do
    with :ok <- validate_logged_in(socket),
         :ok <- validate_can_edit(socket),
         {:ok, %{class: "learning_plan"} = plan_node} <-
           find_node_safe(socket.assigns.graph_id, socket.assigns.node.id),
         {:ok, _guided_plan} <- GuidedLearningPlan.normalize(plan_node.guided_plan),
         {:ok, target_node} <- guided_action_target(socket.assigns.graph_id, plan_node) do
      paths =
        plan_node
        |> guided_paths()
        |> annotate_guided_paths(plan_node, target_node)

      selected_paths = selected_guided_paths(params, paths)

      cond do
        selected_paths == [] ->
          {:noreply, put_flash(socket, :error, "Please select at least one available path")}

        length(selected_paths) > @max_explore_items ->
          {:noreply, put_explore_limit_flash(socket)}

        true ->
          created_paths =
            Enum.flat_map(selected_paths, fn path ->
              submission_key = guided_path_submission_key(path.id)

              case GraphManager.reserve_guided_submission(
                     socket.assigns.graph_id,
                     plan_node.id,
                     submission_key
                   ) do
                :ok ->
                  {_graph, answer_node} =
                    GraphActions.ask_and_answer(
                      graph_action_params(socket, plan_node),
                      path.question,
                      await_generation: true,
                      guided_submission: guided_submission_metadata(plan_node, submission_key)
                    )

                  if is_map(answer_node) do
                    [{path, answer_node}]
                  else
                    release_guided_submission(socket, plan_node, submission_key)
                    []
                  end

                {:error, _reason} ->
                  []
              end
            end)

          case created_paths do
            [] ->
              {:noreply,
               put_flash(socket, :error, "Those paths are already being explored or completed")}

            created_paths ->
              begin_background_generations(
                socket,
                Enum.map(created_paths, &elem(&1, 1)),
                "answer",
                created_paths |> Enum.map(&elem(&1, 0)) |> guided_paths_generation_label()
              )
          end
      end
    else
      {:error, :login_required} ->
        {:noreply, assign(socket, show_login_modal: true)}

      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      _invalid_plan ->
        {:noreply, put_flash(socket, :error, "The path plan is no longer available")}
    end
  end

  def handle_event(
        "apply_guided_next_action",
        %{"action" => action, "id" => plan_node_id},
        socket
      ) do
    with :ok <- validate_logged_in(socket),
         :ok <- validate_can_edit(socket),
         {:ok, plan_node} <- find_node_safe(socket.assigns.graph_id, plan_node_id),
         true <- Map.get(plan_node, :class) == "learning_plan",
         {:ok, _guided_plan} <- GuidedLearningPlan.normalize(plan_node.guided_plan),
         true <- guided_action_recommended?(plan_node, action),
         {:ok, target_node} <- guided_action_target(socket.assigns.graph_id, plan_node),
         false <- guided_action_used?(plan_node, target_node, action),
         :ok <-
           GraphManager.reserve_guided_submission(
             socket.assigns.graph_id,
             plan_node.id,
             guided_action_submission_key(action)
           ) do
      apply_guided_action(action, plan_node, target_node, socket)
    else
      {:error, :login_required} ->
        {:noreply, assign(socket, show_login_modal: true)}

      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      true ->
        {:noreply, put_flash(socket, :error, "That action has already been used here")}

      {:error, :already_reserved} ->
        {:noreply, put_flash(socket, :error, "That action has already been used here")}

      _invalid_recommendation ->
        {:noreply, put_flash(socket, :error, "That recommended action is no longer available")}
    end
  end

  def handle_event("open_explore_modal", %{"items" => items}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      {:noreply,
       socket
       |> assign(show_explore_modal: true, explore_items: items, explore_selected: [])}
    end
  end

  def handle_event("close_explore_modal", _, socket) do
    {:noreply, assign(socket, show_explore_modal: false, explore_items: [], explore_selected: [])}
  end

  def handle_event("submit_explore_modal", params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      selected = params |> normalize_explore_selected() |> Enum.uniq()

      cond do
        selected == [] ->
          {:noreply, socket |> put_flash(:error, "Please select at least one point")}

        length(selected) > @max_explore_items ->
          {:noreply, put_explore_limit_flash(socket)}

        true ->
          nodes =
            Enum.map(selected, fn item ->
              GraphActions.answer_selection(
                graph_action_params(socket, socket.assigns.node),
                "Please explain: #{item}",
                "explain"
              )
            end)

          socket =
            assign(socket,
              show_explore_modal: false,
              explore_items: [],
              explore_selected: []
            )

          begin_background_generations(
            socket,
            nodes,
            "explain",
            explore_generation_label(selected),
            target_node_id: explore_target_node_id(nodes, socket.assigns.node.id)
          )
      end
    end
  end

  def handle_event("node_branch", %{"id" => node_id}, socket) do
    cond do
      !socket.assigns.can_edit ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id) ->
        nodes = create_branch_nodes(socket, parent_node)

        begin_background_generations(
          socket,
          nodes,
          "branch",
          "Building the strongest case for and against this idea",
          target_node_id: parent_node.id
        )

      true ->
        {:noreply, put_flash(socket, :error, "Node not found")}
    end
  end

  def handle_event("node_combine", params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      case Map.get(params, "id") do
        nil ->
          if socket.assigns.combine_mode == :setup do
            socket =
              socket
              |> assign(combine_mode: :off, combine_selected_nodes: [])
              |> push_event("combine_clear_highlights", %{})

            {:noreply, socket}
          else
            socket =
              socket
              |> assign(combine_mode: :setup, combine_selected_nodes: [])

            {:noreply, socket}
          end

        node_id ->
          case GraphActions.find_node(socket.assigns.graph_id, node_id) do
            nil ->
              {:noreply, socket}

            node ->
              selected =
                if socket.assigns.combine_mode == :setup do
                  socket.assigns.combine_selected_nodes
                else
                  []
                end

              updated_selected = add_combine_node(selected, node)

              socket =
                socket
                |> assign(combine_mode: :setup, combine_selected_nodes: updated_selected)
                |> push_event("combine_highlight_nodes", %{
                  ids: Enum.map(updated_selected, & &1.id)
                })

              {:noreply, socket}
          end
      end
    end
  end

  def handle_event("node_related_ideas", %{"id" => node_id}, socket) do
    case GraphHelpers.handle_related_ideas(socket, node_id) do
      {:ok, {_graph, node}, operation} ->
        begin_foreground_generation(
          socket,
          node,
          operation
        )

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  # =========================================================================
  # Advanced Tools — Cluster 1: Core Inquiry Moves
  # =========================================================================

  # =========================================================================
  # Critical Thinking Tools - Generic Handler
  # =========================================================================

  @doc """
  Generic handler for all critical thinking tool actions on nodes.

  Handles events like "node_clarify", "node_assumptions", etc. by:
  1. Checking if the graph is editable
  2. Finding the target node
  3. Calling the appropriate GraphActions function
  4. Updating the graph with the result

  ## Parameters
  - event_name: String like "node_clarify", "node_assumptions", etc.
  - params: Map containing "id" (node_id)
  - socket: LiveView socket

  ## Returns
  - `{:noreply, socket}` with updated graph or error flash
  """
  for {tool_name, _config} <- @critical_thinking_tools do
    tool_string = Atom.to_string(tool_name)

    def handle_event("node_" <> unquote(tool_string), %{"id" => node_id}, socket) do
      apply_critical_thinking_tool(unquote(tool_name), node_id, socket)
    end
  end

  def handle_event("node_regenerate", %{"id" => node_id}, socket) do
    with :ok <- validate_can_edit(socket),
         {:ok, node} <- find_node_safe(socket.assigns.graph_id, node_id),
         :ok <- validate_regeneration_access(node, socket),
         :ok <- reserve_regeneration(node, socket) do
      case GraphActions.regenerate_node(graph_action_params(socket), node_id) do
        {:error, reason} ->
          release_regeneration(node, socket)
          {:noreply, put_flash(socket, :error, reason)}

        {:ok, new_node} ->
          socket =
            assign(socket,
              streaming_nodes:
                socket.assigns.streaming_nodes
                |> MapSet.delete(node_id)
                |> MapSet.put(new_node.id)
            )

          update_graph(socket, {nil, new_node}, "regenerate")
      end
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      {:error, :login_required} ->
        {:noreply, assign(socket, show_login_modal: true)}

      {:error, :node_not_found} ->
        {:noreply, put_flash(socket, :error, "Node not found")}

      {:error, :already_reserved} ->
        {:noreply, put_flash(socket, :error, "This learning plan is already being used")}

      {:error, :invalid_guided_plan} ->
        {:noreply, put_flash(socket, :error, "This learning plan is no longer available")}
    end
  end

  def handle_event("navigate_to_node", %{"node_id" => node_id} = _params, socket) do
    # Navigate to a node (e.g., from clicking a highlight link)
    node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node do
      socket = clear_background_generation(socket, node_id)

      {:noreply, updated_socket} =
        update_graph(
          socket,
          {nil, node},
          "node_clicked"
        )

      # Reveal only the ancestors needed to make the target visible.
      updated_socket = push_event(updated_socket, "center_node", %{id: node_id})

      {:noreply, updated_socket}
    else
      {:noreply, socket |> put_flash(:error, "Node not found")}
    end
  end

  def handle_event("open_background_answer", %{"id" => generation_id}, socket) do
    generation = Map.get(socket.assigns.background_generations, generation_id)
    node_id = if generation, do: generation.target_node_id, else: generation_id
    node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    if node do
      socket = clear_completed_background_generations(socket)

      socket =
        if socket.assigns.reader_path_ids == [] do
          socket
        else
          assign_reader_path(socket, node_id)
        end

      {:noreply, updated_socket} = update_graph(socket, {nil, node}, "node_clicked")

      {:noreply,
       updated_socket
       |> push_event("center_node", %{id: node_id})
       |> push_event("reflow_layout", %{id: node_id})}
    else
      {:noreply, put_flash(socket, :error, "Answer not found")}
    end
  end

  def handle_event("node_clicked", %{"id" => id} = params, socket) do
    # When in combine setup mode, clicking a node toggles it in the selection
    cond do
      socket.assigns.combine_mode == :setup ->
        selected = socket.assigns.combine_selected_nodes
        node = GraphActions.find_node(socket.assigns.graph_id, id)
        from_search = params["from-search"] == "true"

        if node == nil do
          {:noreply, socket}
        else
          updated_selected =
            if Enum.any?(selected, fn n -> n.id == id end) do
              Enum.reject(selected, fn n -> n.id == id end)
            else
              add_combine_node(selected, node)
            end

          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          updated_socket = reapply_right_panel_state(socket, updated_socket)

          updated_socket =
            updated_socket
            |> assign(combine_selected_nodes: updated_selected)
            |> push_event("combine_highlight_nodes", %{ids: Enum.map(updated_selected, & &1.id)})
            |> push_event("center_node", %{id: id})
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, updated_socket}
        end

      socket.assigns.presentation_mode == :setup ->
        ids = socket.assigns.presentation_slide_ids
        from_search = params["from-search"] == "true"

        updated_ids =
          if id in ids do
            List.delete(ids, id)
          else
            ids ++ [id]
          end

        # Still navigate to the node so the user can see its content
        node = GraphActions.find_node(socket.assigns.graph_id, id)

        if node == nil do
          socket =
            socket
            |> assign(presentation_slide_ids: updated_ids)
            |> push_presentation_highlights()
            |> push_presentation_persistence()
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, socket}
        else
          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          updated_socket = reapply_right_panel_state(socket, updated_socket)

          updated_socket =
            updated_socket
            |> assign(presentation_slide_ids: updated_ids)
            |> push_presentation_highlights()
            |> push_presentation_persistence()
            |> push_event("center_node", %{id: id})
            |> then(fn s ->
              if from_search do
                s
                |> assign(show_search_overlay: false, search_term: "", search_results: [])
                |> push_event("clear_search_highlights", %{})
              else
                s
              end
            end)

          {:noreply, updated_socket}
        end

      true ->
        # Normal mode — original behaviour
        # Determine if this was triggered from search results via explicit param
        from_search = params["from-search"] == "true"

        # Update the graph
        node = GraphActions.find_node(socket.assigns.graph_id, id)

        if node == nil do
          {:noreply, socket}
        else
          {:noreply, updated_socket} =
            update_graph(socket, {nil, node}, "node_clicked")

          # Preserve and re-apply panel/menu state across node changes
          updated_socket = reapply_right_panel_state(socket, updated_socket)

          # Close the quick search overlay and clear highlights when navigating from search
          updated_socket =
            if from_search do
              updated_socket
              |> assign(show_search_overlay: false, search_term: "", search_results: [])
              |> push_event("clear_search_highlights", %{})
              |> push_event("center_node", %{id: id})
            else
              # Always center the node on the graph (e.g. when clicked from the ask form indicator)
              push_event(updated_socket, "center_node", %{id: id})
            end

          {:noreply, updated_socket}
        end
    end
  end

  def handle_event("highlight_clicked", %{"id" => highlight_id} = params, socket) do
    node_id = params["node-id"] || params["node_id"]

    socket =
      if (is_binary(node_id) and socket.assigns.node) && socket.assigns.node.id == node_id do
        socket
        |> push_event("center_node", %{id: node_id})
      else
        case GraphManager.find_node_by_id(socket.assigns.graph_id, node_id) do
          nil ->
            socket

          node ->
            {_, socket} = update_graph(socket, {nil, node}, "node_clicked")

            push_event(socket, "center_node", %{id: node.id})
        end
      end

    {:noreply, push_event(socket, "scroll_to_highlight", %{id: highlight_id})}
  end

  # Ignore arrow-key navigation when the user is typing in a text field
  def handle_event("node_move", %{"isEditable" => true}, socket), do: {:noreply, socket}

  def handle_event("node_move", %{"direction" => direction}, socket) do
    if socket.assigns.node do
      {:noreply, updated_socket} =
        update_graph(
          socket,
          {nil, GraphActions.move(graph_action_params(socket), direction)},
          "node_clicked"
        )

      # Preserve and re-apply panel/menu state across node moves
      updated_socket = reapply_right_panel_state(socket, updated_socket)

      {:noreply, push_event(updated_socket, "center_node", %{id: updated_socket.assigns.node.id})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("answer", %{"vertex" => %{"content" => ""}}, socket), do: {:noreply, socket}

  def handle_event("answer", %{"vertex" => %{"content" => answer}}, socket) do
    case GraphHelpers.handle_answer(socket, answer) do
      {:ok, graph_result, operation} ->
        socket
        |> push_event("analytics", %{event: "claim_added", params: %{entry_method: "post"}})
        |> update_graph(graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  # Ignore empty submissions for both Ask (AI) and Post (comment-only) paths
  def handle_event("reply-and-answer", %{"vertex" => %{"content" => ""}}, socket),
    do: {:noreply, socket}

  def handle_event(
        "reply-and-answer",
        %{"vertex" => %{"content" => answer}, "submit_action" => "post"},
        socket
      ) do
    case GraphHelpers.handle_answer(socket, answer) do
      {:ok, graph_result, operation} ->
        socket
        |> push_event("analytics", %{event: "claim_added", params: %{entry_method: "post"}})
        |> update_graph(graph_result, operation)

      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}
    end
  end

  def handle_event(
        "reply-and-answer",
        %{"vertex" => %{"content" => answer}, "prefix" => prefix} = params,
        socket
      ) do
    minimal_context = prefix == "explain"
    highlight_context = Map.get(params, "highlight_context")

    if guided_learning_login_required?(params, socket) do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      case GraphHelpers.handle_reply_and_answer(socket, answer,
             minimal_context: minimal_context,
             highlight_context: highlight_context,
             guided_learning: guided_learning_enabled?(params)
           ) do
        {:ok, {_graph, node}, operation} ->
          socket
          |> push_event("analytics", %{event: "question_added", params: %{ai_requested: "true"}})
          |> reset_ask_form()
          |> begin_query_generation(
            node,
            operation,
            "Answering #{quoted_selection(answer)}",
            params
          )

        {:error, :locked} ->
          {:noreply, socket |> put_flash(:error, "This graph is locked")}
      end
    end
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}} = params, socket) do
    highlight_context = Map.get(params, "highlight_context")

    if guided_learning_login_required?(params, socket) do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      case GraphHelpers.handle_reply_and_answer(socket, answer,
             highlight_context: highlight_context,
             guided_learning: guided_learning_enabled?(params)
           ) do
        {:ok, {_graph, node}, operation} ->
          socket
          |> push_event("analytics", %{event: "question_added", params: %{ai_requested: "true"}})
          |> reset_ask_form()
          |> begin_query_generation(
            node,
            operation,
            "Answering #{quoted_selection(answer)}",
            params
          )

        {:error, :locked} ->
          {:noreply, socket |> put_flash(:error, "This graph is locked")}
      end
    end
  end

  # Start stream handlers grouped with other handle_event clauses
  def handle_event("open_help_modal", _params, socket) do
    {:noreply, assign(socket, show_help_modal: true)}
  end

  def handle_event("close_help_modal", _params, socket) do
    {:noreply, assign(socket, show_help_modal: false)}
  end

  def handle_event("open_share_modal", params, socket) do
    share_highlight =
      socket.assigns.graph_struct
      |> HighlightShare.highlight_for_graph(Map.get(params, "highlight_id"))

    {:noreply, assign(socket, show_share_modal: true, selected_share_highlight: share_highlight)}
  end

  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, show_share_modal: false, selected_share_highlight: nil)}
  end

  def handle_event("modal_closed", _params, socket) do
    {:noreply, assign(socket, open_read_modal: false)}
  end

  # Triggered by the client-side JS hook (text_selection_hook.js) when it receives a 401
  def handle_event("show_login_required", _, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  def handle_event("close_login_modal", _, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  def handle_event("open_start_stream_modal", _params, socket) do
    {:noreply, assign(socket, show_start_stream_modal: true)}
  end

  def handle_event("cancel_start_stream", _params, socket) do
    {:noreply, assign(socket, show_start_stream_modal: false)}
  end

  def handle_event("start_stream", %{"title" => title} = params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      # 1) Optionally create a compound group to visually contain the stream
      group_id =
        if is_binary(title) and String.trim(title) != "" do
          title
        else
          nil
        end

      if group_id do
        GraphManager.create_group(socket.assigns.graph_id, group_id, [])
        GraphManager.save_graph(socket.assigns.graph_id)
      end

      # 2) Create a new root node under the group (if provided)
      content = title

      vertex = %Vertex{
        content: content,
        class: "origin",
        user: socket.assigns.user,
        parent: group_id
      }

      new_node = GraphManager.add_node(socket.assigns.graph_id, vertex)

      # 3) Load updated graph and node-with-relatives and update assigns/UI
      node2 = GraphManager.find_node_by_id(socket.assigns.graph_id, new_node.id)
      GraphManager.save_graph(socket.assigns.graph_id)

      final_node =
        if Map.get(params, "auto_answer") in ["on", "true", "1"] do
          GraphActions.answer(graph_action_params(socket, node2))
        else
          node2
        end

      update_graph(socket, {nil, final_node}, "start_stream")
    end
  end

  def handle_event("focus_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "focus_group", %{id: group_id})}
  end

  def handle_event("toggle_stream", %{"id" => group_id}, socket) do
    {:noreply, push_event(socket, "toggle_group", %{id: group_id})}
  end

  def handle_event("delete_stream", %{"id" => group_id}, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      # Validate group_id is not blank or "Main"
      cond do
        String.trim(group_id) == "" ->
          {:noreply, socket |> put_flash(:error, "Invalid group")}

        group_id == "Main" ->
          {:noreply, socket |> put_flash(:error, "Cannot delete the Main group")}

        true ->
          # Verify the vertex exists and is a compound (group) node
          case GraphManager.vertex_label(socket.assigns.graph_id, group_id) do
            %{} = group_label ->
              cond do
                Map.get(group_label, :deleted, false) ->
                  {:noreply, socket |> put_flash(:error, "Group not found")}

                not Map.get(group_label, :compound, false) ->
                  {:noreply,
                   socket |> put_flash(:error, "Only groups can be deleted from streams")}

                true ->
                  # Verify the group is empty before deleting
                  all_vertices = GraphManager.vertices(socket.assigns.graph_id)

                  has_children =
                    Enum.any?(all_vertices, fn vid ->
                      vid != group_id and
                        case GraphManager.vertex_label(socket.assigns.graph_id, vid) do
                          %{} = lbl ->
                            Map.get(lbl, :parent) == group_id and
                              not Map.get(lbl, :deleted, false)

                          _ ->
                            false
                        end
                    end)

                  if has_children do
                    {:noreply,
                     socket |> put_flash(:error, "Cannot delete a group that has nodes")}
                  else
                    GraphManager.delete_node(socket.assigns.graph_id, group_id)
                    GraphManager.save_graph(socket.assigns.graph_id)

                    {:noreply,
                     socket
                     |> assign(
                       work_streams: list_streams(socket.assigns.graph_id),
                       f_graph: GraphManager.format_graph_json(socket.assigns.graph_id)
                     )
                     |> put_flash(:info, "Group deleted")}
                  end
              end

            _ ->
              {:noreply, socket |> put_flash(:error, "Group not found")}
          end
      end
    end
  end

  # ── Presentation mode events ──────────────────────────────────────

  def handle_event("enter_presentation_setup", _params, socket) do
    # Toggle: if already in setup, close the panel; otherwise open it
    if socket.assigns.presentation_mode == :setup do
      socket =
        socket
        |> assign(presentation_mode: :off)
        |> push_event("presentation_clear_slides", %{})

      {:noreply, socket}
    else
      # Auto-populate the title with the graph's starting question if not already set
      socket =
        if socket.assigns.presentation_title == "" do
          assign(socket, presentation_title: socket.assigns.graph_struct.title)
        else
          socket
        end

      socket =
        socket
        |> assign(presentation_mode: :setup)
        |> push_presentation_highlights()
        |> push_presentation_persistence()

      {:noreply, socket}
    end
  end

  def handle_event("exit_presentation", params, socket) do
    socket =
      socket
      |> assign(presentation_mode: :off)
      |> push_event("toggle_site_header", %{visible: true})
      |> maybe_clear_presentation(params)
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("close_presentation_setup", _params, socket) do
    # Just hide the panel and clear badge overlays — keep the slide deck intact
    socket =
      socket
      |> assign(presentation_mode: :off)
      |> push_event("presentation_clear_slides", %{})

    {:noreply, socket}
  end

  def handle_event("update_presentation_title", %{"title" => title}, socket) do
    title = String.slice(title, 0, 120)

    socket =
      socket
      |> assign(presentation_title: title)
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event(
        "restore_presentation",
        %{"slide_ids" => ids, "title" => title},
        socket
      )
      when is_list(ids) and is_binary(title) do
    # Only restore if we don't already have slides (i.e. fresh mount)
    if socket.assigns.presentation_slide_ids == [] do
      # Validate that the IDs actually exist in this graph
      valid_ids =
        Enum.filter(ids, fn id ->
          GraphActions.find_node(socket.assigns.graph_id, id) != nil
        end)

      socket =
        socket
        |> assign(
          presentation_slide_ids: valid_ids,
          presentation_title: String.slice(title, 0, 120)
        )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("restore_presentation", _params, socket), do: {:noreply, socket}

  def handle_event("presentation_remove_slide", %{"node-id" => node_id}, socket) do
    updated_ids = List.delete(socket.assigns.presentation_slide_ids, node_id)

    socket =
      socket
      |> assign(presentation_slide_ids: updated_ids)
      |> push_presentation_highlights()
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("presentation_reorder", %{"order" => order}, socket) when is_list(order) do
    current_ids = socket.assigns.presentation_slide_ids || []
    allowed_ids = MapSet.new(current_ids)

    sanitized_order =
      order
      |> Enum.uniq()
      |> Enum.filter(&MapSet.member?(allowed_ids, &1))

    socket =
      socket
      |> assign(presentation_slide_ids: sanitized_order)
      |> push_presentation_highlights()
      |> push_presentation_persistence()

    {:noreply, socket}
  end

  def handle_event("presentation_clear_slides", _params, socket) do
    socket =
      socket
      |> assign(presentation_slide_ids: [], presentation_title: "")
      |> push_event("presentation_clear_slides", %{})

    {:noreply, socket}
  end

  def handle_event("start_presenting", _params, socket) do
    ids = socket.assigns.presentation_slide_ids
    slides = slides(socket.assigns.graph_id, ids)

    if length(ids) > 0 do
      # Ensure the title defaults to the graph's starting question
      title =
        if socket.assigns.presentation_title == "",
          do: socket.assigns.graph_struct.title,
          else: socket.assigns.presentation_title

      # Filter the graph to show only the selected nodes (no full-screen overlay)
      socket =
        socket
        |> maybe_focus_presentation_slide(slides)
        |> assign(presentation_mode: :presenting, presentation_title: title)
        |> push_event("presentation_clear_slides", %{})
        |> push_event("toggle_site_header", %{visible: false})
        |> push_presentation_persistence()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("presentation_go_to_slide", %{"node-id" => node_id}, socket) do
    if node_id in socket.assigns.presentation_slide_ids do
      {:noreply, focus_presentation_slide(socket, node_id)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("presentation_step", %{"direction" => direction}, socket)
      when direction in ["next", "previous"] do
    slides = slides(socket.assigns.graph_id, socket.assigns.presentation_slide_ids)

    target_slide =
      slides
      |> active_slide(socket.assigns.node)
      |> then(fn
        nil ->
          nil

        active_slide ->
          adjacent_slide(slides, active_slide.id, direction)
      end)

    case target_slide do
      nil -> {:noreply, socket}
      slide -> {:noreply, focus_presentation_slide(socket, slide.id)}
    end
  end

  # ── Combine mode events ──────────────────────────────────────────

  def handle_event("close_combine_setup", _params, socket) do
    socket =
      socket
      |> assign(combine_mode: :off, combine_selected_nodes: [])
      |> push_event("combine_clear_highlights", %{})

    {:noreply, socket}
  end

  def handle_event("combine_deselect_node", %{"node-id" => node_id}, socket) do
    updated_selected =
      Enum.reject(socket.assigns.combine_selected_nodes, fn n -> n.id == node_id end)

    socket =
      socket
      |> assign(combine_selected_nodes: updated_selected)
      |> push_event("combine_highlight_nodes", %{ids: Enum.map(updated_selected, & &1.id)})

    {:noreply, socket}
  end

  def handle_event("combine_clear_selection", _params, socket) do
    socket =
      socket
      |> assign(combine_selected_nodes: [])
      |> push_event("combine_clear_highlights", %{})

    {:noreply, socket}
  end

  def handle_event("execute_combine", _params, socket) do
    if !socket.assigns.can_edit do
      {:noreply, socket |> put_flash(:error, "This graph is locked")}
    else
      case socket.assigns.combine_selected_nodes do
        [node1, node2] ->
          # Execute the combine action
          case GraphActions.combine(
                 graph_action_params(socket, node1),
                 node2.id
               ) do
            nil ->
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Unable to combine the selected nodes because one of them no longer exists"
               )}

            node ->
              socket =
                socket
                |> assign(combine_mode: :off, combine_selected_nodes: [])
                |> push_event("combine_clear_highlights", %{})

              update_graph(socket, {nil, node}, "combine")
          end

        _ ->
          {:noreply, socket |> put_flash(:error, "Please select exactly 2 nodes")}
      end
    end
  end

  # ── Private helpers ──────────────────────────────────────────────

  defp add_combine_node(selected_nodes, node) do
    cond do
      Enum.any?(selected_nodes, fn selected -> selected.id == node.id end) ->
        selected_nodes

      length(selected_nodes) < 2 ->
        selected_nodes ++ [node]

      true ->
        selected_nodes
    end
  end

  defp maybe_clear_presentation(socket, %{"clear_slides" => value})
       when value in [true, "true"] do
    socket
    |> assign(presentation_slide_ids: [], presentation_title: "")
    |> push_event("presentation_clear_slides", %{})
  end

  defp maybe_clear_presentation(socket, _params), do: socket

  # Handle selection action messages from SelectionActionsComp
  @impl true
  def handle_info({:selection_action, params}, socket) do
    case GraphHelpers.check_selection_action_allowed(socket) do
      {:error, :locked} ->
        {:noreply, socket |> put_flash(:error, "This graph is locked")}

      {:error, :unauthenticated} ->
        {:noreply, assign(socket, show_login_modal: true)}

      :ok ->
        {action, selected_text, node_id, offsets, existing_highlight, extra} =
          GraphHelpers.unpack_selection_action(params)

        handle_selection_action(
          action,
          selected_text,
          node_id,
          offsets,
          existing_highlight,
          extra,
          socket
        )
    end
  end

  def handle_info(:close_share_modal, socket) do
    {:noreply, assign(socket, show_share_modal: false, selected_share_highlight: nil)}
  end

  # Highlight PubSub (:created, :updated, :deleted) injected by GraphStreaming

  def handle_info({DialecticWeb.Presence, {:join, presence}}, socket) do
    {:noreply, GridChat.handle_presence_join(socket, presence)}
  end

  def handle_info({DialecticWeb.Presence, {:leave, presence}}, socket) do
    {:noreply, GridChat.handle_presence_leave(socket, presence)}
  end

  def handle_info({:grid_chat_message, message}, socket) do
    {:noreply, GridChat.insert_message(socket, message)}
  end

  def handle_info({:graph_tags_updated, title, tags}, socket) do
    if socket.assigns.graph_id == title do
      graph_struct = Map.put(socket.assigns.graph_struct, :tags, tags)
      {:noreply, assign(socket, graph_struct: graph_struct)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:other_user_change, sender_pid}, socket) do
    # Skip if it's our own change - we've already updated our view
    if self() != sender_pid do
      {_graph_struct, _graph} = GraphManager.get_graph(socket.assigns.graph_id)

      # Update f_graph so other users see structural changes (new nodes, etc.)
      {:noreply,
       assign(socket,
         f_graph: GraphManager.format_graph_json(socket.assigns.graph_id),
         work_streams: list_streams(socket.assigns.graph_id)
       )}
    else
      {:noreply, socket}
    end
  end

  # :stream_chunk and :stream_chunk_broadcast are injected by GraphStreaming

  def handle_info({:llm_request_complete, node_id}, socket) do
    Logger.debug(fn ->
      "[GraphLive] llm_request_complete node_id=#{inspect(node_id)} current=#{inspect(socket.assigns.node && Map.get(socket.assigns.node, :id))}"
    end)

    socket =
      socket
      |> push_event("analytics", %{event: "ai_response_completed", params: %{}})
      |> assign(streaming_nodes: MapSet.delete(socket.assigns.streaming_nodes, node_id))
      |> assign(work_streams: list_streams(socket.assigns.graph_id))

    socket =
      case background_generation_for_node(socket, node_id) do
        nil ->
          assign(socket, f_graph: GraphManager.format_graph_json(socket.assigns.graph_id))

        {_generation_id, _generation} ->
          mark_background_generation_complete(socket, node_id)
      end

    # Don't broadcast or call update_graph - the streaming already updated the node content
    # and we don't want to cause a flash/rerender for the user watching the stream
    # Other users will see the node when it was created, not when it completes
    {:noreply, socket}
  end

  def handle_info({:stream_error, error, :node_id, node_id}, socket) do
    Logger.debug(fn ->
      "[GraphLive] stream_error node_id=#{inspect(node_id)} current=#{inspect(socket.assigns.node && Map.get(socket.assigns.node, :id))} error=#{inspect(error)}"
    end)

    updated_vertex = GraphManager.find_node_by_id(socket.assigns.graph_id, node_id)

    socket =
      socket
      |> push_event("analytics", %{event: "ai_response_failed", params: %{}})
      |> mark_background_generation_failed(node_id)

    if updated_vertex && socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      label = NodeTitleHelper.extract_node_title(updated_vertex)

      socket =
        socket
        |> assign(node: updated_vertex)
        |> push_event("update_node_label", %{id: node_id, label: label})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp handle_selection_action(
         :explain,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    case GraphActions.find_node(socket.assigns.graph_id, node_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Node not found")}

      parent_node ->
        highlight =
          existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

        graph_result =
          GraphActions.ask_and_answer(
            graph_action_params(socket, parent_node),
            "Please explain: #{selected_text}",
            minimal_context: true,
            source_text: selected_text
          )

        {_graph, answer_node} = graph_result

        if highlight && answer_node do
          Highlights.add_link(highlight.id, answer_node.id, "explain")
        end

        begin_background_generation(
          socket,
          answer_node,
          "explain",
          "Explaining #{quoted_selection(selected_text)}"
        )
    end
  end

  defp handle_selection_action(
         :highlight_only,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    if existing_highlight do
      # Highlight already exists, just close modal
      {:noreply, socket}
    else
      # Create new highlight without any linked nodes
      _highlight = create_highlight(socket, node_id, offsets, selected_text)
      {:noreply, socket}
    end
  end

  defp handle_selection_action(
         :pros_cons,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)
    parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)
    nodes = create_branch_nodes(socket, parent_node, content_override: selected_text)

    if highlight do
      Enum.each(nodes, fn node ->
        link_type = if node.class == "thesis", do: "pro", else: "con"
        Highlights.add_link(highlight.id, node.id, link_type)
      end)
    end

    begin_background_generations(
      socket,
      nodes,
      "branch",
      "Testing both sides of #{quoted_selection(selected_text)}",
      target_node_id: parent_node.id
    )
  end

  defp handle_selection_action(
         :related_ideas,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         _params,
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

    if highlight do
      # Create related ideas node
      parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      ideas_node =
        GraphActions.related_ideas(graph_action_params(socket, parent_node),
          content_override: selected_text
        )

      # Link highlight to the ideas node
      if ideas_node do
        Highlights.add_link(highlight.id, ideas_node.id, "related_idea")
      end

      begin_background_generation(
        socket,
        ideas_node,
        "ideas",
        "Finding related ideas for #{quoted_selection(selected_text)}"
      )
    else
      # If highlight creation fails, still create the ideas node
      parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      ideas_node =
        GraphActions.related_ideas(graph_action_params(socket, parent_node),
          content_override: selected_text
        )

      begin_background_generation(
        socket,
        ideas_node,
        "ideas",
        "Finding related ideas for #{quoted_selection(selected_text)}"
      )
    end
  end

  defp handle_selection_action(
         :ask_question,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         %{question: question_text},
         socket
       ) do
    case GraphActions.find_node(socket.assigns.graph_id, node_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Node not found")}

      parent_node ->
        highlight =
          existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

        graph_result =
          GraphActions.ask_about_selection(
            graph_action_params(socket, parent_node),
            question_text,
            selected_text
          )

        {_graph, answer_node} = graph_result

        if highlight && answer_node do
          Highlights.add_link(highlight.id, answer_node.id, "question")
        end

        begin_background_generation(
          socket,
          answer_node,
          "selection_question",
          "Answering your question about #{quoted_selection(selected_text)}"
        )
    end
  end

  defp handle_selection_action(
         :comment,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         %{comment: comment_text},
         socket
       ) do
    highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)
    parent_node = GraphActions.find_node(socket.assigns.graph_id, node_id)

    full_comment = "#{comment_text}\n\nRegarding: \"#{selected_text}\""

    comment_node =
      GraphActions.comment(
        graph_action_params(socket, parent_node),
        full_comment,
        "",
        fields: %{source_text: selected_text}
      )

    if comment_node do
      if highlight do
        Highlights.add_link(highlight.id, comment_node.id, "comment")
      end
    end

    update_graph(socket, {nil, comment_node}, "user")
  end

  # Advanced Critical Thinking Tools for Text Selection

  # =========================================================================
  # Critical Thinking Tools - Text Selection Actions (Generic)
  # =========================================================================

  for {tool_name, _config} <- @critical_thinking_tools do
    defp handle_selection_action(
           unquote(tool_name),
           selected_text,
           node_id,
           offsets,
           existing_highlight,
           _extra,
           socket
         ) do
      apply_critical_thinking_tool_to_text(
        unquote(tool_name),
        selected_text,
        node_id,
        offsets,
        existing_highlight,
        socket
      )
    end
  end

  defp create_highlight(socket, node_id, offsets, selected_text) do
    highlight_attrs = %{
      mudg_id: socket.assigns.graph_id,
      node_id: node_id,
      text_source_type: "node",
      selection_start: offsets["start"],
      selection_end: offsets["end"],
      selected_text_snapshot: selected_text,
      created_by_user_id: socket.assigns.current_user.id
    }

    case Highlights.create_highlight(highlight_attrs) do
      {:ok, highlight} -> highlight
      {:error, _changeset} -> nil
    end
  end

  def format_graph(graph) do
    if is_nil(graph) do
      # Return empty JSON array if graph is nil
      "[]"
    else
      try do
        graph |> Vertex.to_cytoscape_format() |> Jason.encode!()
      rescue
        # Return empty JSON array on error
        _ -> "[]"
      end
    end
  end

  # Sanitizes a string to be used as a graph title.
  #
  # Removes any characters that would cause issues when used in URLs or as graph identifiers.
  def sanitize_graph_title(title) do
    title
    |> String.trim()
    # Only allow letters, numbers, spaces, ASCII and Unicode dashes and apostrophes
    |> String.replace(~r/[^a-zA-Z0-9\s"'’,“”\-–—]/u, "")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
  end

  # Search for nodes in the graph based on a search term

  defp valid_search_node(vertex_data) do
    # First ensure we have a vertex_data that's a map
    # Then check if it has all required fields
    # Make sure content is a string
    # Ensure ID is non-nil and valid
    # And the node isn't marked as deleted
    vertex_data != nil and is_map(vertex_data) and
      Map.has_key?(vertex_data, :content) and
      Map.has_key?(vertex_data, :id) and
      is_binary(Map.get(vertex_data, :content, "")) and
      Map.get(vertex_data, :id) != nil and
      not Map.get(vertex_data, :deleted, false)
  end

  defp put_explore_limit_flash(socket) do
    put_flash(socket, :error, "Choose up to #{@max_explore_items} points at a time.")
  end

  defp normalize_explore_selected(params) do
    cond do
      is_list(params) ->
        Enum.filter(params, &is_binary/1)

      is_map(params) and is_list(Map.get(params, "selected")) ->
        Enum.filter(Map.get(params, "selected"), &is_binary/1)

      is_map(params) and is_list(Map.get(params, "items")) ->
        Enum.filter(Map.get(params, "items"), &is_binary/1)

      is_map(params) and is_map(Map.get(params, "items")) ->
        params["items"]
        |> Enum.flat_map(fn {key, value} ->
          cond do
            is_list(value) ->
              if Enum.any?(value, &checked_checkbox_value?/1), do: [key], else: []

            checked_checkbox_value?(value) ->
              [key]

            value in ["false", "off", "0", ""] ->
              []

            is_binary(value) ->
              [value]

            true ->
              []
          end
        end)

      true ->
        []
    end
  end

  defp checked_checkbox_value?(value), do: value in ["on", "true", "1", true, 1]

  defp guided_learning_enabled?(params) do
    checked_checkbox_value?(Map.get(params, "guided_learning"))
  end

  defp guided_learning_login_required?(params, socket) do
    is_nil(socket.assigns.current_user) && guided_learning_enabled?(params)
  end

  defp guided_plan_options(%{class: "learning_plan"} = plan_node) do
    with {:ok, _guided_plan} <- GuidedLearningPlan.normalize(Map.get(plan_node, :guided_plan)),
         %{} = target_node <- List.first(Map.get(plan_node, :parents, [])) do
      actions =
        plan_node
        |> guided_next_actions()
        |> annotate_guided_actions(plan_node, target_node)

      paths =
        plan_node
        |> guided_paths()
        |> annotate_guided_paths(plan_node, target_node)

      {actions, paths}
    else
      _invalid_or_missing_target -> {[], []}
    end
  end

  defp guided_plan_options(_node), do: {[], []}

  defp guided_paths(%{class: "learning_plan", guided_plan: guided_plan})
       when is_map(guided_plan) do
    GuidedLearningPlan.paths(guided_plan)
  end

  defp guided_paths(_node), do: []

  defp annotate_guided_paths(paths, plan_node, _target_node) do
    existing_questions =
      plan_node
      |> Map.get(:children, [])
      |> Enum.filter(fn child ->
        !Map.get(child, :deleted, false) && Map.get(child, :class) == "question"
      end)
      |> Enum.map(&normalize_guided_question(Map.get(&1, :content, "")))
      |> MapSet.new()

    Enum.map(paths, fn path ->
      reserved? =
        guided_submission_reserved?(plan_node, guided_path_submission_key(path.id))

      Map.put(
        path,
        :disabled,
        reserved? || MapSet.member?(existing_questions, normalize_guided_question(path.question))
      )
    end)
  end

  defp normalize_guided_question(question) do
    question
    |> to_string()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.downcase()
  end

  defp selected_guided_paths(params, paths) do
    selected_ids =
      case Map.get(params, "paths") do
        selected when is_map(selected) ->
          selected
          |> Enum.flat_map(fn {path_id, value} ->
            values = if is_list(value), do: value, else: [value]

            if Enum.any?(values, &checked_checkbox_value?/1) do
              [path_id]
            else
              []
            end
          end)
          |> MapSet.new()

        _no_selection ->
          MapSet.new()
      end

    Enum.filter(paths, fn path ->
      !path.disabled && MapSet.member?(selected_ids, path.id)
    end)
  end

  defp guided_paths_generation_label([path]), do: "Exploring #{path.label}"

  defp guided_paths_generation_label(paths) do
    "Exploring #{length(paths)} selected paths"
  end

  defp guided_next_actions(%{class: "learning_plan", guided_plan: guided_plan})
       when is_map(guided_plan) do
    GuidedLearningPlan.actions(guided_plan)
  end

  defp guided_next_actions(_node), do: []

  defp guided_action_recommended?(plan_node, action) do
    Enum.any?(guided_next_actions(plan_node), &(&1.action == action))
  end

  defp guided_action_target(graph_id, plan_node) do
    case List.first(Map.get(plan_node, :parents, [])) do
      %{} = parent -> {:ok, parent}
      parent_id when is_binary(parent_id) -> find_node_safe(graph_id, parent_id)
      _missing_parent -> {:error, :node_not_found}
    end
  end

  defp annotate_guided_actions(actions, plan_node, target_node) do
    actions
    |> Enum.map(fn recommendation ->
      Map.put(
        recommendation,
        :disabled,
        guided_action_used?(plan_node, target_node, recommendation.action)
      )
    end)
    |> Enum.map_reduce(false, fn recommendation, recommendation_assigned? ->
      recommended? = !recommendation.disabled && !recommendation_assigned?

      {Map.put(recommendation, :recommended, recommended?),
       recommendation_assigned? || recommended?}
    end)
    |> elem(0)
  end

  defp guided_action_used?(plan_node, _target_node, action) do
    reserved? =
      guided_submission_reserved?(plan_node, guided_action_submission_key(action))

    classes = GuidedLearningPlan.result_classes(action)

    reserved? ||
      Enum.any?(Map.get(plan_node, :children, []), fn child ->
        !Map.get(child, :deleted, false) && Map.get(child, :class) in classes
      end)
  end

  defp guided_submission_reserved?(plan_node, submission_key) do
    submission_key in Map.get(plan_node, :guided_submissions, [])
  end

  defp guided_path_submission_key(path_id), do: "path:#{path_id}"
  defp guided_action_submission_key(action), do: "action:#{action}"

  defp guided_submission_metadata(plan_node, submission_key, cleanup_classes \\ []) do
    %{
      plan_node_id: plan_node.id,
      submission_key: submission_key,
      cleanup_classes: cleanup_classes
    }
  end

  defp apply_guided_action(action, plan_node, target_node, socket) do
    action_opts = [
      content_override: Map.get(target_node, :content, ""),
      await_generation: true,
      guided_submission:
        guided_submission_metadata(
          plan_node,
          guided_action_submission_key(action),
          GuidedLearningPlan.result_classes(action)
        )
    ]

    case GuidedLearningPlan.executor(action) do
      {:ok, :branch} ->
        nodes =
          create_branch_nodes(socket, plan_node, action_opts)

        if nodes == [] do
          release_guided_action(socket, plan_node, action)
          {:noreply, put_flash(socket, :error, "Failed to apply recommended action")}
        else
          begin_background_generations(
            socket,
            nodes,
            "branch",
            "Building the strongest case for and against this idea",
            target_node_id: plan_node.id
          )
        end

      {:ok, :related_ideas} ->
        result_node =
          GraphActions.related_ideas(
            graph_action_params(socket, plan_node),
            action_opts
          )

        if is_map(result_node) do
          begin_foreground_generation(socket, result_node, "ideas")
        else
          release_guided_action(socket, plan_node, action)
          {:noreply, put_flash(socket, :error, "Failed to apply recommended action")}
        end

      {:ok, {:thinking_tool, tool}} ->
        result_node =
          GraphActions.apply_thinking_tool(
            tool,
            graph_action_params(socket, plan_node),
            action_opts
          )

        case result_node do
          nil ->
            release_guided_action(socket, plan_node, action)
            {:noreply, put_flash(socket, :error, "Failed to apply recommended action")}

          node ->
            begin_foreground_generation(socket, node, action)
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Unknown recommended action")}
    end
  end

  # =========================================================================
  # Critical Thinking Tools - Helper Functions
  # =========================================================================

  # Applies a critical thinking tool to a node with proper error handling.
  #
  # ## Parameters
  # - tool: Atom representing the tool (e.g., :clarify, :assumptions)
  # - node_id: String ID of the target node
  # - socket: LiveView socket
  #
  # ## Returns
  # - `{:noreply, socket}` with updated graph or error flash
  #
  # ## Error Handling
  # - Returns error flash if graph is locked (can_edit is false)
  # - Returns error flash if node is not found
  # - Handles nil results from GraphActions gracefully
  defp apply_critical_thinking_tool(tool, node_id, socket) do
    with :ok <- validate_can_edit(socket),
         {:ok, node} <- find_node_safe(socket.assigns.graph_id, node_id),
         {:ok, tool_config} <- get_tool_config(tool),
         {:ok, result_node} <- apply_graph_action(tool_config, socket, node) do
      begin_foreground_generation(
        socket,
        result_node,
        Atom.to_string(tool)
      )
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      {:error, :node_not_found} ->
        {:noreply, put_flash(socket, :error, "Node not found")}

      {:error, :tool_not_found} ->
        {:noreply, put_flash(socket, :error, "Unknown tool")}

      {:error, :action_failed} ->
        {:noreply, put_flash(socket, :error, "Failed to apply tool")}
    end
  end

  # Applies a critical thinking tool to selected text with proper error handling.
  #
  # ## Parameters
  # - tool: Atom representing the tool (e.g., :clarify, :assumptions)
  # - selected_text: String of text to analyze
  # - node_id: String ID of the parent node
  # - offsets: Map with text selection offsets
  # - existing_highlight: Existing highlight struct or nil
  # - socket: LiveView socket
  #
  # ## Returns
  # - Updated socket with new node and highlight links
  #
  # ## Validation
  # - Validates selected_text is non-empty
  # - Checks if tool supports text selection
  # - Creates highlight and links to new node
  defp apply_critical_thinking_tool_to_text(
         tool,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         socket
       ) do
    with :ok <- validate_can_edit(socket),
         :ok <- validate_selected_text(selected_text),
         {:ok, node} <- find_node_safe(socket.assigns.graph_id, node_id),
         {:ok, tool_config} <- get_tool_config(tool),
         :ok <- validate_tool_supports_text(tool_config),
         {:ok, result_node} <-
           apply_text_graph_action(tool_config, socket, node, selected_text) do
      highlight = existing_highlight || create_highlight(socket, node_id, offsets, selected_text)

      if result_node && highlight do
        Highlights.add_link(highlight.id, result_node.id, Atom.to_string(tool))
      end

      begin_background_generation(
        socket,
        result_node,
        Atom.to_string(tool),
        "Applying #{tool |> Atom.to_string() |> String.replace("_", " ")} to #{quoted_selection(selected_text)}"
      )
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      {:error, :empty_text} ->
        {:noreply, put_flash(socket, :error, "Please select some text")}

      {:error, :node_not_found} ->
        {:noreply, put_flash(socket, :error, "Node not found")}

      {:error, :tool_not_found} ->
        {:noreply, put_flash(socket, :error, "Unknown tool")}

      {:error, :text_not_supported} ->
        {:noreply, put_flash(socket, :error, "This tool does not support text selection")}

      {:error, :action_failed} ->
        {:noreply, put_flash(socket, :error, "Failed to apply tool to text")}
    end
  end

  # Validation helpers

  defp validate_can_edit(%{assigns: %{can_edit: true}}), do: :ok
  defp validate_can_edit(_socket), do: {:error, :locked}

  defp validate_logged_in(%{assigns: %{current_user: %User{}}}), do: :ok
  defp validate_logged_in(_socket), do: {:error, :login_required}

  defp validate_regeneration_access(%{class: "learning_plan"}, socket),
    do: validate_logged_in(socket)

  defp validate_regeneration_access(_node, _socket), do: :ok

  defp reserve_regeneration(%{class: "learning_plan"} = node, socket) do
    GraphManager.reserve_guided_submission(socket.assigns.graph_id, node.id, "regeneration")
  end

  defp reserve_regeneration(_node, _socket), do: :ok

  defp release_regeneration(%{class: "learning_plan"} = node, socket) do
    GraphManager.release_guided_submission(socket.assigns.graph_id, node.id, "regeneration")
  end

  defp release_regeneration(_node, _socket), do: :ok

  defp release_guided_action(socket, plan_node, action) do
    release_guided_submission(socket, plan_node, guided_action_submission_key(action))
  end

  defp release_guided_submission(socket, plan_node, submission_key) do
    GraphManager.release_guided_submission(
      socket.assigns.graph_id,
      plan_node.id,
      submission_key
    )
  end

  defp validate_selected_text(text) when is_binary(text) and byte_size(text) > 0, do: :ok
  defp validate_selected_text(_), do: {:error, :empty_text}

  defp validate_tool_supports_text(%{supports_text: true}), do: :ok
  defp validate_tool_supports_text(_), do: {:error, :text_not_supported}

  defp find_node_safe(graph_id, node_id) do
    case GraphActions.find_node(graph_id, node_id) do
      nil -> {:error, :node_not_found}
      node -> {:ok, node}
    end
  end

  defp get_tool_config(tool) do
    case Map.fetch(@critical_thinking_tools, tool) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, :tool_not_found}
    end
  end

  defp apply_graph_action(%{function: func}, socket, node) do
    result = apply(GraphActions, func, [graph_action_params(socket, node)])

    case result do
      nil -> {:error, :action_failed}
      node -> {:ok, node}
    end
  end

  defp apply_text_graph_action(%{text_function: text_func}, socket, node, selected_text) do
    result = apply(GraphActions, text_func, [graph_action_params(socket, node), selected_text])

    case result do
      nil -> {:error, :action_failed}
      node -> {:ok, node}
    end
  end

  defp graph_action_params(socket, node \\ nil) do
    GraphHelpers.graph_action_params(socket, node)
  end

  defp create_branch_nodes(socket, parent_node, opts \\ [])
  defp create_branch_nodes(_socket, nil, _opts), do: []

  defp create_branch_nodes(socket, parent_node, opts) do
    GraphActions.branch(graph_action_params(socket, parent_node), opts)
    |> Enum.filter(&is_map/1)
    |> Enum.sort_by(fn node -> if node.class == "thesis", do: 0, else: 1 end)
  end

  defp reset_ask_form(socket) do
    new_node = GraphActions.create_new_node(socket.assigns.user)
    assign(socket, form: to_form(Vertex.changeset(new_node), id: new_node.id))
  end

  defp explore_generation_label([item]), do: "Explaining #{quoted_selection(item)}"

  defp explore_generation_label(items) do
    "Exploring #{length(items)} selected points"
  end

  defp explore_target_node_id([node], _parent_node_id), do: node.id
  defp explore_target_node_id(_nodes, parent_node_id), do: parent_node_id

  defp begin_query_generation(
         socket,
         node,
         operation,
         _label,
         %{"query_origin" => "node_action_bar"}
       ) do
    socket
    |> push_event("analytics", %{
      event: "ai_response_requested",
      params: %{origin: "node_action_bar"}
    })
    |> begin_foreground_generation(node, operation)
  end

  defp begin_query_generation(socket, node, operation, label, _params) do
    socket
    |> push_event("analytics", %{event: "ai_response_requested", params: %{origin: "question"}})
    |> begin_background_generation(node, operation, label)
  end

  defp begin_foreground_generation(socket, node, operation) do
    nodes = Enum.filter([node], &is_map/1)

    case nodes do
      [] ->
        {:noreply, put_flash(socket, :error, "The response could not be started")}

      [target_node] ->
        socket
        |> assign(
          streaming_nodes: MapSet.put(socket.assigns.streaming_nodes, target_node.id),
          work_streams: list_streams(socket.assigns.graph_id)
        )
        |> update_graph({nil, target_node}, operation)
    end
  end

  defp begin_background_generation(socket, node, operation, label) do
    begin_background_generations(socket, [node], operation, label)
  end

  defp begin_background_generations(socket, nodes, operation, label, opts \\ []) do
    nodes = Enum.filter(nodes, &is_map/1)

    if nodes == [] do
      {:noreply, put_flash(socket, :error, "The response could not be started")}
    else
      register_background_generation(socket, nodes, operation, label, opts)
    end
  end

  defp register_background_generation(socket, nodes, operation, label, opts) do
    sequence = socket.assigns.background_generation_sequence + 1
    node_ids = Enum.map(nodes, & &1.id)
    target_node_id = Keyword.get(opts, :target_node_id, List.last(node_ids))

    generation_id =
      Keyword.get(
        opts,
        :generation_id,
        if(length(node_ids) == 1, do: hd(node_ids), else: "batch-#{Enum.join(node_ids, "-")}")
      )

    generation = %{
      id: generation_id,
      node_ids: node_ids,
      target_node_id: target_node_id,
      pending_node_ids: MapSet.new(node_ids),
      failed_node_ids: MapSet.new(),
      label: label,
      title: nil,
      status: :generating,
      sequence: sequence
    }

    maybe_record_activity(socket, operation, List.last(nodes))

    if operation in @structural_graph_operations do
      PubSub.broadcast(
        Dialectic.PubSub,
        socket.assigns.graph_topic,
        {:other_user_change, self()}
      )
    end

    {:noreply,
     assign(socket,
       background_generation_sequence: sequence,
       background_generations:
         Map.put(socket.assigns.background_generations, generation_id, generation),
       streaming_nodes:
         Enum.reduce(node_ids, socket.assigns.streaming_nodes, &MapSet.put(&2, &1)),
       work_streams: list_streams(socket.assigns.graph_id)
     )}
  end

  defp mark_background_generation_complete(socket, node_id) do
    update_background_generation_for_node(socket, node_id, fn generation ->
      pending_node_ids = MapSet.delete(generation.pending_node_ids, node_id)

      if MapSet.size(pending_node_ids) == 0 do
        failed? = MapSet.size(generation.failed_node_ids) > 0

        title =
          if length(generation.node_ids) == 1 and not failed? do
            node = GraphActions.find_node(socket.assigns.graph_id, node_id)
            if node, do: NodeTitleHelper.extract_node_title(node), else: ""
          else
            ""
          end

        generation
        |> Map.put(:pending_node_ids, pending_node_ids)
        |> Map.put(:status, if(failed?, do: :failed, else: :ready))
        |> Map.put(:title, title)
      else
        Map.put(generation, :pending_node_ids, pending_node_ids)
      end
    end)
  end

  defp mark_background_generation_failed(socket, node_id) do
    update_background_generation_for_node(socket, node_id, fn generation ->
      Map.update!(generation, :failed_node_ids, &MapSet.put(&1, node_id))
    end)
  end

  defp update_background_generation_for_node(socket, node_id, update_fun) do
    case background_generation_for_node(socket, node_id) do
      {generation_id, generation} ->
        assign(
          socket,
          :background_generations,
          Map.put(socket.assigns.background_generations, generation_id, update_fun.(generation))
        )

      nil ->
        socket
    end
  end

  defp clear_background_generation(socket, node_id) do
    generation_id =
      case background_generation_for_node(socket, node_id) do
        {id, _generation} -> id
        nil -> node_id
      end

    assign(
      socket,
      :background_generations,
      Map.delete(socket.assigns.background_generations, generation_id)
    )
  end

  defp clear_completed_background_generations(socket) do
    assign(
      socket,
      :background_generations,
      Map.reject(socket.assigns.background_generations, fn {_id, generation} ->
        generation.status in [:ready, :failed]
      end)
    )
  end

  defp background_generation_for_node(socket, node_id) do
    Enum.find(socket.assigns.background_generations, fn {_generation_id, generation} ->
      node_id in generation.node_ids
    end)
  end

  defp quoted_selection(text) do
    text = String.trim(text)
    shortened = if String.length(text) > 54, do: String.slice(text, 0, 51) <> "…", else: text
    "“#{shortened}”"
  end

  defp compute_nav_flags(_graph, nil), do: {false, false, false, false}

  defp compute_nav_flags(graph, node) do
    can_up = is_list(node.parents) and List.first(node.parents) != nil
    can_down = is_list(node.children) and List.first(node.children) != nil

    siblings =
      try do
        case graph do
          id when is_binary(id) -> Siblings.sort_siblings(node, id)
          _ -> Siblings.sort_siblings(node, graph)
        end
      rescue
        _ -> []
      end

    {can_left, can_right} =
      case Enum.find_index(siblings, fn n -> n.id == node.id end) do
        nil -> {false, false}
        0 -> {false, length(siblings) > 1}
        idx when idx == length(siblings) - 1 -> {length(siblings) > 1, false}
        _ -> {true, true}
      end

    {can_up, can_down, can_left, can_right}
  end

  defp list_streams(graph_id) do
    try do
      GraphManager.vertices(graph_id)
      |> Enum.reduce([], fn vid, acc ->
        case GraphManager.vertex_label(graph_id, vid) do
          %{} = v ->
            if Map.get(v, :compound) == true and not Map.get(v, :deleted, false) do
              [%{id: v.id} | acc]
            else
              acc
            end

          _ ->
            acc
        end
      end)
      |> Enum.reverse()
    rescue
      _ -> []
    end
  end

  defp ensure_main_group(graph_id) do
    GraphManager.ensure_main_group(graph_id)
  end

  def update_graph(socket, {_graph, node}, operation) do
    # Changeset needs to be a new node
    new_node = GraphActions.create_new_node(socket.assigns.user)
    changeset = Vertex.changeset(new_node)

    # Clear search when a node is clicked from search results
    socket =
      if operation == "node_clicked" and socket.assigns.search_term != "" do
        assign(socket, search_term: "", search_results: [])
      else
        socket
      end

    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(socket.assigns.graph_id, node)
    maybe_record_activity(socket, operation, node)

    # Skip f_graph regeneration for content-only updates to prevent stuttering
    # Structural operations (new nodes/edges) must regenerate so Cytoscape stays in sync
    content_only_operations = ["llm_request_complete"]

    new_socket =
      assign(socket,
        f_graph:
          if operation in content_only_operations do
            socket.assigns.f_graph
          else
            GraphManager.format_graph_json(socket.assigns.graph_id)
          end,
        form:
          if operation in ["llm_request_complete"] do
            socket.assigns.form
          else
            to_form(changeset, id: new_node.id)
          end,
        node: node,
        graph_operation: operation,
        open_read_modal: false,
        nav_can_up: nav_up,
        nav_can_down: nav_down,
        nav_can_left: nav_left,
        nav_can_right: nav_right,
        work_streams: list_streams(socket.assigns.graph_id),
        prompt_mode:
          Atom.to_string(Dialectic.Responses.ModeServer.get_mode(socket.assigns.graph_id))
      )
      |> assign(:ask_question, socket.assigns.ask_question)
      |> then(fn s ->
        # Close the start stream modal if applicable
        if operation == "start_stream" do
          s
          |> assign(show_start_stream_modal: false)
          |> push_event("reflow_layout", %{})
        else
          s
        end
      end)
      |> then(fn s ->
        # Ensure newly created nodes are selected immediately
        if operation in @node_creation_operations && node && Map.get(node, :id) do
          push_event(s, "center_node", %{id: node.id})
        else
          s
        end
      end)
      |> then(fn s ->
        # Reset the side-drawer scroll position when navigating to a
        # different node.  Skip streaming updates — those append content
        # to the current node and shouldn't jump the user back to top.
        if operation not in ["llm_request_complete"] do
          push_event(s, "scroll_to_top", %{})
        else
          s
        end
      end)

    # Broadcast structural changes to other users (new nodes created, etc.)
    # Skip for operations that don't change graph structure
    if operation in @structural_graph_operations do
      PubSub.broadcast(
        Dialectic.PubSub,
        socket.assigns.graph_topic,
        {:other_user_change, self()}
      )
    end

    {:noreply, new_socket}
  end

  defp maybe_record_activity(socket, operation, node) do
    case GridActivity.Actions.for_graph_operation(operation) do
      nil ->
        :ok

      action ->
        _ =
          GridActivity.record_node_event_async(
            socket.assigns.graph_id,
            activity_actor(socket),
            action,
            node
          )

        :ok
    end
  end

  defp activity_actor(socket), do: socket.assigns[:current_user] || socket.assigns[:user]

  # Helper to preserve and re-apply right panel state across node changes/moves
  defp reapply_right_panel_state(socket, updated_socket) do
    updated_socket =
      updated_socket
      |> assign(:group_states, socket.assigns[:group_states] || %{})

    send_update(
      DialecticWeb.RightPanelComp,
      id: "right-panel-comp",
      group_states: updated_socket.assigns[:group_states]
    )

    updated_socket
  end

  defp update_streaming_node(socket, updated_vertex, node_id) do
    new_content = Map.get(updated_vertex, :content, "")
    new_grounding_metadata = Map.get(updated_vertex, :grounding_metadata)
    new_guided_plan = Map.get(updated_vertex, :guided_plan)

    # Check if we've already set the title for this node on this socket
    already_titled = MapSet.member?(socket.assigns.titled_nodes, node_id)
    new_title = NodeTitleHelper.extract_node_title(updated_vertex)
    needs_title_set = !already_titled && new_title != ""

    # Push label update to Cytoscape for all users, regardless of which node they're viewing
    socket =
      if needs_title_set do
        socket
        |> assign(titled_nodes: MapSet.put(socket.assigns.titled_nodes, node_id))
        |> push_event("update_node_label", %{id: node_id, label: new_title})
      else
        socket
      end

    # If this user is currently viewing the streaming node, update their assigns
    if socket.assigns.node && node_id == Map.get(socket.assigns.node, :id) do
      current_content = Map.get(socket.assigns.node, :content, "")
      current_grounding_metadata = Map.get(socket.assigns.node, :grounding_metadata)
      current_guided_plan = Map.get(socket.assigns.node, :guided_plan)

      if current_content == new_content and
           current_grounding_metadata == new_grounding_metadata and
           current_guided_plan == new_guided_plan do
        socket
      else
        node =
          socket.assigns.node
          |> Map.put(:content, new_content)
          |> Map.put(:grounding_metadata, new_grounding_metadata)
          |> Map.put(:guided_plan, new_guided_plan)

        assign(socket, node: node)
      end
    else
      socket
    end
  end

  defp fetch_graph(user, graph_id, params) do
    # Try slug first, then title for backward compatibility
    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_id) do
      nil ->
        {:error, "Graph not found: #{graph_id}"}

      graph_db ->
        token_param = Map.get(params, "token")

        has_access =
          Dialectic.DbActions.Sharing.can_access?(user, graph_db) or
            (is_binary(token_param) and is_binary(graph_db.share_token) and
               Plug.Crypto.secure_compare(token_param, graph_db.share_token))

        if has_access do
          try do
            # Always use title for GraphManager lookup (internal identifier)
            {:ok, GraphManager.get_graph(graph_db.title), graph_db}
          rescue
            _e ->
              require Logger
              Logger.error("Failed to load graph: #{graph_db.title}")
              {:error, "Error loading graph: #{graph_db.title}"}
          end
        else
          {:error, "You do not have permission to view this graph."}
        end
    end
  end

  defp resolve_target_node(graph_id, params) do
    highlight_param = Map.get(params, "highlight")

    if highlight_param do
      case Highlights.get_highlight(highlight_param) do
        %{mudg_id: ^graph_id, node_id: h_node_id, id: h_id} ->
          {h_node_id, h_id}

        _ ->
          {Map.get(params, "node", "1"), nil}
      end
    else
      {Map.get(params, "node", "1"), nil}
    end
  end

  defp assign_reader_path(socket, path_endpoint) do
    path_endpoint = normalize_reader_path(path_endpoint)
    path_ids = reader_path_ids(socket.assigns.graph_id, path_endpoint)

    assign(socket,
      reader_path_endpoint: if(path_ids == [], do: nil, else: path_endpoint),
      reader_path_ids: path_ids
    )
  end

  defp normalize_reader_path(path_endpoint) when is_binary(path_endpoint) do
    case String.trim(path_endpoint) do
      "" -> nil
      endpoint -> endpoint
    end
  end

  defp normalize_reader_path(_path_endpoint), do: nil

  defp reader_path_ids(_graph_id, nil), do: []

  defp reader_path_ids(graph_id, path_endpoint) do
    case GraphManager.find_node_by_id(graph_id, path_endpoint) do
      nil ->
        []

      node ->
        graph_id
        |> GraphManager.path_to_node(node)
        |> Enum.reverse()
        |> Enum.reject(fn path_node ->
          Map.get(path_node, :deleted, false) || Map.get(path_node, :compound, false)
        end)
        |> Enum.map(& &1.id)
    end
  end

  defp graph_nav_params(token, path_endpoint) do
    []
    |> then(fn params -> if token, do: Keyword.put(params, :token, token), else: params end)
    |> then(fn params ->
      if path_endpoint,
        do: Keyword.put(params, :path, path_endpoint),
        else: params
    end)
  end

  defp assign_defaults(socket) do
    user = UserUtils.current_identity(socket.assigns)

    assign(socket,
      user: user,
      current_user: socket.assigns[:current_user],
      streaming_nodes: MapSet.new(),
      titled_nodes: MapSet.new(),
      background_generations: %{},
      background_generation_sequence: 0,
      graph_operation: "",
      ask_question: true,
      group_states: %{},
      search_term: "",
      search_results: [],
      show_search_overlay: false,
      nav_can_up: false,
      nav_can_down: false,
      nav_can_left: false,
      nav_can_right: false,
      open_read_modal: false,
      show_explore_modal: false,
      explore_items: [],
      explore_selected: [],
      explore_form: to_form(%{}, as: :explore),
      max_explore_items: @max_explore_items,
      guided_path_form: to_form(%{}, as: :guided_paths),
      show_start_stream_modal: false,
      show_help_modal: false,
      show_share_modal: false,
      selected_share_highlight: nil,
      work_streams: [],
      show_login_modal: false,
      highlights: [],
      presentation_mode: :off,
      presentation_slide_ids: [],
      presentation_title: "",
      combine_mode: :off,
      combine_selected_nodes: [],
      graph_owner_name: nil
    )
    |> assign(GridChat.default_assigns())
  end

  defp subscribe_to_topics(socket, graph_id) do
    if connected?(socket) do
      live_view_topic = "graph_update:#{socket.id}"
      graph_topic = "graph_update:#{graph_id}"

      Phoenix.PubSub.subscribe(Dialectic.PubSub, live_view_topic)
      Phoenix.PubSub.subscribe(Dialectic.PubSub, graph_topic)
      Highlights.subscribe(graph_id)

      socket = GridChat.subscribe(socket, graph_id)

      # Load highlights asynchronously after connection - doesn't block initial render
      highlights = Highlights.list_highlights_with_links(mudg_id: graph_id)

      socket
      |> GridChat.init_streams(graph_id)
      |> assign(highlights: highlights)
      |> push_event("highlights_loaded", %{
        highlights: serialize_highlights(highlights)
      })
    else
      # Load highlights even when not connected (e.g., during tests or initial render)
      highlights = Highlights.list_highlights_with_links(mudg_id: graph_id)

      socket
      |> GridChat.init_streams(graph_id)
      |> assign(highlights: highlights)
    end
  end

  defp serialize_highlights(highlights) do
    Enum.map(highlights, fn h ->
      %{
        id: h.id,
        node_id: h.node_id,
        selection_start: h.selection_start,
        selection_end: h.selection_end,
        selected_text_snapshot: h.selected_text_snapshot,
        links:
          Enum.map(h.links || [], fn l ->
            %{node_id: l.node_id, link_type: l.link_type}
          end)
      }
    end)
  end

  defp assign_graph_data(socket, graph_db, graph_struct, node, graph_id, user) do
    changeset = GraphActions.create_new_node(user) |> Vertex.changeset()
    can_edit = !graph_struct.is_locked
    {nav_up, nav_down, nav_left, nav_right} = compute_nav_flags(graph_id, node)

    base_url = DialecticWeb.Endpoint.url()
    canonical = base_url <> "/g/#{graph_struct.slug}"

    description =
      "Explore the interactive grid for \"#{graph_struct.title}\". Visualize arguments, discover connections, and collaborate on RationalGrid."

    # JSON-LD structured data for search engine rich results
    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "name" => graph_struct.title,
        "headline" => graph_struct.title,
        "description" => description,
        "url" => canonical,
        "image" => base_url <> ~p"/images/graph_live.webp",
        "dateModified" => DateTime.to_iso8601(graph_struct.updated_at),
        "datePublished" => DateTime.to_iso8601(graph_struct.inserted_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "RationalGrid",
          "url" => base_url
        },
        "keywords" => graph_struct.tags || [],
        "isAccessibleForFree" => true
      })

    # Resolve the graph owner's display name for presentation credits
    owner_name =
      case graph_db.user_id do
        nil ->
          nil

        uid ->
          case Repo.get(User, uid) do
            nil -> nil
            user -> User.display_name(user)
          end
      end

    assign(socket,
      page_title: graph_struct.title,
      graph_owner_name: owner_name,
      og_image: base_url <> ~p"/images/graph_live.webp",
      page_description: description,
      canonical_url: canonical,
      og_type: "article",
      json_ld: json_ld,
      noindex: true,
      live_view_topic: "graph_update:#{socket.id}",
      graph_topic: "graph_update:#{graph_id}",
      graph_struct: graph_struct,
      graph_id: graph_id,
      appearance_preferences: User.appearance_preferences(socket.assigns[:current_user]),
      following_graph?: following_graph?(socket.assigns[:current_user], graph_struct),
      f_graph: GraphManager.format_graph_json(graph_id),
      node: node,
      form: to_form(changeset),
      can_edit: can_edit,
      node_menu_visible: true,
      nav_can_up: nav_up,
      nav_can_down: nav_down,
      nav_can_left: nav_left,
      nav_can_right: nav_right,
      work_streams: list_streams(graph_id),
      prompt_mode: Atom.to_string(Dialectic.Responses.ModeServer.get_mode(graph_id))
    )
  end

  defp following_graph?(%User{} = user, graph) do
    Follows.following_graph?(user, graph)
  end

  defp following_graph?(_user, _graph), do: false

  defp handle_initial_highlight(socket, highlight_id) do
    if connected?(socket) && highlight_id do
      push_event(socket, "scroll_to_highlight", %{id: highlight_id})
    else
      socket
    end
  end

  # ── Presentation helpers ────────────────────────────────────────────

  defp push_presentation_highlights(socket) do
    ids = socket.assigns.presentation_slide_ids
    push_event(socket, "presentation_highlight_slides", %{ids: ids})
  end

  defp push_presentation_persistence(socket) do
    graph_id = socket.assigns.graph_id

    push_event(socket, "presentation_persist", %{
      graph_id: graph_id,
      slide_ids: socket.assigns.presentation_slide_ids,
      title: socket.assigns.presentation_title
    })
  end

  defp focus_presentation_slide(socket, nil), do: socket

  defp focus_presentation_slide(socket, node_id) do
    case GraphActions.find_node(socket.assigns.graph_id, node_id) do
      nil ->
        socket

      node ->
        {:noreply, updated_socket} =
          update_graph(socket, {nil, node}, "presentation_go_to_slide")

        updated_socket =
          reapply_right_panel_state(socket, updated_socket)

        push_event(updated_socket, "center_node", %{id: node.id})
    end
  end

  defp maybe_focus_presentation_slide(socket, []), do: socket

  defp maybe_focus_presentation_slide(socket, slides) do
    focus_presentation_slide(socket, List.first(slides).id)
  end
end
