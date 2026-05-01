defmodule DialecticWeb.OutlineGraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.GraphActions
  alias Dialectic.Linear.ThreadedConv
  alias DialecticWeb.ColUtils
  alias DialecticWeb.Utils.NodeTitleHelper
  alias Phoenix.PubSub

  require Logger

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(%{"graph_name" => graph_id_uri} = params, _session, socket) do
    graph_id = URI.decode(graph_id_uri)

    case Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Graph not found: #{graph_id}")
          |> redirect(to: ~p"/")

        {:ok, socket}

      graph_db ->
        token_param = Map.get(params, "token")

        has_access =
          Dialectic.DbActions.Sharing.can_access?(socket.assigns[:current_user], graph_db) or
            (is_binary(token_param) and is_binary(graph_db.share_token) and
               Plug.Crypto.secure_compare(token_param, graph_db.share_token))

        if has_access do
          try do
            {:ok, mount_graph(socket, graph_db, token_param)}
          rescue
            e ->
              Logger.error(
                "Error loading outline view for #{graph_id}: #{Exception.format(:error, e, __STACKTRACE__)}"
              )

              socket =
                socket
                |> put_flash(:error, "Error loading graph: #{graph_id}")
                |> redirect(to: ~p"/")

              {:ok, socket}
          end
        else
          socket =
            socket
            |> put_flash(:error, "You do not have permission to view this graph.")
            |> redirect(to: ~p"/")

          {:ok, socket}
        end
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_node = resolve_target_node(socket.assigns.graph_id, params)

    {:noreply, assign_selected_node(socket, selected_node)}
  end

  @impl true
  def handle_info({:other_user_change, sender_pid}, socket) do
    if self() == sender_pid do
      {:noreply, socket}
    else
      {:noreply, refresh_outline(socket)}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp mount_graph(socket, graph_db, token_param) do
    {_graph_struct, graph} = GraphManager.get_graph(graph_db.title)

    graph_topic = "graph_update:#{graph_db.title}"

    if connected?(socket) do
      PubSub.subscribe(Dialectic.PubSub, graph_topic)
    end

    outline_nodes = build_outline_nodes(graph_db.title, graph)

    assign(socket,
      graph_id: graph_db.title,
      graph_struct: graph_db,
      graph_topic: graph_topic,
      token: token_param,
      nav_params: token_params(token_param),
      can_edit: !graph_db.is_locked,
      outline_nodes: outline_nodes,
      outline_stats: summarize_outline(outline_nodes),
      selected_node_id: nil,
      node: nil,
      selected_path: [],
      selected_path_ids: MapSet.new(),
      child_summaries: [],
      sibling_summaries: [],
      compare_context: nil,
      compare_branches: [],
      current_depth: 0,
      page_title: "#{graph_db.title} — Outline View",
      page_description:
        "Browse \"#{graph_db.title}\" as an outline. Follow the main thread, inspect sibling branches, and move through the conversation without the canvas.",
      canonical_url: DialecticWeb.Endpoint.url() <> "/g/#{graph_db.slug}",
      noindex: true
    )
  end

  defp refresh_outline(socket) do
    {_graph_struct, graph} = GraphManager.get_graph(socket.assigns.graph_id)
    outline_nodes = build_outline_nodes(socket.assigns.graph_id, graph)

    selected_node =
      current_selected_node(socket.assigns.graph_id, socket.assigns.selected_node_id) ||
        default_target_node(socket.assigns.graph_id)

    socket
    |> assign(
      outline_nodes: outline_nodes,
      outline_stats: summarize_outline(outline_nodes)
    )
    |> assign_selected_node(selected_node)
  end

  defp assign_selected_node(socket, nil) do
    assign(socket,
      selected_node_id: nil,
      node: nil,
      selected_path: [],
      selected_path_ids: MapSet.new(),
      child_summaries: [],
      sibling_summaries: [],
      compare_context: nil,
      compare_branches: [],
      current_depth: 0
    )
  end

  defp assign_selected_node(socket, selected_node) do
    selected_node = enrich_node(selected_node)

    selected_path =
      socket.assigns.graph_id
      |> GraphManager.path_to_node(selected_node)
      |> Enum.reverse()
      |> Enum.filter(&visible_node?/1)
      |> Enum.map(&enrich_node/1)

    {compare_context, compare_branches} =
      build_compare_state(socket.assigns.graph_id, selected_node, selected_path)

    assign(socket,
      selected_node_id: selected_node.id,
      node: selected_node,
      selected_path: selected_path,
      selected_path_ids: MapSet.new(Enum.map(selected_path, & &1.id)),
      child_summaries: get_child_summaries(socket.assigns.graph_id, selected_node.id),
      sibling_summaries: get_sibling_summaries(socket.assigns.graph_id, selected_node.id),
      compare_context: compare_context,
      compare_branches: compare_branches,
      current_depth: max(length(selected_path) - 1, 0)
    )
  end

  defp resolve_target_node(graph_id, %{"node_id" => node_id})
       when is_binary(node_id) and node_id != "" do
    current_selected_node(graph_id, node_id) || default_target_node(graph_id)
  end

  defp resolve_target_node(graph_id, _params), do: default_target_node(graph_id)

  defp current_selected_node(_graph_id, nil), do: nil

  defp current_selected_node(graph_id, node_id) do
    node = GraphActions.find_node(graph_id, node_id)

    if visible_node?(node), do: node, else: nil
  end

  defp default_target_node(graph_id) do
    graph_id
    |> GraphManager.find_leaf_nodes()
    |> Enum.filter(&visible_node?/1)
    |> Enum.sort_by(&sort_key(&1.id), :desc)
    |> List.first()
    |> case do
      nil ->
        node = GraphManager.best_node(graph_id, nil)

        if visible_node?(node), do: node, else: nil

      node ->
        node
    end
  end

  defp build_outline_nodes(graph_id, graph) do
    graph
    |> ThreadedConv.prepare_conversation()
    |> Enum.filter(&visible_node?/1)
    |> Enum.map(fn node ->
      children = list_non_deleted_children(graph_id, node.id)

      %{
        id: node.id,
        indent: Map.get(node, :indent, 0),
        title: display_title(node),
        class: Map.get(node, :class, "default"),
        preview: preview_content(Map.get(node, :content, ""), 96),
        child_count: length(children),
        branch?: length(children) > 1
      }
    end)
  end

  defp summarize_outline(outline_nodes) do
    %{
      total: length(outline_nodes),
      branch_points: Enum.count(outline_nodes, & &1.branch?),
      leaves: Enum.count(outline_nodes, &(&1.child_count == 0)),
      max_depth: Enum.max(Enum.map(outline_nodes, & &1.indent), fn -> 0 end)
    }
  end

  defp get_child_summaries(graph_id, node_id) do
    graph_id
    |> list_non_deleted_children(node_id)
    |> Enum.map(fn node ->
      %{
        id: node.id,
        title: display_title(node),
        class: Map.get(node, :class, "default"),
        content_preview: preview_content(Map.get(node, :content, ""), 140),
        child_count: length(list_non_deleted_children(graph_id, node.id))
      }
    end)
  end

  defp get_sibling_summaries(graph_id, node_id) do
    case GraphManager.in_neighbours(graph_id, node_id) |> List.first() do
      nil ->
        []

      parent_id ->
        graph_id
        |> list_non_deleted_children(parent_id)
        |> Enum.map(fn node ->
          %{
            id: node.id,
            title: display_title(node),
            class: Map.get(node, :class, "default"),
            content_preview: preview_content(Map.get(node, :content, ""), 120)
          }
        end)
    end
  end

  defp build_compare_state(graph_id, selected_node, selected_path) do
    case nearest_branch_root(graph_id, selected_path) do
      nil ->
        {nil, []}

      branch_root ->
        compare_branches =
          graph_id
          |> list_non_deleted_children(branch_root.id)
          |> Enum.with_index()
          |> Enum.map(fn {child, index} ->
            representative_leaf = deepest_visible_descendant(graph_id, child)
            segment = branch_segment(graph_id, branch_root.id, representative_leaf)
            enriched_segment = Enum.map(segment, &enrich_node/1)
            lead = List.first(enriched_segment)
            leaf = List.last(enriched_segment)

            %{
              id: child.id,
              label: branch_option_label(index),
              lead: lead,
              leaf: leaf,
              step_count: max(length(enriched_segment), 1),
              active?: branch_active?(selected_node, branch_root, enriched_segment),
              leaf_preview: preview_content(Map.get(leaf || %{}, :content, ""), 180)
            }
          end)

        if length(compare_branches) > 1 do
          compare_context = %{
            root: enrich_node(branch_root),
            branch_count: length(compare_branches),
            active_branch_id:
              Enum.find_value(compare_branches, fn branch ->
                if branch.active?, do: branch.id, else: nil
              end)
          }

          {compare_context, compare_branches}
        else
          {nil, []}
        end
    end
  end

  defp nearest_branch_root(graph_id, selected_path) do
    selected_path
    |> Enum.reverse()
    |> Enum.find(fn node ->
      length(list_non_deleted_children(graph_id, node.id)) > 1
    end)
  end

  defp deepest_visible_descendant(graph_id, node) do
    {_depth, leaf} = deepest_visible_descendant_with_depth(graph_id, node)
    leaf
  end

  defp deepest_visible_descendant_with_depth(graph_id, node) do
    case list_non_deleted_children(graph_id, node.id) do
      [] ->
        {0, node}

      children ->
        children
        |> Enum.map(fn child ->
          {depth, leaf} = deepest_visible_descendant_with_depth(graph_id, child)
          {depth + 1, leaf}
        end)
        |> Enum.max_by(fn {depth, leaf} -> {depth, sort_key(leaf.id)} end)
    end
  end

  defp branch_segment(graph_id, branch_root_id, leaf_node) do
    graph_id
    |> GraphManager.path_to_node(leaf_node)
    |> Enum.reverse()
    |> Enum.filter(&visible_node?/1)
    |> Enum.drop_while(&(&1.id != branch_root_id))
    |> Enum.drop(1)
  end

  defp branch_active?(selected_node, branch_root, enriched_segment) do
    selected_node.id != branch_root.id and
      Enum.any?(enriched_segment, fn node -> node.id == selected_node.id end)
  end

  defp list_non_deleted_children(graph_id, node_id) do
    graph_id
    |> GraphManager.out_neighbours(node_id)
    |> Enum.map(&GraphActions.find_node(graph_id, &1))
    |> Enum.filter(&visible_node?/1)
    |> Enum.sort_by(&sort_key(&1.id))
  end

  defp enrich_node(node) do
    node
    |> Map.put(:title, display_title(node))
    |> Map.put(:class, Map.get(node, :class, "default"))
  end

  defp visible_node?(nil), do: false
  defp visible_node?(%{deleted: true}), do: false
  defp visible_node?(%{compound: true}), do: false
  defp visible_node?(%{}), do: true
  defp visible_node?(_), do: false

  defp display_title(node) do
    node
    |> NodeTitleHelper.extract_node_title()
    |> case do
      nil ->
        fallback_title(node)

      title ->
        if String.trim(title) == "" do
          fallback_title(node)
        else
          title
        end
    end
  end

  defp fallback_title(node) do
    "Untitled " <> String.downcase(ColUtils.node_type_label(Map.get(node, :class, "default")))
  end

  defp preview_content(content, limit) do
    content
    |> to_string()
    |> String.replace(~r/[#*_`~\[\]\(\)>!\-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> "No content yet."
      cleaned -> String.slice(cleaned, 0, limit)
    end
  end

  defp compact_type_label("origin"), do: "Origin"
  defp compact_type_label("question"), do: "Question"
  defp compact_type_label("user"), do: "Comment"
  defp compact_type_label("answer"), do: "Answer"
  defp compact_type_label("thesis"), do: "Pro"
  defp compact_type_label("antithesis"), do: "Con"
  defp compact_type_label("synthesis"), do: "Synthesis"
  defp compact_type_label("ideas"), do: "Ideas"
  defp compact_type_label("deepdive"), do: "Deep Dive"
  defp compact_type_label(other), do: other |> to_string() |> String.capitalize()

  defp branch_option_label(index) when index >= 0 and index < 26 do
    "Option " <> <<?A + index>>
  end

  defp branch_option_label(index), do: "Option #{index + 1}"

  defp compare_grid_class(count) when count <= 1, do: "grid-cols-1"
  defp compare_grid_class(2), do: "grid-cols-1 xl:grid-cols-2"
  defp compare_grid_class(_count), do: "grid-cols-1 xl:grid-cols-2 2xl:grid-cols-3"

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_count, _singular, plural), do: plural

  defp outline_indent_style(indent) do
    "padding-left: #{0.75 + indent * 1.1}rem;"
  end

  defp sort_key(id) do
    case Integer.parse(to_string(id)) do
      {int, _rest} -> {0, int}
      :error -> {1, to_string(id)}
    end
  end

  defp token_params(token) when is_binary(token) and token != "", do: [token: token]
  defp token_params(_token), do: []
end
