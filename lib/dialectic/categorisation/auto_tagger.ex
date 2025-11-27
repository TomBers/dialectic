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
      provider_mod = get_provider()

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

      case make_request(provider_mod, system_prompt, user_prompt) do
        {:ok, text} ->
          case parse_tags(text) do
            {:ok, tags} ->
              Logger.info("AutoTagger generated tags for #{graph.title}: #{inspect(tags)}")
              Graphs.update_tags(graph, tags)

            {:error, _} ->
              Logger.warning("AutoTagger failed to parse response: #{text}")
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

  defp make_request(provider_mod, system_prompt, user_prompt) do
    case Dialectic.LLM.Provider.api_key(provider_mod) do
      {:ok, api_key} ->
        model_spec = Dialectic.LLM.Provider.model_spec(provider_mod)
        {_, receive_timeout} = Dialectic.LLM.Provider.timeouts(provider_mod)
        finch_name = Dialectic.LLM.Provider.finch_name(provider_mod)
        provider_options = provider_mod.provider_options()

        ctx =
          ReqLLM.Context.new([
            ReqLLM.Context.system(system_prompt),
            ReqLLM.Context.user(user_prompt)
          ])

        case ReqLLM.stream_text(
               model_spec,
               ctx,
               api_key: api_key,
               finch_name: finch_name,
               provider_options: provider_options,
               receive_timeout: receive_timeout
             ) do
          {:ok, stream_resp} ->
            text =
              stream_resp
              |> ReqLLM.StreamResponse.tokens()
              |> Enum.reduce("", fn token, acc ->
                chunk =
                  case token do
                    t when is_binary(t) -> t
                    t when is_list(t) -> IO.iodata_to_binary(t)
                    t -> to_string(t)
                  end

                acc <> chunk
              end)

            {:ok, text}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp get_provider do
    case System.get_env("LLM_PROVIDER") do
      "google" -> Dialectic.LLM.Providers.Google
      "gemini" -> Dialectic.LLM.Providers.Google
      _ -> Dialectic.LLM.Providers.OpenAI
    end
  end
end
