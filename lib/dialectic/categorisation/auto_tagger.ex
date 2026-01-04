defmodule Dialectic.Categorisation.AutoTagger do
  @moduledoc """
  Automatically categorizes graphs by generating tags using an LLM.
  """
  require Logger
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.Serialise

  @doc """
  Analyzes the graph content and updates its tags asynchronously.
  """
  def tag_graph(graph) do
    Task.Supervisor.start_child(Dialectic.TaskSupervisor, fn ->
      try do
        generate_tags(graph)
      rescue
        e ->
          Logger.error("AutoTagger failed for graph #{graph.title}: #{inspect(e)}")
      end
    end)
  end

  defp generate_tags(graph) do
    content = get_origin_content(graph)

    if content != "" do
      system_prompt = """
      You are an expert librarian and taxonomist.
      Analyze the following discussion topic and context.
      Generate 3 to 5 short, relevant, high-level category tags.

      Rules:
      1. Tags must be single words or short phrases (e.g. "Philosophy", "Artificial Intelligence").
      2. Return ONLY a valid JSON array of strings. No markdown formatting, no explanations.
      3. Example output: ["Technology", "Ethics", "Future"]
      """

      user_prompt = """
      Title: #{graph.title}

      Content:
      #{content}
      """

      # Use a faster model for Google/Gemini
      model =
        case System.get_env("LLM_PROVIDER") do
          "google" -> "gemini-2.5-flash-lite"
          "gemini" -> "gemini-2.5-flash-lite"
          _ -> nil
        end

      opts =
        [system_prompt: system_prompt]
        |> then(&if(model, do: Keyword.put(&1, :model, model), else: &1))

      case Dialectic.LLM.Generator.generate(user_prompt, opts) do
        {:ok, text} ->
          case parse_tags(text) do
            {:ok, tags} ->
              Logger.info("AutoTagger generated tags for #{graph.title}: #{inspect(tags)}")
              Graphs.update_tags(graph, tags)

            {:error, _} ->
              Logger.warning("AutoTagger failed to parse response: #{inspect(text)}")
          end

        {:error, reason} ->
          Logger.error("AutoTagger LLM error: #{inspect(reason)}")
      end
    end
  end

  defp get_origin_content(graph) do
    digraph = Serialise.json_to_graph(graph.data)

    case :digraph.vertex(digraph, "1") do
      {_v, data} -> data.content
      false -> ""
    end
  end

  defp parse_tags(text) do
    # Cleanup markdown code blocks if present
    clean_text =
      text
      |> String.replace(~r/^```json\s*/i, "")
      |> String.replace(~r/^```\s*/i, "")
      |> String.replace(~r/\s*```$/i, "")
      |> String.trim()

    case Jason.decode(clean_text) do
      {:ok, list} when is_list(list) ->
        # Filter for strings only and limit to reasonable length
        tags =
          list
          |> Enum.filter(&is_binary/1)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.take(5)

        {:ok, tags}

      _ ->
        {:error, :invalid_json}
    end
  end
end
