defmodule Dialectic.Graph.Importer do
  @moduledoc """
  Imports graph JSON artifacts into the graphs table.
  """

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Repo

  @required_node_keys ~w(id content class user parent noted_by deleted compound)
  @max_file_size 10_000_000

  @type import_attrs :: %{
          required(:title) => String.t(),
          required(:data) => map(),
          optional(:slug) => String.t(),
          optional(:tags) => [String.t()],
          optional(:is_public) => boolean(),
          optional(:is_published) => boolean(),
          optional(:is_deleted) => boolean(),
          optional(:is_locked) => boolean(),
          optional(:prompt_mode) => String.t(),
          optional(:user_id) => integer() | nil
        }

  @doc """
  Imports a JSON file from disk.

  The file may either be a raw graph (`%{"nodes" => ..., "edges" => ...}`) or an
  artifact with `%{"metadata" => ..., "graph" => ...}`.
  """
  def import_file(path, opts \\ []) when is_binary(path) do
    with {:ok, json} <- read_file(path),
         {:ok, decoded} <- decode_json(json),
         {:ok, attrs} <- attrs_from_artifact(decoded, opts),
         :ok <- validate_data(attrs.data) do
      upsert(attrs)
    end
  end

  @doc """
  Imports an already decoded graph map using explicit attributes.
  """
  def import_data(data, attrs) when is_map(data) and is_map(attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put(:data, data)

    with {:ok, attrs} <- ensure_required_attrs(attrs),
         :ok <- validate_data(data) do
      upsert(attrs)
    end
  end

  def validate_data(%{"nodes" => nodes, "edges" => edges})
      when is_list(nodes) and is_list(edges) do
    with :ok <- validate_nodes(nodes),
         :ok <- validate_edges(edges, nodes) do
      :ok
    end
  end

  def validate_data(_), do: {:error, "Graph JSON must contain nodes and edges arrays."}

  defp read_file(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > @max_file_size ->
        {:error, "File is too large. Maximum graph JSON size is 10MB."}

      {:ok, _stat} ->
        File.read(path)

      {:error, reason} ->
        {:error, "Could not read file: #{:file.format_error(reason)}"}
    end
  end

  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, error} -> {:error, "Invalid JSON: #{Exception.message(error)}"}
    end
  end

  defp attrs_from_artifact(%{"metadata" => metadata, "graph" => graph}, opts)
       when is_map(metadata) and is_map(graph) do
    attrs =
      metadata
      |> atomize_known_metadata()
      |> Map.merge(Map.new(opts))
      |> normalize_attrs()
      |> Map.put(:data, graph)

    ensure_required_attrs(attrs)
  end

  defp attrs_from_artifact(%{"nodes" => _nodes, "edges" => _edges} = graph, opts) do
    attrs =
      opts
      |> Map.new()
      |> normalize_attrs()
      |> Map.put(:data, graph)

    ensure_required_attrs(attrs)
  end

  defp attrs_from_artifact(_artifact, _opts) do
    {:error, "JSON must be either a graph with nodes/edges or an artifact with metadata/graph."}
  end

  defp atomize_known_metadata(metadata) do
    allowed = %{
      "title" => :title,
      "slug" => :slug,
      "tags" => :tags,
      "is_public" => :is_public,
      "is_published" => :is_published,
      "is_deleted" => :is_deleted,
      "is_locked" => :is_locked,
      "prompt_mode" => :prompt_mode,
      "user_id" => :user_id
    }

    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      case allowed[key] do
        nil -> acc
        atom_key -> Map.put(acc, atom_key, value)
      end
    end)
  end

  defp normalize_attrs(attrs) do
    attrs
    |> normalize_title()
    |> normalize_slug()
    |> normalize_tags()
    |> Map.put_new(:is_public, false)
    |> Map.put_new(:is_published, false)
    |> Map.put_new(:is_deleted, false)
    |> Map.put_new(:is_locked, false)
    |> Map.put_new(:prompt_mode, "essay")
    |> Map.put_new(:user_id, nil)
  end

  defp normalize_title(%{title: title} = attrs) when is_binary(title) do
    Map.put(attrs, :title, Graphs.sanitize_title(title))
  end

  defp normalize_title(%{"title" => title} = attrs) when is_binary(title) do
    attrs
    |> Map.delete("title")
    |> Map.put(:title, Graphs.sanitize_title(title))
  end

  defp normalize_title(attrs), do: attrs

  defp normalize_slug(%{slug: slug} = attrs) when is_binary(slug) do
    Map.put(attrs, :slug, String.trim(slug))
  end

  defp normalize_slug(%{"slug" => slug} = attrs) when is_binary(slug) do
    attrs
    |> Map.delete("slug")
    |> Map.put(:slug, String.trim(slug))
  end

  defp normalize_slug(attrs), do: attrs

  defp normalize_tags(%{tags: tags} = attrs) when is_list(tags) do
    Map.put(attrs, :tags, clean_tags(tags))
  end

  defp normalize_tags(%{"tags" => tags} = attrs) when is_list(tags) do
    attrs
    |> Map.delete("tags")
    |> Map.put(:tags, clean_tags(tags))
  end

  defp normalize_tags(%{tags: tags} = attrs) when is_binary(tags) do
    Map.put(attrs, :tags, split_tags(tags))
  end

  defp normalize_tags(%{"tags" => tags} = attrs) when is_binary(tags) do
    attrs
    |> Map.delete("tags")
    |> Map.put(:tags, split_tags(tags))
  end

  defp normalize_tags(attrs), do: Map.put_new(attrs, :tags, [])

  defp split_tags(tags) do
    tags
    |> String.split(",")
    |> clean_tags()
  end

  defp clean_tags(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp ensure_required_attrs(%{title: title, data: data} = attrs)
       when is_binary(title) and title != "" and is_map(data) do
    attrs = Map.put_new_lazy(attrs, :slug, fn -> Graphs.generate_unique_slug(title) end)
    {:ok, attrs}
  end

  defp ensure_required_attrs(_attrs), do: {:error, "A graph title is required."}

  defp validate_nodes([]), do: {:error, "Graph must contain at least one node."}

  defp validate_nodes(nodes) do
    ids = Enum.map(nodes, & &1["id"])

    cond do
      Enum.any?(nodes, &(not is_map(&1))) ->
        {:error, "Every node must be an object."}

      Enum.any?(nodes, &(missing_keys(&1, @required_node_keys) != [])) ->
        {:error, "Every node must include #{Enum.join(@required_node_keys, ", ")}."}

      Enum.any?(ids, &(not is_binary(&1) or String.trim(&1) == "")) ->
        {:error, "Every node must have a non-empty string id."}

      length(ids) != length(Enum.uniq(ids)) ->
        {:error, "Node ids must be unique."}

      true ->
        :ok
    end
  end

  defp validate_edges(edges, nodes) do
    node_ids = nodes |> Enum.map(& &1["id"]) |> MapSet.new()

    invalid_edge? =
      Enum.find(edges, fn
        %{"data" => %{"source" => source, "target" => target}}
        when is_binary(source) and is_binary(target) ->
          not (MapSet.member?(node_ids, source) and MapSet.member?(node_ids, target))

        _ ->
          true
      end)

    if invalid_edge? do
      {:error, "Every edge must have data.source and data.target matching existing node ids."}
    else
      :ok
    end
  end

  defp missing_keys(map, keys) do
    Enum.reject(keys, &Map.has_key?(map, &1))
  end

  defp upsert(attrs) do
    case Repo.get(Graph, attrs.title) do
      nil ->
        attrs
        |> Map.put(:share_token, generate_share_token())
        |> insert_graph()

      %Graph{} = graph ->
        update_graph(graph, attrs)
    end
  end

  defp insert_graph(attrs) do
    %Graph{}
    |> Graph.changeset(attrs)
    |> Repo.insert()
  end

  defp update_graph(graph, attrs) do
    graph
    |> Graph.changeset(Map.drop(attrs, [:share_token]))
    |> Repo.update()
  end

  defp generate_share_token do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
