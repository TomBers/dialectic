defmodule DialecticWeb.GraphPathHelper do
  @moduledoc """
  Helper functions for generating graph URLs using slug-based routes.

  All graphs should have slugs generated automatically.
  """

  @doc """
  Generates a path to a graph using its slug.

  For private graphs with a share_token, the token is automatically
  included as a query parameter so the link grants access.

  ## Examples

      # With a graph struct
      graph_path(%{slug: "my-graph-abc123", is_public: true})
      # => "/g/my-graph-abc123"

      # With a node parameter
      graph_path(%{slug: "my-graph-abc123", is_public: true}, "5")
      # => "/g/my-graph-abc123?node=5"

      # Private graph with share token
      graph_path(%{slug: "my-graph-abc123", is_public: false, share_token: "abc"})
      # => "/g/my-graph-abc123?token=abc"
  """
  def graph_path(graph, node \\ nil, params \\ [])

  def graph_path(%{slug: slug} = graph, node, params) when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}"
    params = maybe_add_token(graph, params)
    build_path_with_params(base_path, node, params)
  end

  @doc """
  Generates a path to the linear view of a graph.

  For private graphs with a share_token, the token is automatically
  included as a query parameter so the link grants access.

  ## Examples

      graph_linear_path(%{slug: "my-graph-abc123", is_public: true})
      # => "/g/my-graph-abc123/linear"

      # Private graph with share token
      graph_linear_path(%{slug: "my-graph-abc123", is_public: false, share_token: "abc"})
      # => "/g/my-graph-abc123/linear?token=abc"
  """
  def graph_linear_path(graph, node_id \\ nil, params \\ [])

  def graph_linear_path(%{slug: slug} = graph, node_id, params)
      when not is_nil(slug) and slug != "" do
    base_path = "/g/#{slug}/linear"
    params = maybe_add_token(graph, params)
    build_path_with_params(base_path, node_id && {:node_id, node_id}, params)
  end

  # Appends the share_token as a "token" query param for private graphs
  defp maybe_add_token(%{is_public: false, share_token: token}, params)
       when is_binary(token) and token != "" do
    [{"token", token} | params]
  end

  defp maybe_add_token(_graph, params), do: params

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
