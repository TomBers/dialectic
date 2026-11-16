defmodule Dialectic.Workers.VisibilityVerificationWorker do
  use Oban.Worker, queue: :api_request, max_attempts: 3
  import Ecto.Query
  alias Dialectic.Accounts.Graph
  alias Dialectic.Integrations.GridAction
  alias Dialectic.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => uuid, "user_id" => user_id}} = job) do
    receipt = Repo.get_by(GridAction, request_id: uuid, user_id: user_id)

    cond do
      is_nil(receipt) ->
        :ok

      receipt.verification["anonymous_access_verification"] in ["verified", "failed"] ->
        :ok

      true ->
        graph = if receipt.graph_title, do: Repo.get(Graph, receipt.graph_title)

        outcome =
          with :ok <- current_intent(graph, receipt) do
            verify(graph, receipt)
          end

        persist_outcome(receipt, outcome, job)
    end
  end

  defp persist_outcome(receipt, outcome, job) do
    result =
      Repo.transact(fn ->
        graph =
          if receipt.graph_title,
            do:
              Repo.one(
                from g in Graph, where: g.title == ^receipt.graph_title, lock: "FOR UPDATE"
              )

        current = Repo.one!(from a in GridAction, where: a.id == ^receipt.id, lock: "FOR UPDATE")

        if current.verification["anonymous_access_verification"] in ["verified", "failed"] do
          {:ok, :terminal}
        else
          outcome =
            case current_intent(graph, current) do
              :ok -> outcome
              error -> error
            end

          {state, reason} =
            case outcome do
              :ok -> {"verified", nil}
              {:error, reason} -> {"failed", reason}
              {:retry, reason} when job.attempt < job.max_attempts -> {"pending", reason}
              {:retry, reason} -> {"failed", reason}
            end

          verification = %{
            "anonymous_access_verification" => state,
            "verification_checked_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "verification_error" => reason
          }

          with {:ok, _} <-
                 current |> Ecto.Changeset.change(verification: verification) |> Repo.update() do
            {:ok, if(state == "pending", do: :retry, else: :terminal)}
          end
        end
      end)

    case result do
      {:ok, :retry} -> {:error, :verification_pending}
      {:ok, :terminal} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp current_intent(nil, _receipt), do: {:error, "grid_unavailable"}

  defp current_intent(graph, receipt) do
    cond do
      graph.is_deleted == true or graph.user_id != receipt.user_id ->
        {:error, "grid_unavailable"}

      graph.visibility_version != receipt.result["visibility_version"] or
          graph.is_public != (receipt.result["visibility"] == "public") ->
        {:error, "visibility_changed"}

      graph.is_public and graph.data_revision != receipt.completed_revision ->
        {:error, "content_revision_changed"}

      true ->
        :ok
    end
  end

  defp verify(graph, %{result: %{"visibility" => "public"}} = receipt) do
    case fetch("/api/mcp/grids/" <> graph.slug) do
      {:ok,
       %{
         status: 200,
         body: %{
           "grid" => %{"id" => id, "visibility" => "public", "visibility_version" => version},
           "snapshot_revision" => revision
         }
       }}
      when id == graph.slug and revision == receipt.completed_revision ->
        if version == receipt.result["visibility_version"] do
          expect_status("/g/" <> graph.slug, [200])
        else
          {:retry, "visibility_not_propagated"}
        end

      {:ok, %{status: 200}} ->
        {:retry, "revision_not_propagated"}

      response ->
        retry_reason(response)
    end
  end

  defp verify(graph, _receipt) do
    with :ok <- expect_status("/api/mcp/grids/" <> graph.slug, [401, 404]),
         :ok <- expect_status("/api/graphs/json/" <> graph.slug, [403, 404]) do
      expect_status("/g/" <> graph.slug, [302, 303, 403, 404])
    end
  end

  defp expect_status(path, statuses) do
    case fetch(path) do
      {:ok, %{status: status}} = response ->
        if status in statuses, do: :ok, else: retry_reason(response)

      response ->
        retry_reason(response)
    end
  end

  defp retry_reason({:error, _}), do: {:retry, "network_error"}

  defp retry_reason({:ok, %{status: status}}) when status == 429 or status >= 500,
    do: {:retry, "destination_unavailable"}

  defp retry_reason(_), do: {:retry, "access_not_propagated"}

  defp fetch(path) do
    options = Application.get_env(:dialectic, __MODULE__, []) |> Keyword.get(:req_options, [])

    Req.new(options)
    |> Req.get(
      url: DialecticWeb.Endpoint.url() <> path,
      redirect: false,
      retry: false,
      receive_timeout: 5_000,
      connect_options: [timeout: 5_000]
    )
  end
end
