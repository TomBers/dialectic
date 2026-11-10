defmodule Dialectic.Integrations.McpCapabilities do
  def max_active_explorations do
    case Application.get_env(:dialectic, :mcp_limits, [])[:max_active_explorations] do
      value when is_integer(value) and value > 0 -> value
      _ -> 3
    end
  end

  def get do
    Map.merge(Dialectic.Responses.RequestQueue.limits(), %{
      max_active_explorations: max_active_explorations(),
      suggested_poll_interval_seconds: 3,
      api_requests_per_minute: 120,
      publication_supported: false,
      batch_supported: false,
      notifications_supported: false,
      stage_recovery_supported: false,
      revision_bound_reads_supported: true,
      content_limits: %{
        question_characters: 4000,
        title_characters: 140,
        idea_characters: 4000,
        read_page_nodes: 50,
        search_results: 20
      }
    })
  end
end
