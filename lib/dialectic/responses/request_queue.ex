defmodule Dialectic.Responses.RequestQueue do
  @moduledoc """
  Manages the queue for LLM requests using Oban.

  This module handles job deduplication to prevent duplicate LLM requests
  for the same graph/node combination within a 60-second window.
  """
  alias Dialectic.Workers.LLMWorker
  alias Dialectic.Workers.LocalWorker
  require Logger

  # Define the implementation based on compile-time environment
  if Mix.env() == :test do
    # Test environment uses local model
    def add(instruction, system_prompt, to_node, graph, live_view_topic) do
      node_id = if is_map(to_node), do: to_node.id, else: to_node

      params = %{
        instruction: instruction,
        system_prompt: system_prompt,
        question: instruction,
        to_node: node_id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      run_local(params)
    end
  else
    # Non-test environments use LLMWorker
    def add(instruction, system_prompt, to_node, graph, live_view_topic) do
      node_id = if is_map(to_node), do: to_node.id, else: to_node

      params = %{
        instruction: instruction,
        system_prompt: system_prompt,
        question: instruction,
        to_node: node_id,
        graph: graph,
        module: nil,
        live_view_topic: live_view_topic
      }

      run_llm(params)
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

    case Oban.insert(job) do
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

      {:error, reason} = error ->
        Logger.error(fn ->
          "[RequestQueue] Failed to insert LLM job for graph=#{inspect(params.graph)} node=#{inspect(params.to_node)}: #{inspect(reason)}"
        end)

        error
    end
  end
end
