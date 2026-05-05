defmodule DialecticWeb.GraphHelpers do
  @moduledoc """
  Shared helper functions extracted from graph-facing LiveViews.

  These helpers return data that the calling LiveView can use with its own
  `update_graph` / `handle_graph_update` function. For graph mutations they
  return `{:ok, graph_result, operation}` or `{:error, reason}`, letting each
  LiveView call its own update function.

  For simple assign-only operations (like showing the login modal), they can
  return `{:noreply, socket}` directly.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Dialectic.Graph.{Vertex, GraphActions}

  require Logger

  # ── Default node ──────────────────────────────────────────────────────

  @doc """
  Returns a default empty node map used as a fallback.
  """
  def default_node do
    %{id: "1", content: "", children: [], parents: []}
  end

  # ── Graph action params ───────────────────────────────────────────────

  @doc """
  Builds the `{graph_id, node, user, live_view_topic}` tuple required by
  most `GraphActions` functions.

  Falls back to `socket.assigns.node` if no explicit node is given, and
  ultimately to `default_node/0`.
  """
  def graph_action_params(socket, node \\ nil) do
    node_to_use =
      cond do
        node != nil -> node
        is_map(socket.assigns.node) -> socket.assigns.node
        true -> default_node()
      end

    graph_id = socket.assigns.graph_id

    unless GraphManager.exists?(graph_id) do
      case Dialectic.DbActions.Graphs.get_graph_by_title(graph_id) do
        nil ->
          Logger.warning("Attempted to access non-existent graph: #{graph_id}")

        _graph ->
          case DynamicSupervisor.start_child(GraphSupervisor, {GraphManager, graph_id}) do
            {:ok, _pid} ->
              :ok

            {:error, {:already_started, _pid}} ->
              :ok

            {:error, reason} ->
              Logger.error("Failed to start GraphManager for #{graph_id}: #{inspect(reason)}")
          end
      end
    end

    {graph_id, node_to_use, socket.assigns.user, socket.assigns.live_view_topic}
  end

  # ── Note / Unnote ─────────────────────────────────────────────────────

  @doc """
  Handles the note action for a node.

  Returns either:
  - `{:noreply, socket}` when the user is not logged in (shows login modal)
  - `{:ok, {nil, graph_result}, "note"}` on success, for the caller to pass
    to its own update_graph / handle_graph_update
  """
  def handle_note(socket, node_id, :note) do
    if socket.assigns.current_user == nil do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      Dialectic.DbActions.Notes.add_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      graph_result =
        GraphActions.change_noted_by(
          graph_action_params(socket),
          node_id,
          &Vertex.add_noted_by/2
        )

      {:ok, {nil, graph_result}, "note"}
    end
  end

  def handle_note(socket, node_id, :unnote) do
    if socket.assigns.current_user == nil do
      {:noreply, assign(socket, show_login_modal: true)}
    else
      Dialectic.DbActions.Notes.remove_note(
        socket.assigns.graph_id,
        node_id,
        socket.assigns.current_user
      )

      graph_result =
        GraphActions.change_noted_by(
          graph_action_params(socket),
          node_id,
          &Vertex.remove_noted_by/2
        )

      {:ok, {nil, graph_result}, "unnote"}
    end
  end

  # ── Branch / Related Ideas ────────────────────────────────────────────

  @doc """
  Handles the branch action for a node.

  Returns either:
  - `{:error, :locked}` when the graph is locked
  - `{:ok, {nil, graph_result}, "branch"}` on success
  """
  def handle_branch(socket, node_id) do
    if not socket.assigns.can_edit do
      {:error, :locked}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      graph_result = GraphActions.branch(graph_action_params(socket, node))
      {:ok, {nil, graph_result}, "branch"}
    end
  end

  @doc """
  Handles the related_ideas action for a node.

  Returns either:
  - `{:error, :locked}` when the graph is locked
  - `{:ok, {nil, graph_result}, "ideas"}` on success
  """
  def handle_related_ideas(socket, node_id) do
    if not socket.assigns.can_edit do
      {:error, :locked}
    else
      node = GraphActions.find_node(socket.assigns.graph_id, node_id)

      graph_result = GraphActions.related_ideas(graph_action_params(socket, node))
      {:ok, {nil, graph_result}, "ideas"}
    end
  end

  # ── Answer / Reply-and-Answer ─────────────────────────────────────────

  @doc """
  Handles the simple "answer" (comment) action.

  Returns either:
  - `{:error, :locked}` when the graph is locked
  - `{:ok, {nil, graph_result}, "comment"}` on success
  """
  def handle_answer(socket, answer_content) do
    if not socket.assigns.can_edit do
      {:error, :locked}
    else
      graph_result = GraphActions.comment(graph_action_params(socket), answer_content)
      {:ok, {nil, graph_result}, "comment"}
    end
  end

  # ── Selection action helpers ──────────────────────────────────────────

  @doc """
  Checks if a selection action can proceed based on socket assigns.

  Returns:
  - `:ok` — action is allowed
  - `{:error, :locked}` — graph is locked (`can_edit` is false)
  - `{:error, :unauthenticated}` — user is not logged in
  """
  def check_selection_action_allowed(socket) do
    cond do
      not socket.assigns.can_edit -> {:error, :locked}
      socket.assigns.current_user == nil -> {:error, :unauthenticated}
      true -> :ok
    end
  end

  @doc """
  Unpacks a `{:selection_action, params}` message into its constituent parts.

  Returns a tuple of `{action, selected_text, node_id, offsets, existing_highlight, extra}`
  where `extra` is a map of any additional keys beyond the standard ones.
  """
  def unpack_selection_action(params) do
    %{
      action: action,
      selected_text: selected_text,
      node_id: node_id,
      offsets: offsets,
      highlight: existing_highlight
    } = params

    extra = Map.drop(params, [:action, :selected_text, :node_id, :offsets, :highlight])

    {action, selected_text, node_id, offsets, existing_highlight, extra}
  end

  @doc """
  Handles the "reply-and-answer" (ask_and_answer) action.

  Accepts an optional keyword list of options that may include:
  - `:minimal_context` — boolean, derived from prefix == "explain"
  - `:highlight_context` — string or nil

  Returns either:
  - `{:error, :locked}` when the graph is locked
  - `{:ok, graph_result, "answer"}` on success (note: `ask_and_answer`
    returns `{graph, node}` directly, not wrapped in `{nil, ...}`)
  """
  def handle_reply_and_answer(socket, answer_content, opts \\ []) do
    if not socket.assigns.can_edit do
      {:error, :locked}
    else
      graph_result =
        GraphActions.ask_and_answer(
          graph_action_params(socket, socket.assigns.node),
          answer_content,
          opts
        )

      {:ok, graph_result, "answer"}
    end
  end
end
