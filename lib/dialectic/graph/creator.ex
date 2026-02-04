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

    callback.("Creating mind map structure...")

    if Graphs.get_graph_by_title(title) do
      {:ok, title}
    else
      do_create(title, question, user, user_identity, mode, callback)
    end
  end

  defp do_create(title, question, user, user_identity, mode, callback) do
    case Graphs.create_new_graph(title, user) do
      {:ok, _} ->
        ModeServer.set_mode(title, mode)

        callback.("Initializing whiteboard...")
        GraphManager.get_graph(title)

        # Retrieve the origin node (ID "1") created by default during graph init
        origin_node = GraphManager.find_node_by_id(title, "1")

        callback.("Updating origin...")
        updated_origin = update_origin_content(title, origin_node, question)

        callback.("Generating response (this may take a moment)...")

        # Create the empty answer node connected to origin
        answer_node = create_answer_node_struct(title, updated_origin, user_identity)

        # Generate LLM response synchronously
        case generate_response(title, updated_origin, mode) do
          {:ok, content} ->
            GraphManager.set_node_content(title, answer_node.id, content)
            GraphManager.finalize_node_content(title, answer_node.id)
            GraphManager.save_graph(title)

            callback.("Finalizing...")
            {:ok, title}

          {:error, reason} ->
            Logger.error("Graph creation LLM error: #{inspect(reason)}")
            # If generation fails, we still return the graph, just with empty answer node
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_origin_content(title, node, question) do
    decoded_q = URI.decode_www_form(to_string(question))
    new_content = "## " <> decoded_q
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
    node
  end

  defp generate_response(title, origin_node, mode) do
    context = GraphManager.build_context(title, origin_node)
    instruction = Prompts.initial_explainer(context, origin_node.content)

    system_prompt = PromptsStructured.system_preamble(mode)

    opts = [
      system_prompt: system_prompt,
      model: "gemini-3-flash-preview"
    ]

    Dialectic.LLM.Generator.generate(instruction, opts)
  end
end
