defmodule Dialectic.Content.PromotionMaterial do
  @moduledoc false

  alias Dialectic.Content
  alias Dialectic.Highlights

  def list_graphs do
    graphs = Content.list_public_graphs()

    %{
      "count" => length(graphs),
      "grids" =>
        Enum.map(graphs, fn {graph, node_count} ->
          metadata(graph, node_count)
        end)
    }
  end

  def build(graph) do
    %{
      "metadata" => metadata(graph, Content.node_count(graph)),
      "graph" => graph.data || %{},
      "highlights" =>
        Highlights.list_highlights(mudg_id: graph.title) |> Enum.map(&highlight_material/1)
    }
  end

  defp metadata(graph, node_count) do
    %{
      title: graph.title,
      slug: graph.slug,
      url: graph_url(graph),
      api_url: graph_api_url(graph),
      tags: graph.tags || [],
      node_count: node_count,
      inserted_at: iso8601(graph.inserted_at),
      updated_at: iso8601(graph.updated_at)
    }
  end

  defp highlight_material(highlight) do
    %{
      id: highlight.id,
      node_id: highlight.node_id,
      text_source_type: highlight.text_source_type,
      text_source_id: highlight.text_source_id,
      selection_start: highlight.selection_start,
      selection_end: highlight.selection_end,
      text: highlight.selected_text_snapshot,
      note: highlight.note,
      inserted_at: iso8601(highlight.inserted_at),
      updated_at: iso8601(highlight.updated_at)
    }
  end

  defp graph_url(graph),
    do: DialecticWeb.Endpoint.url() <> DialecticWeb.GraphPathHelper.graph_path(graph)

  defp graph_api_url(graph) do
    DialecticWeb.Endpoint.url() <> "/api/promotion/grids/#{graph_identifier(graph)}"
  end

  defp graph_identifier(%{slug: slug}) when is_binary(slug) and slug != "", do: slug

  defp graph_identifier(%{title: title}) do
    URI.encode(to_string(title), &URI.char_unreserved?/1)
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(value), do: to_string(value)
end
