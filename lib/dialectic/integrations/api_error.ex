defmodule Dialectic.Integrations.ApiError do
  def data(reason, request_id \\ nil) do
    {code, retryable, delay, accepted} =
      case reason do
        :rate_limited -> {"rate_limited", true, 60, false}
        :too_many_active_requests -> {"too_many_active_generations", true, 20, false}
        :too_many_active_operations -> {"too_many_active_operations", true, 20, false}
        :request_conflict -> {"request_conflict", false, nil, false}
        :unavailable -> {"result_unavailable", false, nil, true}
        :not_found -> {"not_found_or_inaccessible", false, nil, false}
        :locked -> {"editing_disabled", false, nil, false}
        :stale -> {"stale_revision", false, nil, false}
        :stale_snapshot -> {"stale_snapshot", false, nil, false}
        :source_changed -> {"source_changed", false, nil, false}
        :invalid_selection -> {"invalid_selection", false, nil, false}
        :selection_not_found -> {"invalid_selection", false, nil, false}
        :invalid_context -> {"invalid_context", false, nil, false}
        :generation_in_progress -> {"generation_in_progress", true, 3, false}
        :invalid_token -> {"invalid_token", false, nil, false}
        :insufficient_scope -> {"insufficient_scope", false, nil, false}
        _ -> {"invalid_arguments", false, nil, false}
      end

    %{
      code: code,
      retryable: retryable,
      retry_after_seconds: delay,
      request_accepted: accepted,
      request_id:
        case Ecto.UUID.cast(request_id) do
          {:ok, uuid} -> uuid
          _ -> nil
        end
    }
  end
end
