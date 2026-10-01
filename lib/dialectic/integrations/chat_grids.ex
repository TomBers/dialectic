defmodule Dialectic.Integrations.ChatGrids do
  import Ecto.Query

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Integrations.GridRequest
  alias Dialectic.Repo

  @kinds ~w(origin question answer thesis antithesis synthesis premise conclusion ideas clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if)

  def create(%User{} = user, params) do
    with {:ok, request_id} <- Ecto.UUID.cast(params["request_id"]),
         {:ok, draft} <- prepare(params) do
      payload_hash = :crypto.hash(:sha256, :erlang.term_to_binary(draft))

      Repo.transact(fn ->
        request = %GridRequest{
          user_id: user.id,
          request_id: request_id,
          payload_hash: payload_hash
        }

        inserted_request =
          Repo.insert!(request, on_conflict: :nothing, conflict_target: [:user_id, :request_id])

        stored_request = Repo.get_by!(GridRequest, user_id: user.id, request_id: request_id)

        cond do
          stored_request.payload_hash != payload_hash ->
            {:error, :request_conflict}

          stored_request.graph_title != nil ->
            case Repo.get(Graph, stored_request.graph_title) do
              %Graph{is_deleted: deleted} = graph when deleted != true -> {:ok, graph}
              _ -> {:error, :unavailable}
            end

          inserted_request.id != nil ->
            create_and_link(user, draft, stored_request)

          true ->
            {:error, :unavailable}
        end
      end)
    else
      :error -> {:error, "request_id must be a UUID"}
      error -> error
    end
  end

  def get(%User{id: user_id}, slug) do
    Repo.one(
      from graph in Graph,
        where: graph.slug == ^slug and graph.user_id == ^user_id,
        where: graph.is_deleted == false or is_nil(graph.is_deleted)
    )
  end

  def prepare(params) when is_map(params) do
    title = params["title"]
    nodes = params["nodes"]
    edges = params["edges"]
    tags = Map.get(params, "tags", [])

    cond do
      not text?(title, 140) ->
        {:error, "title must contain 1–140 characters"}

      not is_list(nodes) or length(nodes) not in 1..50 ->
        {:error, "Provide 1–50 idea nodes"}

      not Enum.all?(nodes, &valid_node?/1) ->
        {:error, "Each node needs an id, content, and supported kind"}

      not is_list(edges) or length(edges) > 150 ->
        {:error, "Provide at most 150 edges"}

      not is_list(tags) or length(tags) > 10 or not Enum.all?(tags, &text?(&1, 40)) ->
        {:error, "Provide at most 10 short tags"}

      byte_size(Jason.encode!(Map.take(params, ~w(title nodes edges tags)))) > 64_000 ->
        {:error, "Grid content must be at most 64KB"}

      true ->
        prepare_graph(title, nodes, edges, tags)
    end
  end

  def prepare(_params), do: {:error, "Provide a grid object"}

  defp prepare_graph(title, nodes, edges, tags) do
    ids = Enum.map(nodes, & &1["id"])
    roots = Enum.filter(nodes, &(&1["kind"] == "origin"))

    cond do
      length(Enum.uniq(ids)) != length(ids) ->
        {:error, "Node ids must be unique"}

      length(roots) != 1 ->
        {:error, "Provide exactly one origin node for the main question"}

      not Enum.all?(edges, &valid_edge?(&1, ids)) ->
        {:error, "Edges must connect two existing, distinct nodes"}

      length(Enum.uniq_by(edges, &{&1["from"], &1["to"]})) != length(edges) ->
        {:error, "Edges must be unique"}

      true ->
        [root] = roots
        ordered_nodes = [root | Enum.reject(nodes, &(&1["id"] == root["id"]))]

        id_map =
          ordered_nodes
          |> Enum.with_index(1)
          |> Map.new(fn {node, index} -> {node["id"], Integer.to_string(index)} end)

        data = %{
          "nodes" =>
            Enum.map(ordered_nodes, fn node ->
              %{
                "id" => id_map[node["id"]],
                "content" => String.trim(node["content"]),
                "class" => node["kind"],
                "user" => "",
                "parent" => nil,
                "noted_by" => [],
                "deleted" => false,
                "compound" => false
              }
            end),
          "edges" =>
            Enum.map(edges, fn edge ->
              source = id_map[edge["from"]]
              target = id_map[edge["to"]]

              %{
                "data" => %{"id" => "#{source}-#{target}", "source" => source, "target" => target}
              }
            end)
        }

        if connected_dag?(data) do
          {:ok,
           %{
             title: Graphs.sanitize_title(title),
             data: data,
             tags: Enum.map(tags, &String.trim/1)
           }}
        else
          {:error,
           "All nodes must be reachable from the origin, with no cycles or edges into the origin"}
        end
    end
  end

  defp connected_dag?(data) do
    graph = :digraph.new([:acyclic])

    try do
      Enum.each(data["nodes"], &:digraph.add_vertex(graph, &1["id"]))

      Enum.all?(data["edges"], fn %{"data" => edge} ->
        edge["target"] != "1" and
          not match?({:error, _}, :digraph.add_edge(graph, edge["source"], edge["target"]))
      end) and length(:digraph_utils.reachable(["1"], graph)) == length(data["nodes"])
    after
      :digraph.delete(graph)
    end
  end

  defp valid_node?(%{"id" => id, "content" => content, "kind" => kind}) do
    text?(id, 64) and text?(content, 4000) and kind in @kinds
  end

  defp valid_node?(_node), do: false

  defp valid_edge?(%{"from" => source, "to" => target}, ids),
    do: source in ids and target in ids and source != target

  defp valid_edge?(_edge, _ids), do: false

  defp text?(value, maximum) when is_binary(value),
    do: String.length(String.trim(value)) in 1..maximum

  defp text?(_value, _maximum), do: false

  defp create_and_link(user, draft, request) do
    with {:ok, graph} <- insert_graph(user, draft, draft.title, 3),
         {:ok, _request} <-
           request |> Ecto.Changeset.change(graph_title: graph.title) |> Repo.update() do
      {:ok, graph}
    end
  end

  defp insert_graph(_user, _draft, _title, 0), do: {:error, :title_conflict}

  defp insert_graph(user, draft, title, attempts) do
    changeset =
      %Graph{user_id: user.id}
      |> Graph.changeset(%{
        title: title,
        slug: Graphs.generate_unique_slug(title),
        data: draft.data,
        tags: draft.tags,
        is_public: false,
        is_published: true,
        is_locked: false,
        is_deleted: false,
        share_token: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
        prompt_mode: "university"
      })

    case Repo.insert(changeset, mode: :savepoint) do
      {:error, %Ecto.Changeset{errors: errors}} = error ->
        if Enum.any?(errors, fn {field, {_message, metadata}} ->
             field == :title and metadata[:constraint] == :unique
           end) do
          suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
          insert_graph(user, draft, "#{draft.title} (#{suffix})", attempts - 1)
        else
          error
        end

      result ->
        result
    end
  end
end
