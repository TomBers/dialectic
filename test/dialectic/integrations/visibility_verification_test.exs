defmodule Dialectic.Integrations.VisibilityVerificationTest do
  use Dialectic.DataCase, async: false
  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{ChatGrids, GridAction, GridActions, GridVisibility}
  alias Dialectic.Workers.VisibilityVerificationWorker, as: Worker

  setup do
    user = user_fixture()
    {:ok, graph} = ChatGrids.create(user, grid_draft())

    params = %{
      "request_id" => Ecto.UUID.generate(),
      "visibility" => "public",
      "expected_revision" => graph.data_revision
    }

    {:ok, accepted} = GridVisibility.set(user, graph.slug, params)

    job = %Oban.Job{
      args: %{"request_id" => params["request_id"], "user_id" => user.id},
      attempt: 1,
      max_attempts: 3
    }

    %{user: user, graph: graph, params: params, accepted: accepted, job: job}
  end

  test "successful verification is pollable while setter replay stays exactly unchanged",
       context do
    stub_public(context)
    assert :ok = Worker.perform(context.job)
    assert {:ok, polled} = GridActions.get_operation(context.user, context.params["request_id"])
    assert polled.result["anonymous_access_verification"] == "verified"
    assert polled.result["verification_checked_at"]
    assert polled.next_poll_after_seconds == nil

    assert {:ok, context.accepted} ==
             GridVisibility.set(context.user, context.graph.slug, context.params)

    assert Repo.get_by!(GridAction, request_id: context.params["request_id"]).result ==
             context.accepted.result

    Req.Test.stub(Worker, fn _conn -> flunk("terminal verification must not run again") end)
    assert :ok = Worker.perform(context.job)
  end

  test "network failures and unavailable destinations retry before failing durably", context do
    Req.Test.stub(Worker, &Req.Test.transport_error(&1, :timeout))
    assert {:error, :verification_pending} = Worker.perform(context.job)
    assert {:ok, pending} = GridActions.get_operation(context.user, context.params["request_id"])
    assert pending.result["anonymous_access_verification"] == "pending"
    assert pending.result["verification_error"] == "network_error"
    assert pending.next_poll_after_seconds == 3

    Req.Test.stub(Worker, &Plug.Conn.send_resp(&1, 503, "temporarily unavailable"))
    assert {:error, :verification_pending} = Worker.perform(%{context.job | attempt: 2})
    assert :ok = Worker.perform(%{context.job | attempt: 3})
    assert {:ok, failed} = GridActions.get_operation(context.user, context.params["request_id"])
    assert failed.result["anonymous_access_verification"] == "failed"
    assert failed.result["verification_error"] == "destination_unavailable"

    assert {:ok, context.accepted} ==
             GridVisibility.set(context.user, context.graph.slug, context.params)
  end

  test "a temporary failure can recover on a later attempt", context do
    Req.Test.stub(Worker, &Plug.Conn.send_resp(&1, 429, "try later"))
    assert {:error, :verification_pending} = Worker.perform(context.job)
    stub_public(context)
    assert :ok = Worker.perform(%{context.job | attempt: 2})
    assert receipt(context).verification["anonymous_access_verification"] == "verified"
  end

  test "a reachable public destination with a different revision is not verified", context do
    Req.Test.stub(Worker, fn conn ->
      Req.Test.json(conn, %{
        grid: %{id: context.graph.slug, visibility: "public", visibility_version: 1},
        snapshot_revision: context.graph.data_revision + 1
      })
    end)

    assert {:error, :verification_pending} = Worker.perform(context.job)
    assert receipt(context).verification["verification_error"] == "revision_not_propagated"
    refute_received {:canonical_read, _}
  end

  test "local content changes invalidate publication verification", context do
    context.graph |> Repo.reload!() |> Ecto.Changeset.change(data_revision: 10) |> Repo.update!()
    Req.Test.stub(Worker, fn _ -> flunk("obsolete revision must not trigger HTTP") end)
    assert :ok = Worker.perform(context.job)
    assert receipt(context).verification["verification_error"] == "content_revision_changed"
  end

  test "a private transition during HTTP verification cannot be affirmed", context do
    Req.Test.stub(Worker, fn conn ->
      case conn.request_path do
        "/api/mcp/grids/" <> _ ->
          Req.Test.json(conn, %{
            grid: %{id: context.graph.slug, visibility: "public", visibility_version: 1},
            snapshot_revision: context.graph.data_revision
          })

        "/g/" <> _ ->
          {:ok, _} = GridVisibility.change(context.graph, context.user, false)
          Plug.Conn.send_resp(conn, 200, "a response from before revocation")
      end
    end)

    assert :ok = Worker.perform(context.job)
    assert receipt(context).verification["anonymous_access_verification"] == "failed"
    assert receipt(context).verification["verification_error"] == "visibility_changed"
    refute Repo.reload!(context.graph).is_public
  end

  test "private verification checks canonical and both export routes", context do
    params = %{"request_id" => Ecto.UUID.generate(), "visibility" => "private"}
    {:ok, accepted} = GridVisibility.set(context.user, context.graph.slug, params)

    Req.Test.stub(Worker, fn conn ->
      send(self(), {:private_read, conn.request_path})

      status =
        cond do
          String.starts_with?(conn.request_path, "/api/mcp/") -> 401
          String.starts_with?(conn.request_path, "/api/graphs/") -> 403
          true -> 302
        end

      Plug.Conn.send_resp(conn, status, "")
    end)

    job = %{
      context.job
      | args: %{"request_id" => params["request_id"], "user_id" => context.user.id}
    }

    assert :ok = Worker.perform(job)
    assert {:ok, polled} = GridActions.get_operation(context.user, params["request_id"])
    assert polled.result["anonymous_access_verification"] == "verified"
    assert {:ok, ^accepted} = GridVisibility.set(context.user, context.graph.slug, params)

    for path <- ["/api/mcp/grids/", "/api/graphs/json/", "/g/"] do
      expected = path <> context.graph.slug
      assert_received {:private_read, ^expected}
    end
  end

  defp receipt(context), do: Repo.get_by!(GridAction, request_id: context.params["request_id"])

  defp stub_public(context) do
    Req.Test.stub(Worker, fn conn ->
      if String.starts_with?(conn.request_path, "/api/mcp/") do
        Req.Test.json(conn, %{
          grid: %{id: context.graph.slug, visibility: "public", visibility_version: 1},
          snapshot_revision: context.graph.data_revision
        })
      else
        send(self(), {:canonical_read, conn.request_path})
        Plug.Conn.send_resp(conn, 200, "public destination")
      end
    end)
  end
end
