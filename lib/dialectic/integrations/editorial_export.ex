defmodule Dialectic.Integrations.EditorialExport do
  alias Dialectic.DbActions.Sharing
  alias Dialectic.Integrations.GridContent

  def read(user, slug, params) do
    with {:ok, revision, offset} <- position(slug, params),
         graph when not is_nil(graph) <- Sharing.get_accessible_graph(user, slug),
         true <- graph.user_id == user.id or graph.data_revision == revision,
         {:ok, raw, ^revision} <- GridContent.at_revision(graph, revision) do
      content = GridContent.serialize(raw, graph.title, revision)
      hash = GridContent.content_hash(Jason.encode!(content))
      nodes = Enum.slice(content.nodes, offset, 50)
      ids = MapSet.new(nodes, & &1.id)
      more? = offset + 50 < length(content.nodes)

      {:ok,
       %{
         schema_version: "editorial_v1",
         grid_id: slug,
         revision: revision,
         content_hash: hash,
         nodes: nodes,
         edges:
           Enum.filter(
             content.edges,
             &(MapSet.member?(ids, &1.from) or MapSet.member?(ids, &1.to))
           ),
         total_nodes: length(content.nodes),
         next_cursor:
           if(more?,
             do:
               Phoenix.Token.sign(
                 DialecticWeb.Endpoint,
                 "editorial-export-v1",
                 {slug, revision, offset + 50}
               ),
             else: nil
           ),
         final_content_hash: if(more?, do: nil, else: hash),
         brief_status: "not_prepared",
         subject: nil,
         central_tension: nil,
         reader_payoff: nil,
         claims: nil,
         examples: nil,
         competing_readings: nil,
         qualifications: nil,
         open_questions: nil,
         recommended_node_ids: nil,
         readiness: nil,
         unresolved_issues: nil,
         field_availability: %{
           graph: "available",
           editorial_brief: "not_prepared",
           claim_verification: "unavailable"
         },
         visibility: %{
           value: if(graph.is_public, do: "public", else: "private"),
           version: graph.visibility_version,
           observed_at: DateTime.utc_now()
         }
       }}
    else
      nil -> {:error, :not_found}
      false -> {:error, :stale_snapshot}
      error -> error
    end
  end

  defp position(slug, params) do
    with "editorial_v1" <- Map.get(params, "profile", "editorial_v1"),
         value when is_binary(value) <- params["revision"],
         {revision, ""} when revision >= 0 <- Integer.parse(value) do
      case params["cursor"] do
        nil ->
          {:ok, revision, 0}

        cursor when is_binary(cursor) and byte_size(cursor) <= 2048 ->
          case Phoenix.Token.verify(DialecticWeb.Endpoint, "editorial-export-v1", cursor,
                 max_age: 604_800
               ) do
            {:ok, {^slug, ^revision, offset}} when is_integer(offset) and offset >= 0 ->
              {:ok, revision, offset}

            _ ->
              {:error, :stale_snapshot}
          end

        _ ->
          {:error, :invalid_arguments}
      end
    else
      _ -> {:error, :invalid_arguments}
    end
  end
end
