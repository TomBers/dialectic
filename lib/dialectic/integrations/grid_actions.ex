defmodule Dialectic.Integrations.GridActions do
  import Ecto.Query

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.{Graphs, Sharing}
  alias Dialectic.Graph.{Serialise, Vertex}
  alias Dialectic.Integrations.{GridAction, GridContent}
  alias Dialectic.Repo
  alias Dialectic.Responses.{LlmInterface, PromptsStructured}

  @actions Dialectic.Integrations.ExplorationTools.actions()

  def apply(user, slug, params) do
    if Map.has_key?(@actions, params["action"]) do
      with {:ok, focus} <- prepare_focus(params) do
        attrs = params |> Map.take(~w(request_id node_id action)) |> Map.merge(focus)
        submit(user, slug, attrs)
      end
    else
      {:error, :invalid_action}
    end
  end

  def get_operation(user, request_id) do
    with {:ok, request_id} <- Ecto.UUID.cast(request_id),
         %GridAction{graph_title: title} when is_binary(title) <-
           Repo.get_by(GridAction, user_id: user.id, request_id: request_id),
         %Graph{} <- accessible_graph(user, title) do
      GraphManager.get_mcp_operation(title, user, request_id)
    else
      _ -> {:error, :not_found}
    end
  end

  def get_operation_in_graph({graph_struct, graph}, user, request_id) do
    with %Graph{} = fresh <- accessible_graph(user, graph_struct.title),
         %GridAction{} = request <-
           Repo.get_by(GridAction,
             user_id: user.id,
             request_id: request_id,
             graph_title: fresh.title
           ),
         {:ok, node} <- visible_node(graph, request.node_id),
         {:ok, answer} <- visible_node(graph, request.answer_node_id) do
      result = response(request, fresh, node, answer, graph) |> persisted_result(request, fresh)
      {:ok, Dialectic.Integrations.Explorations.progress(result, request, graph)}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def read_content_in_graph({graph_struct, graph}, user) do
    case accessible_graph(user, graph_struct.title) do
      nil ->
        {:error, :not_found}

      fresh ->
        persisted = GridContent.serialize(fresh.data, fresh.title, fresh.data_revision)

        if fresh.data_revision > graph_struct.data_revision do
          {:ok, persisted, fresh.data_revision}
        else
          live = GridContent.serialize(Serialise.graph_to_json(graph), fresh.title)
          {:ok, live, if(live == persisted, do: fresh.data_revision, else: nil)}
        end
    end
  end

  defp persisted_result(result, %{completed_revision: nil}, _graph), do: result

  defp persisted_result(result, request, graph) do
    case GridContent.at_revision(graph, request.completed_revision) do
      {:ok, data, revision} ->
        nodes = GridContent.serialize(data, graph.title, revision).nodes

        result =
          result
          |> Map.put(:snapshot_revision, revision)
          |> Map.put(:node, Enum.find(nodes, &(&1.id == request.node_id)))

        if request.answer_node_id,
          do: Map.put(result, :answer_node, Enum.find(nodes, &(&1.id == request.answer_node_id))),
          else: result

      _ ->
        Map.put(result, :status, "unknown")
    end
  end

  defp accessible_graph(user, title) do
    graph = Graphs.get_graph_by_title(title)

    if graph && graph.is_deleted != true && Sharing.can_access?(user, graph), do: graph
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
        with {:ok, focus} <- prepare_focus(Map.delete(params, "action")) do
          attrs =
            Map.merge(focus, %{
              "request_id" => params["request_id"],
              "node_id" => params["parent_node_id"],
              "action" => if(kind == "question", do: "ask_question", else: "add_idea"),
              "content" => content,
              "content_hash" => request_hash(content, focus)
            })

          submit(user, slug, attrs)
        end
    end
  end

  defp prepare_focus(params) do
    selection = params["selection"]
    expected = params["expected_content_hash"]
    context_ids = Map.get(params, "context_node_ids", [])

    valid_hash? =
      is_nil(expected) or (is_binary(expected) and Regex.match?(~r/\A[0-9a-f]{64}\z/, expected))

    valid_selection? =
      is_nil(selection) or
        (is_binary(selection) and String.trim(selection) != "" and
           String.length(selection) <= 4000 and not is_nil(expected))

    valid_context? =
      is_list(context_ids) and length(context_ids) <= 4 and
        Enum.all?(context_ids, &(is_binary(&1) and byte_size(&1) in 1..255)) and
        Enum.uniq(context_ids) == context_ids

    cond do
      not valid_hash? or not valid_selection? ->
        {:error, :invalid_selection}

      not valid_context? ->
        {:error, :invalid_context}

      params["action"] == "synthesis" and
          (selection != nil or context_ids == [] or params["node_id"] in context_ids) ->
        {:error, :invalid_context}

      params["action"] != "synthesis" and context_ids != [] ->
        {:error, :invalid_context}

      true ->
        focus = %{
          "selection" => selection,
          "expected_content_hash" => expected,
          "context_node_ids" => context_ids
        }

        {:ok, Map.put(focus, "content_hash", request_hash(nil, focus))}
    end
  end

  defp request_hash(content, focus) do
    if is_nil(focus["selection"]) and is_nil(focus["expected_content_hash"]) and
         focus["context_node_ids"] == [],
       do: if(is_binary(content), do: :crypto.hash(:sha256, content)),
       else:
         :crypto.hash(
           :sha256,
           :erlang.term_to_binary(
             {content, focus["selection"], focus["expected_content_hash"],
              focus["context_node_ids"]}
           )
         )
  end

  def continue_exploration(user, slug, %{"action" => action} = params)
      when action in ["exploration_testing", "exploration_deepening", "exploration_synthesizing"] do
    submit(user, slug, params)
  end

  defp submit(user, slug, params) do
    with {:ok, request_id} <- Ecto.UUID.cast(params["request_id"]),
         true <- is_binary(params["node_id"]) and byte_size(params["node_id"]) in 1..255,
         %Graph{} = graph <- Sharing.get_accessible_graph(user, slug) do
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
                where: stored.title == ^graph_struct.title,
                where: stored.is_deleted == false or is_nil(stored.is_deleted),
                lock: "FOR UPDATE"
            )

          request = Repo.get_by(GridAction, user_id: user.id, request_id: params["request_id"])

          cond do
            is_nil(fresh) ->
              {:error, :not_found}

            not Sharing.can_access?(user, fresh) ->
              {:error, :not_found}

            params["private_owner_only"] == true and
                (fresh.user_id != user.id or fresh.is_public == true) ->
              {:error, :not_found}

            request != nil ->
              existing_result(request, fresh, candidate, params, graph_struct)

            fresh.is_locked == true or graph_struct.is_locked == true ->
              {:error, :locked}

            fresh.data_revision > graph_struct.data_revision ->
              {:error, :stale}

            true ->
              with :ok <- validate_focus(candidate, params, fresh.title) do
                append(fresh, candidate, user, params, graph_struct.data_revision)
              end
          end
        end)

      case result do
        {:ok, {response, updated}} ->
          for node <- [response.node, Map.get(response, :answer_node)], node != nil do
            if :digraph.vertex(graph, node.id) == false do
              {_, child} = :digraph.vertex(candidate, node.id)
              :digraph.add_vertex(graph, child.id, child)

              for parent_id <- :digraph.in_neighbours(candidate, child.id) do
                :digraph.add_edge(graph, parent_id, child.id)
              end
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

  defp validate_focus(graph, params, title) do
    case :digraph.vertex(graph, params["node_id"]) do
      {_, %Vertex{deleted: false, compound: false, content: content} = source}
      when is_binary(content) and content != "" ->
        cond do
          params["expected_content_hash"] &&
              GridContent.content_hash(content) != params["expected_content_hash"] ->
            {:error, :source_changed}

          params["selection"] && not String.contains?(content, params["selection"]) ->
            {:error, :selection_not_found}

          not Enum.all?(Map.get(params, "context_node_ids", []), &usable_node?(graph, &1)) ->
            {:error, :invalid_context}

          params["action"] != "add_idea" and not learning_target_current?(source, graph) ->
            {:error, :source_changed}

          params["action"] != "add_idea" and generation_pending?(title, params) ->
            {:error, :generation_in_progress}

          true ->
            :ok
        end

      _ ->
        {:error, :invalid_node}
    end
  end

  defp learning_target_current?(%Vertex{class: "learning_plan", guided_plan: plan}, graph) do
    case Dialectic.Responses.GuidedLearningPlan.normalize(plan) do
      {:ok, plan} ->
        Enum.all?(plan.actions, fn action ->
          case Map.get(action, :target) do
            nil ->
              true

            target ->
              match?(
                {:ok, _},
                Dialectic.Responses.GuidedLearningTarget.resolve(target, fn id ->
                  case :digraph.vertex(graph, id) do
                    {_, node} -> node
                    _ -> nil
                  end
                end)
              )
          end
        end)

      _ ->
        true
    end
  end

  defp learning_target_current?(_source, _graph), do: true

  defp usable_node?(graph, id) do
    case :digraph.vertex(graph, id) do
      {_, %Vertex{deleted: false, compound: false, content: content}} ->
        is_binary(content) and String.trim(content) != ""

      _ ->
        false
    end
  end

  defp generation_pending?(title, params) do
    ids = [params["node_id"] | Map.get(params, "context_node_ids", [])]
    pending = Dialectic.Responses.RequestQueue.pending_node_ids(title)

    Enum.any?(ids, &MapSet.member?(pending, &1)) or
      Repo.exists?(
        from operation in GridAction,
          where:
            (is_nil(operation.answer_node_id) and operation.node_id in ^ids) or
              operation.answer_node_id in ^ids,
          where: operation.status in ["queued", "generating"],
          where: operation.graph_title == ^title
      )
  end

  defp existing_result(request, fresh, graph, params, graph_struct) do
    cond do
      request.graph_title != fresh.title or request.parent_node_id != params["node_id"] or
        request.action != params["action"] or request.content_hash != params["content_hash"] ->
        {:error, :request_conflict}

      true ->
        with {:ok, node} <- visible_node(graph, request.node_id),
             {:ok, answer} <- visible_node(graph, request.answer_node_id) do
          result =
            response(request, fresh, node, answer, graph) |> persisted_result(request, fresh)

          {:ok, {result, graph_struct}}
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
              params["action"] == "related_ideas" -> "ideas"
              params["action"] == "exploration_synthesizing" -> "synthesis"
              String.starts_with?(params["action"], "exploration_") -> "answer"
              true -> params["action"]
            end,
          prompt_kind:
            cond do
              question? -> "question"
              authored? -> nil
              true -> params["action"]
            end,
          user: user.email,
          source_text: params["selection"],
          source_reference:
            if(params["selection"],
              do: %{
                "node_id" => parent.id,
                "content_hash" => GridContent.content_hash(parent.content)
              }
            ),
          parent: parent.parent,
          response_level:
            if(authored?, do: nil, else: PromptsStructured.response_profile(mode).key)
        }

        :digraph.add_vertex(graph, child.id, child)
        :digraph.add_edge(graph, parent.id, child.id)

        for id <- Map.get(params, "context_node_ids", []),
            do: :digraph.add_edge(graph, id, child.id)

        answer = if question?, do: add_answer(graph, child, mode)
        source = if question?, do: child, else: parent
        data = Serialise.graph_to_json(graph)
        next_revision = max(System.system_time(:microsecond), revision + 1)

        with true <- byte_size(Jason.encode!(data)) <= 10_000_000,
             {:ok, job_id} <-
               queue_action(params, source, answer || child, fresh, graph, mode),
             {:ok, :updated} <- Graphs.save_graph_if_newer(fresh.title, data, next_revision),
             :ok <- snapshot_authored(fresh.title, data, next_revision, job_id),
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
                 status: if(is_nil(job_id), do: "completed", else: "queued"),
                 completed_revision: if(is_nil(job_id), do: next_revision),
                 content_hash: params["content_hash"]
               }) do
          {:ok,
           {response(request, fresh, child, answer, graph),
            %{fresh | data: data, data_revision: next_revision}}}
        else
          false -> {:error, :grid_too_large}
          error -> error
        end

      _ ->
        {:error, :invalid_node}
    end
  end

  defp snapshot_authored(title, data, revision, nil) do
    Repo.insert!(%Dialectic.Integrations.GridSnapshot{
      graph_title: title,
      data: data,
      revision: revision
    })

    :ok
  end

  defp snapshot_authored(_title, _data, _revision, _job), do: :ok

  defp queue_action(%{"action" => "add_idea"}, _parent, _child, _fresh, _graph, _mode),
    do: {:ok, nil}

  defp queue_action(%{"action" => action} = params, parent, child, fresh, graph, mode) do
    context =
      if String.starts_with?(action, "exploration_") do
        [parent.id | Map.get(params, "context_node_ids", [])]
        |> Enum.map(fn id ->
          {_, node} = :digraph.vertex(graph, id)
          sources = Dialectic.LLM.Grounding.sources(node.grounding_metadata)

          Vertex.build_context(node, graph, 16000) <>
            "\n" <>
            node.content <>
            "\nProvider-reported sources for this node (not independent corroboration): " <>
            Jason.encode!(sources)
        end)
        |> Enum.join("\n\n")
      else
        Vertex.build_context(parent, graph, 5000)
      end

    result =
      cond do
        String.starts_with?(action, "exploration_") ->
          LlmInterface.queue_exploration_step(action, child, fresh.title, context, mode)

        action == "ask_question" ->
          LlmInterface.queue_grid_answer(parent, child, fresh.title, context, mode)

        true ->
          LlmInterface.queue_grid_action(
            Map.fetch!(@actions, action),
            parent,
            child,
            fresh.title,
            context,
            mode,
            selection: params["selection"],
            context_nodes:
              Enum.map(Map.get(params, "context_node_ids", []), fn id ->
                {_, node} = :digraph.vertex(graph, id)
                node
              end),
            learning_target:
              if(action == "learning_plan",
                do: learning_target(parent, graph, params["selection"])
              )
          )
      end

    with {:ok, job} <- result do
      {:ok, job.id}
    end
  end

  defp learning_target(parent, graph, nil) do
    Dialectic.Responses.GuidedLearningTarget.select(Vertex.add_relatives(parent, graph), fn id ->
      case :digraph.vertex(graph, id) do
        {_, node} -> Vertex.add_relatives(node, graph)
        _ -> nil
      end
    end)
  end

  defp learning_target(parent, _graph, selection) do
    %{
      node_id: parent.id,
      title: "Selected passage",
      content: selection,
      source_hash: GridContent.content_hash(parent.content)
    }
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

  defp response(request, graph, node, answer, digraph) do
    result = %{
      graph: graph,
      request_id: request.request_id,
      status: request.status,
      node:
        node_result(
          node,
          Enum.sort(:digraph.in_neighbours(digraph, node.id)),
          if(answer, do: nil, else: request.status)
        )
    }

    result =
      if request.completed_revision,
        do: Map.put(result, :snapshot_revision, request.completed_revision),
        else: result

    if answer,
      do:
        Map.put(
          result,
          :answer_node,
          node_result(
            answer,
            Enum.sort(:digraph.in_neighbours(digraph, answer.id)),
            request.status
          )
        ),
      else: result
  end

  defp node_result(node, parents, status), do: GridContent.node(node, parents, status)

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

  def lock_request(user_id, request_id) do
    <<key::signed-64, _rest::binary>> =
      :crypto.hash(:sha256, "mcp-action:#{user_id}:#{request_id}")

    Ecto.Adapters.SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [key])
  end
end
