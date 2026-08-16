defmodule Dialectic.Graph.Creator do
  @moduledoc """
  Handles the end-to-end flow of creating a new graph from a question.
  This orchestrates database creation, graph process initialization,
  node creation, and queues asynchronous LLM generation for streaming.

  The user is redirected immediately after graph creation, and the LLM
  response streams on the graph page via PubSub for a faster perceived experience.
  """
  require Logger
  alias Dialectic.DbActions.Graphs
  alias GraphManager
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.{ModeServer, Prompts, PromptsStructured, RequestQueue}

  @doc """
  Creates a graph, adds the initial question, queues LLM generation, and saves it.

  The LLM response is generated asynchronously via streaming, allowing the user
  to be redirected immediately to the graph page where they'll see the response
  stream in real-time.

  ## Arguments
  - `question`: String, the user's initial prompt.
  - `user`: The User Ecto struct (for DB ownership).
  - `user_identity`: Map/Struct representing the user for Vertex attribution.
  - `opts`: Keyword list of options.
    - `:mode` - :expert, :university (default), :high_school, or :simple.
    - `:title` - Optional title override.
    - `:progress_callback` - Function/1 to receive status strings.
  """
  def create(question, user, user_identity, opts \\ []) do
    callback = Keyword.get(opts, :progress_callback, fn _ -> :ok end)
    title = Keyword.get(opts, :title) || Graphs.sanitize_title(question)
    mode = Keyword.get(opts, :mode, :university)
    actor_id = Keyword.get(opts, :actor_id)

    callback.("Creating grid structure...")

    if Graphs.get_graph_by_title(title) do
      {:ok, title}
    else
      do_create(title, question, user, user_identity, mode, actor_id, callback)
    end
  end

  defp do_create(title, question, user, user_identity, mode, actor_id, callback) do
    case Graphs.create_new_graph(title, user, Atom.to_string(mode)) do
      {:ok, _} ->
        ModeServer.set_mode(title, mode)

        callback.("Initializing grid...")
        GraphManager.get_graph(title)

        # Retrieve the origin node (ID "1") created by default during graph init
        origin_node = GraphManager.find_node_by_id(title, "1")

        callback.("Updating origin...")
        updated_origin = update_origin_content(title, origin_node, question)

        callback.("Preparing response...")

        # Create the empty answer node connected to origin
        answer_node = create_answer_node_struct(title, updated_origin, user_identity, mode)

        queue_result =
          queue_streaming_response(title, updated_origin, answer_node, mode, actor_id)

        unless match?({:ok, _job}, queue_result) do
          current_answer = GraphManager.find_node_by_id(title, answer_node.id)

          if current_answer && current_answer.content == "" do
            GraphManager.set_node_content(
              title,
              answer_node.id,
              queue_error_message(queue_result)
            )
          end
        end

        callback.("Finalizing...")

        case GraphManager.save_graph(title) do
          {:ok, _job} ->
            Logger.info("Successfully queued graph #{title} for persistence after creation")
            {:ok, title}

          {:error, save_reason} ->
            Logger.error(
              "Failed to queue graph #{title} for persistence: #{inspect(save_reason)}"
            )

            {:error, :save_failed}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_origin_content(title, node, question) do
    new_content = "## " <> to_string(question)
    GraphManager.set_node_content(title, node.id, new_content)
    # Explicitly return the updated node struct
    GraphManager.find_node_by_id(title, node.id)
  end

  defp queue_error_message({:error, :too_many_active_requests}) do
    "AI generation is busy with your other requests. Please regenerate this answer shortly."
  end

  defp queue_error_message({:error, :rate_limited}) do
    "AI generation was requested too quickly. Please regenerate this answer in a minute."
  end

  defp queue_error_message(_queue_result) do
    "AI generation could not be queued. Please regenerate this answer shortly."
  end

  defp create_answer_node_struct(title, parent, user_identity, mode) do
    vertex = %Vertex{
      content: "",
      class: "answer",
      user: user_identity,
      parent: nil,
      prompt_kind: "initial_explainer",
      response_level: Atom.to_string(mode)
    }

    node = GraphManager.add_node(title, vertex)
    GraphManager.add_edges(title, node, [parent])
    node
  end

  @doc """
  Queues an asynchronous streaming LLM request for the initial graph response.

  This uses the same streaming infrastructure as follow-up questions,
  allowing the response to stream in real-time on the graph page.
  """
  def queue_streaming_response(title, origin_node, answer_node, mode, actor_id \\ nil) do
    context = GraphManager.build_context(title, origin_node)
    instruction = Prompts.initial_explainer(context, origin_node.content)
    system_prompt = PromptsStructured.system_preamble(mode)

    # Use the shared graph topic so all viewers (including the user who just created
    # the graph) will receive stream chunks when they mount the graph page.
    # This matches the graph_topic pattern in GraphLive: "graph_update:#{graph_id}"
    live_view_topic = "graph_update:#{title}"

    # Queue the streaming request via the existing worker infrastructure
    case RequestQueue.add(
           instruction,
           system_prompt,
           answer_node,
           title,
           {live_view_topic, actor_id}
         ) do
      {:ok, job} ->
        Logger.debug(
          "[Creator] Queued streaming LLM request for graph=#{title} node=#{answer_node.id}"
        )

        {:ok, job}

      {:error, reason} = error ->
        Logger.error(
          "[Creator] Failed to queue streaming LLM request for graph=#{title} node=#{answer_node.id}: #{inspect(reason)}"
        )

        error

      other ->
        Logger.error(
          "[Creator] Unexpected result queueing streaming LLM request for graph=#{title} node=#{answer_node.id}: #{inspect(other)}"
        )

        other
    end
  end
end
