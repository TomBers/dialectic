defmodule DialecticWeb.GraphPathHelper do
  @moduledoc """
  Helper functions for generating graph URLs with slug support.

  These functions automatically use the slug when available for cleaner URLs,
  and fall back to title-based URLs for backward compatibility.
  """

  @doc """
  Generates a path to a graph, using slug if available, otherwise falling back to title.

  ## Examples

      # With a graph struct that has a slug
      graph_path(%{slug: "my-graph-abc123", title: "My Graph"})
      # => "/g/my-graph-abc123"

      # With a graph struct without a slug
      graph_path(%{title: "My Graph"})
      # => "/My%20Graph"

      # With a node parameter
      graph_path(%{slug: "my-graph-abc123"}, "5")
      # => "/g/my-graph-abc123?node=5"

      # With a linear path
      graph_linear_path(%{slug: "my-graph-abc123"})
      # => "/g/my-graph-abc123/linear"
  """
  def graph_path(graph, node \\ nil, params \\ [])

  def graph_path(%{slug: slug} = _graph, node, params) when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}"
    build_path_with_params(base_path, node, params)
  end

  def graph_path(%{title: title} = _graph, node, params) when is_binary(title) do
    base_path = "/#{URI.encode(title)}"
    build_path_with_params(base_path, node, params)
  end

  def graph_path(identifier, node, params) when is_binary(identifier) do
    # Fallback for string identifiers (backward compatibility)
    base_path = "/#{URI.encode(identifier)}"
    build_path_with_params(base_path, node, params)
  end

  @doc """
  Generates a path to the linear view of a graph.
  """
  def graph_linear_path(graph, node_id \\ nil, params \\ [])

  def graph_linear_path(%{slug: slug} = _graph, node_id, params)
      when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}/linear"
    build_path_with_params(base_path, node_id && {:node_id, node_id}, params)
  end

  def graph_linear_path(%{title: title} = _graph, node_id, params) when is_binary(title) do
    base_path = "/#{URI.encode(title)}/linear"
    build_path_with_params(base_path, node_id && {:node_id, node_id}, params)
  end

  def graph_linear_path(identifier, node_id, params) when is_binary(identifier) do
    base_path = "/#{URI.encode(identifier)}/linear"
    build_path_with_params(base_path, node_id && {:node_id, node_id}, params)
  end

  @doc """
  Generates a path to the story view of a graph node.
  """
  def graph_story_path(graph, node_id, params \\ [])

  def graph_story_path(%{slug: slug} = _graph, node_id, params)
      when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}/story/#{node_id}"
    build_path_with_params(base_path, nil, params)
  end

  def graph_story_path(%{title: title} = _graph, node_id, params) when is_binary(title) do
    base_path = "/#{URI.encode(title)}/story/#{node_id}"
    build_path_with_params(base_path, nil, params)
  end

  def graph_story_path(identifier, node_id, params) when is_binary(identifier) do
    base_path = "/#{URI.encode(identifier)}/story/#{node_id}"
    build_path_with_params(base_path, nil, params)
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
