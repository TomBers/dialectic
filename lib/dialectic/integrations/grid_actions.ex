defmodule Dialectic.Integrations.GridActions do
  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Graph.{Serialise, Vertex}
  alias Dialectic.Integrations.{ChatGrids, GridAction}
  alias Dialectic.Repo
  alias Dialectic.Responses.{LlmInterface, PromptsStructured}

  @actions Map.new(
             ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if)a,
             &{Atom.to_string(&1), &1}
           )

  def apply(user, slug, params) do
    if Map.has_key?(@actions, params["action"]) do
      submit(user, slug, Map.take(params, ~w(request_id node_id action)))
    else
      {:error, :invalid_action}
    end
  end

  def add_idea(user, slug, params) do
    content = params["content"]
    kind = Map.get(params, "kind", "comment")

    cond do
      kind not in ["comment", "question"] ->
        {:error, :invalid_kind}

      not is_binary(content) or String.trim(content) == "" or String.length(content) > 4000 ->
        {:error, :invalid_content}

      true ->
        submit(user, slug, %{
          "request_id" => params["request_id"],
          "node_id" => params["parent_node_id"],
          "action" => if(kind == "question", do: "ask_question", else: "add_idea"),
          "content" => content,
          "content_hash" => :crypto.hash(:sha256, content)
        })
    end
  end

  defp submit(user, slug, params) do
    with {:ok, request_id} <- Ecto.UUID.cast(params["request_id"]),
         true <- is_binary(params["node_id"]) and byte_size(params["node_id"]) in 1..255,
         %Graph{} = graph <- ChatGrids.get(user, slug) do
      GraphManager.apply_mcp_action(graph.title, user, Map.put(params, "request_id", request_id))
    else
      nil -> {:error, :not_found}
      _ -> {:error, :invalid_action}
    end
  end

  def apply_in_graph({graph_struct, graph} = state, user, params) do
    candidate = copy_graph(graph)

    try do
      result =
        Repo.transact(fn ->
          lock_request(user.id, params["request_id"])

          fresh =
            Repo.one(
              from stored in Graph,
                where: stored.title == ^graph_struct.title and stored.user_id == ^user.id,
                where: stored.is_deleted == false or is_nil(stored.is_deleted),
                lock: "FOR UPDATE"
            )

          request = Repo.get_by(GridAction, user_id: user.id, request_id: params["request_id"])

          cond do
            is_nil(fresh) -> {:error, :not_found}
            request != nil -> existing_result(request, fresh, candidate, params, graph_struct)
            fresh.is_locked == true or graph_struct.is_locked == true -> {:error, :locked}
            fresh.data_revision > graph_struct.data_revision -> {:error, :stale}
            true -> append(fresh, candidate, user, params, graph_struct.data_revision)
          end
        end)

      case result do
        {:ok, {response, updated}} ->
          for node <- [response.node, Map.get(response, :answer_node)], node != nil do
            if :digraph.vertex(graph, node.id) == false do
              {_, child} = :digraph.vertex(candidate, node.id)
              :digraph.add_vertex(graph, child.id, child)
              :digraph.add_edge(graph, node.parent_node_id, child.id)
            end
          end

          Phoenix.PubSub.broadcast(
            Dialectic.PubSub,
            "graph_update:#{updated.title}",
            {:other_user_change, self()}
          )

          {{:ok, response}, {updated, graph}}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    after
      :digraph.delete(candidate)
    end
  end

  defp existing_result(request, fresh, graph, params, graph_struct) do
    cond do
      request.graph_title != fresh.title or request.parent_node_id != params["node_id"] or
        request.action != params["action"] or request.content_hash != params["content_hash"] ->
        {:error, :request_conflict}

      true ->
        with {:ok, node} <- visible_node(graph, request.node_id),
             {:ok, answer} <- visible_node(graph, request.answer_node_id) do
          {:ok, {response(request, fresh, node, answer), graph_struct}}
        end
    end
  end

  defp append(fresh, graph, user, params, revision) do
    case :digraph.vertex(graph, params["node_id"]) do
      {_, %Vertex{deleted: false, compound: false, content: content} = parent}
      when is_binary(content) and content != "" ->
        mode = response_mode(fresh.prompt_mode)
        authored? = params["action"] in ["add_idea", "ask_question"]
        question? = params["action"] == "ask_question"

        child = %Vertex{
          id: next_id(graph, :digraph.no_vertices(graph) + 1),
          content: if(authored?, do: params["content"], else: ""),
          class:
            cond do
              question? -> "question"
              authored? -> "user"
              true -> params["action"]
            end,
          prompt_kind:
            cond do
              question? -> "question"
              authored? -> nil
              true -> params["action"]
            end,
          user: user.email,
          parent: parent.parent,
          response_level:
            if(authored?, do: nil, else: PromptsStructured.response_profile(mode).key)
        }

        :digraph.add_vertex(graph, child.id, child)
        :digraph.add_edge(graph, parent.id, child.id)
        answer = if question?, do: add_answer(graph, child, mode)
        source = if question?, do: child, else: parent
        data = Serialise.graph_to_json(graph)
        next_revision = max(System.system_time(:microsecond), revision + 1)

        with true <- byte_size(Jason.encode!(data)) <= 10_000_000,
             {:ok, job_id} <-
               queue_action(params["action"], source, answer || child, fresh, graph, mode),
             {:ok, :updated} <- Graphs.save_graph_if_newer(fresh.title, data, next_revision),
             {:ok, request} <-
               Repo.insert(%GridAction{
                 user_id: user.id,
                 request_id: params["request_id"],
                 graph_title: fresh.title,
                 parent_node_id: parent.id,
                 action: params["action"],
                 node_id: child.id,
                 answer_node_id: if(answer, do: answer.id),
                 job_id: job_id,
                 content_hash: params["content_hash"]
               }) do
          {:ok,
           {response(request, fresh, child, answer),
            %{fresh | data: data, data_revision: next_revision}}}
        else
          false -> {:error, :grid_too_large}
          error -> error
        end

      _ ->
        {:error, :invalid_node}
    end
  end

  defp queue_action("add_idea", _parent, _child, _fresh, _graph, _mode), do: {:ok, nil}

  defp queue_action(action, parent, child, fresh, graph, mode) do
    context = Vertex.build_context(parent, graph, 5000)

    result =
      if action == "ask_question" do
        LlmInterface.queue_grid_answer(parent, child, fresh.title, context, mode)
      else
        LlmInterface.queue_grid_action(
          Map.fetch!(@actions, action),
          parent,
          child,
          fresh.title,
          context,
          mode
        )
      end

    with {:ok, job} <- result do
      {:ok, job.id}
    end
  end

  defp add_answer(graph, question, mode) do
    answer = %Vertex{
      id: next_id(graph, :digraph.no_vertices(graph) + 1),
      class: "answer",
      prompt_kind: "answer",
      user: question.user,
      parent: question.parent,
      response_level: PromptsStructured.response_profile(mode).key
    }

    :digraph.add_vertex(graph, answer.id, answer)
    :digraph.add_edge(graph, question.id, answer.id)
    answer
  end

  defp visible_node(_graph, nil), do: {:ok, nil}

  defp visible_node(graph, id) do
    case :digraph.vertex(graph, id) do
      {_, %Vertex{deleted: false} = node} -> {:ok, node}
      _ -> {:error, :unavailable}
    end
  end

  defp response(request, graph, node, answer) do
    result = %{
      graph: graph,
      request_id: request.request_id,
      status: status(request),
      node: node_result(node, request.parent_node_id)
    }

    if answer, do: Map.put(result, :answer_node, node_result(answer, node.id)), else: result
  end

  defp node_result(node, parent_id),
    do: %{id: node.id, parent_node_id: parent_id, class: node.class, content: node.content}

  defp status(%GridAction{action: "add_idea"}), do: "completed"

  defp status(request) do
    case Repo.get(Oban.Job, request.job_id) do
      %{state: "completed"} -> "completed"
      %{state: "executing"} -> "generating"
      %{state: state} when state in ~w(available scheduled retryable) -> "queued"
      %{state: state} when state in ~w(cancelled discarded) -> "failed"
      _ -> "unknown"
    end
  end

  defp copy_graph(graph) do
    copy = :digraph.new()

    for id <- :digraph.vertices(graph) do
      {^id, node} = :digraph.vertex(graph, id)
      :digraph.add_vertex(copy, id, node)
    end

    for id <- :digraph.edges(graph) do
      {^id, source, target, label} = :digraph.edge(graph, id)
      :digraph.add_edge(copy, source, target, label)
    end

    copy
  end

  defp next_id(graph, number) do
    id = Integer.to_string(number)
    if :digraph.vertex(graph, id) == false, do: id, else: next_id(graph, number + 1)
  end

  defp response_mode("expert"), do: :expert
  defp response_mode(level) when level in ["simple", "high_school"], do: :high_school
  defp response_mode(_), do: :university

  defp lock_request(user_id, request_id) do
    <<key::signed-64, _rest::binary>> =
      :crypto.hash(:sha256, "mcp-action:#{user_id}:#{request_id}")

    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [key])
  end
end
