defmodule DialecticWeb.GraphPathHelper do
  @moduledoc """
  Helper functions for generating graph URLs using slug-based routes.

  All graphs should have slugs generated automatically.
  """

  @doc """
  Generates a path to a graph using its slug.

  ## Examples

      # With a graph struct
      graph_path(%{slug: "my-graph-abc123"})
      # => "/g/my-graph-abc123"

      # With a node parameter
      graph_path(%{slug: "my-graph-abc123"}, "5")
      # => "/g/my-graph-abc123?node=5"
  """
  def graph_path(graph, node \\ nil, params \\ [])

  def graph_path(%{slug: slug} = _graph, node, params) when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}"
    build_path_with_params(base_path, node, params)
  end

  @doc """
  Generates a path to the linear view of a graph.

  ## Examples

      graph_linear_path(%{slug: "my-graph-abc123"})
      # => "/g/my-graph-abc123/linear"
  """
  def graph_linear_path(graph, node_id \\ nil, params \\ [])

  def graph_linear_path(%{slug: slug} = _graph, node_id, params)
      when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}/linear"
    build_path_with_params(base_path, node_id && {:node_id, node_id}, params)
  end

  # Private helper to build path with query parameters
  defp build_path_with_params(base_path, node_or_tuple, additional_params) do
    all_params =
      case node_or_tuple do
        nil -> additional_params
        {key, value} when not is_nil(value) -> [{key, value} | additional_params]
        value when is_binary(value) -> [{:node, value} | additional_params]
        _ -> additional_params
      end

    if all_params == [] do
      base_path
    else
      query_string = URI.encode_query(all_params)
      "#{base_path}?#{query_string}"
    end
  end
end
