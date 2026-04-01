defmodule Dialectic.Graph.Creator do
  @moduledoc """
  Handles the end-to-end flow of creating a new graph from a question.
  This orchestrates database creation, graph process initialization,
  node creation, and synchronous LLM generation.
  """
  require Logger
  alias Dialectic.DbActions.Graphs
  alias GraphManager
  alias Dialectic.Graph.Vertex
  alias Dialectic.Responses.{ModeServer, Prompts, PromptsStructured}

  @doc """
  Creates a graph, adds the initial question, generates an answer, and saves it.

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

    callback.("Creating grid structure...")

    if Graphs.get_graph_by_title(title) do
      {:ok, title}
    else
      do_create(title, question, user, user_identity, mode, callback)
    end
  end

  defp do_create(title, question, user, user_identity, mode, callback) do
    case Graphs.create_new_graph(title, user, Atom.to_string(mode)) do
      {:ok, _} ->
        ModeServer.set_mode(title, mode)

        callback.("Initializing grid...")

        case GraphManager.get_graph(title) do
          {:error, reason} ->
            Logger.error("Failed to initialize GraphManager for new graph: #{inspect(reason)}")
            {:error, reason}

          _graph_data ->
            # Retrieve the origin node (ID "1") created by default during graph init
            origin_node = GraphManager.find_node_by_id(title, "1")

            callback.("Updating origin...")
            updated_origin = update_origin_content(title, origin_node, question)

            callback.("Generating response (this may take a moment)...")

            # Create the empty answer node connected to origin
            answer_node = create_answer_node_struct(title, updated_origin, user_identity)

            Logger.info("Created answer node for graph creation",
              graph_id: title,
              answer_node_id: answer_node.id,
              parent_node_id: updated_origin.id
            )

            # Generate LLM response synchronously
            Logger.info("Starting synchronous LLM generation for graph creation",
              graph_id: title,
              mode: mode
            )

            case generate_response(title, updated_origin, mode) do
              {:ok, content} ->
                Logger.info("LLM generation succeeded for graph creation",
                  graph_id: title,
                  content_length: byte_size(content)
                )

                GraphManager.set_node_content(title, answer_node.id, content)
                GraphManager.finalize_node_content(title, answer_node.id)
                GraphManager.save_graph(title)

                callback.("Finalizing...")
                {:ok, title}

              {:error, reason} ->
                Logger.error("Graph creation LLM generation failed",
                  graph_id: title,
                  answer_node_id: answer_node.id,
                  reason: inspect(reason)
                )

                # If generation fails, we still return the graph, just with empty answer node
                # The answer node has been created, it just has no content
                GraphManager.save_graph(title)
                callback.("Finalizing...")
                {:ok, title}
            end
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

  defp create_answer_node_struct(title, parent, user_identity) do
    vertex = %Vertex{
      content: "",
      class: "answer",
      user: user_identity,
      parent: nil
    }

    node = GraphManager.add_node(title, vertex)
    GraphManager.add_edges(title, node, [parent])

    Logger.debug("Created answer node structure",
      graph_id: title,
      node_id: node.id,
      parent_id: parent.id
    )

    node
  end

  defp generate_response(title, origin_node, mode) do
    context = GraphManager.build_context(title, origin_node)
    instruction = Prompts.initial_explainer(context, origin_node.content)

    system_prompt = PromptsStructured.system_preamble(mode)

    opts = [
      system_prompt: system_prompt
    ]

    Logger.debug("Calling LLM Generator",
      graph_id: title,
      mode: mode,
      instruction_length: byte_size(instruction)
    )

    result = Dialectic.LLM.Generator.generate(instruction, opts)

    case result do
      {:ok, content} ->
        Logger.debug("Generator returned success",
          graph_id: title,
          response_length: byte_size(content)
        )

      {:error, reason} ->
        Logger.error("Generator returned error",
          graph_id: title,
          reason: inspect(reason)
        )
    end

    result
  end
end
