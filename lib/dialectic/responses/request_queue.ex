defmodule Dialectic.Responses.RequestQueue do
  @moduledoc """
  Manages the queue for LLM requests using Oban.

  This module handles job deduplication to prevent duplicate LLM requests
  for the same graph/node combination within a 60-second window.
  """
  import Ecto.Query

  alias Dialectic.Repo
  alias Dialectic.Responses.{ModeServer, PromptsStructured}
  alias Dialectic.Workers.LLMWorker
  alias Dialectic.Workers.LocalWorker

  require Logger

  @active_states ["available", "scheduled", "executing", "retryable"]
  @default_max_active_per_actor 3
  @default_max_requests_per_minute 10
  @rate_window_ms :timer.minutes(1)

  def add(instruction, system_prompt, to_node, graph, live_view_topic) do
    add(instruction, system_prompt, to_node, graph, live_view_topic, [])
  end

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(instruction, system_prompt, to_node, graph, live_view_topic, opts) do
      instruction
      |> build_params(system_prompt, to_node, graph, live_view_topic, opts)
      |> run_local()
    end
  else
    # Non-test environments use LLMWorker
    def add(instruction, system_prompt, to_node, graph, live_view_topic, opts) do
      instruction
      |> build_params(system_prompt, to_node, graph, live_view_topic, opts)
      |> run_llm()
    end
  end

  def run_local(params) do
    Logger.debug(fn ->
      "[RequestQueue] Queueing LOCAL job for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}"
    end)

    job =
      %{
        params
        | module: Dialectic.Workers.LocalWorker
      }
      |> LocalWorker.new(
        unique: [
          keys: [:graph, :to_node],
          period: 60,
          states: [:available, :scheduled, :executing, :retryable]
        ]
      )

    case Oban.insert(job) do
      {:ok, %{conflict?: true} = oban_job} ->
        Logger.warning(fn ->
          "[RequestQueue] DUPLICATE LOCAL job detected for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)} - existing job_id=#{oban_job.id}"
        end)

        {:ok, oban_job}

      {:ok, oban_job} ->
        Logger.debug(fn ->
          "[RequestQueue] LOCAL job inserted job_id=#{oban_job.id} for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}"
        end)

        {:ok, oban_job}

      {:error, reason} = error ->
        Logger.error(fn ->
          "[RequestQueue] Failed to insert LOCAL job for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}: #{inspect(reason)}"
        end)

        error
    end
  end

  def run_llm(params) do
    params = ensure_actor_key(params)

    Logger.debug(fn ->
      "[RequestQueue] Queueing LLM job for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}"
    end)

    job =
      %{
        params
        | module: Dialectic.Workers.LLMWorker
      }
      |> LLMWorker.new(
        priority: 0,
        max_attempts: 3,
        tags: ["llm"],
        unique: [
          keys: [:graph, :to_node],
          period: 60,
          states: [:available, :scheduled, :executing, :retryable]
        ]
      )

    case insert_with_admission(job, params) do
      {:ok, %{conflict?: true} = oban_job} ->
        Logger.warning(fn ->
          "[RequestQueue] DUPLICATE LLM job detected for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)} - existing job_id=#{oban_job.id}"
        end)

        {:ok, oban_job}

      {:ok, oban_job} ->
        Logger.debug(fn ->
          "[RequestQueue] LLM job inserted job_id=#{oban_job.id} for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}"
        end)

        {:ok, oban_job}

      {:error, :too_many_active_requests} = error ->
        reject_request(
          params,
          "You already have #{max_active_per_actor()} AI requests in progress. Please wait for one to finish."
        )

        error

      {:error, :rate_limited} = error ->
        reject_request(
          params,
          "You are requesting AI responses too quickly. Please wait a minute."
        )

        error

      {:error, reason} = error ->
        Logger.error(fn ->
          "[RequestQueue] Failed to insert LLM job for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}: #{inspect(reason)}"
        end)

        error
    end
  end

  defp build_params(instruction, system_prompt, to_node, graph, request_context, opts) do
    node_id = if is_map(to_node), do: to_node.id, else: to_node
    {live_view_topic, anonymous_actor_id} = split_request_context(request_context)
    mode = Keyword.get_lazy(opts, :mode, fn -> ModeServer.get_mode(graph) end)

    %{
      instruction: instruction,
      system_prompt: system_prompt,
      question: instruction,
      to_node: node_id,
      graph: graph,
      module: nil,
      live_view_topic: live_view_topic,
      actor_key: actor_key(to_node, graph, anonymous_actor_id),
      response_level: mode |> PromptsStructured.response_profile() |> Map.fetch!(:key),
      max_tokens: PromptsStructured.max_output_tokens(mode)
    }
  end

  defp ensure_actor_key(params) do
    Map.put_new_lazy(params, :actor_key, fn ->
      actor_key(nil, Map.get(params, :graph, "unknown"), nil)
    end)
  end

  defp split_request_context({live_view_topic, anonymous_actor_id})
       when is_binary(live_view_topic) do
    {live_view_topic, anonymous_actor_id}
  end

  defp split_request_context(live_view_topic), do: {live_view_topic, nil}

  defp actor_key(%{user: user}, _graph, _anonymous_actor_id)
       when is_binary(user) and user not in ["", "anonymous"] do
    hash_actor("user:#{user}")
  end

  defp actor_key(_to_node, _graph, anonymous_actor_id)
       when is_binary(anonymous_actor_id) and anonymous_actor_id != "" do
    hash_actor("anonymous:#{anonymous_actor_id}")
  end

  defp actor_key(_to_node, graph, _anonymous_actor_id) do
    hash_actor("graph:#{graph}")
  end

  defp hash_actor(actor) do
    :sha256
    |> :crypto.hash(actor)
    |> Base.url_encode64(padding: false)
  end

  defp insert_with_admission(job, params) do
    case Repo.transaction(fn ->
           lock_actor(params.actor_key)

           cond do
             duplicate_active_request?(params) ->
               Oban.insert(job)

             active_request_count(params.actor_key) >= max_active_per_actor() ->
               Repo.rollback(:too_many_active_requests)

             rate_limited?(params.actor_key) ->
               Repo.rollback(:rate_limited)

             true ->
               Oban.insert(job)
           end
         end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp lock_actor(actor_key) do
    <<lock_key::signed-64, _rest::binary>> = :crypto.hash(:sha256, actor_key)
    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])
    :ok
  end

  defp duplicate_active_request?(params) do
    worker = Oban.Worker.to_string(LLMWorker)
    graph = to_string(params.graph)
    to_node = to_string(params.to_node)

    Repo.exists?(
      from job in Oban.Job,
        where:
          job.worker == ^worker and job.state in ^@active_states and
            fragment("?->>'graph' = ?", job.args, ^graph) and
            fragment("?->>'to_node' = ?", job.args, ^to_node)
    )
  end

  defp active_request_count(actor_key) do
    worker = Oban.Worker.to_string(LLMWorker)

    Repo.aggregate(
      from(job in Oban.Job,
        where:
          job.worker == ^worker and job.state in ^@active_states and
            fragment("?->>'actor_key' = ?", job.args, ^actor_key)
      ),
      :count
    )
  end

  defp rate_limited?(actor_key) do
    case Hammer.check_rate(
           "llm_admission:#{actor_key}",
           @rate_window_ms,
           max_requests_per_minute()
         ) do
      {:allow, _count} ->
        false

      {:deny, _limit} ->
        true

      {:error, reason} ->
        Logger.error("[RequestQueue] Rate limiter unavailable: #{inspect(reason)}")
        false
    end
  end

  defp admission_config do
    Application.get_env(:dialectic, :llm_admission, [])
  end

  defp max_active_per_actor do
    case Keyword.get(admission_config(), :max_active_per_actor, @default_max_active_per_actor) do
      value when is_integer(value) and value > 0 -> value
      _other -> @default_max_active_per_actor
    end
  end

  defp max_requests_per_minute do
    case Keyword.get(
           admission_config(),
           :max_requests_per_minute,
           @default_max_requests_per_minute
         ) do
      value when is_integer(value) and value > 0 -> value
      _other -> @default_max_requests_per_minute
    end
  end

  defp reject_request(params, message) do
    Logger.warning(
      "[RequestQueue] LLM request rejected for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}: #{message}"
    )

    if GraphManager.exists?(params.graph) do
      GraphManager.set_node_content(params.graph, params.to_node, message)
      GraphManager.save_graph(params.graph)
    end

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      params.live_view_topic,
      {:stream_error, message, :node_id, params.to_node}
    )

    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      params.live_view_topic,
      {:llm_request_complete, params.to_node}
    )
  end
end
