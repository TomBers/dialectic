defmodule DialecticWeb.OutlineGraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.GraphActions
  alias Dialectic.Highlights
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
                "Error loading reader view for #{graph_id}: #{Exception.format(:error, e, __STACKTRACE__)}"
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
    previous_node_id = socket.assigns.selected_node_id

    socket =
      socket
      |> assign_selected_node(selected_node)
      |> maybe_scroll_to_top(previous_node_id, selected_node)
      |> push_highlights()

    {:noreply, socket}
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
  def handle_info({:created, highlight}, socket) do
    highlight = Dialectic.Repo.preload(highlight, :links)
    highlights = [highlight | socket.assigns.highlights]

    {:noreply,
     socket
     |> assign(highlights: highlights)
     |> push_highlights()}
  end

  @impl true
  def handle_info({:updated, highlight}, socket) do
    highlight = Dialectic.Repo.preload(highlight, :links)

    highlights =
      Enum.map(socket.assigns.highlights, fn current_highlight ->
        if current_highlight.id == highlight.id, do: highlight, else: current_highlight
      end)

    {:noreply,
     socket
     |> assign(highlights: highlights)
     |> push_highlights()}
  end

  @impl true
  def handle_info({:deleted, highlight}, socket) do
    highlights =
      Enum.reject(socket.assigns.highlights, fn current_highlight ->
        current_highlight.id == highlight.id
      end)

    {:noreply,
     socket
     |> assign(highlights: highlights)
     |> push_highlights()}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("navigate_to_node", %{"node_id" => node_id}, socket) do
    {:noreply, navigate_to_node(socket, node_id)}
  end

  @impl true
  def handle_event("node_clicked", %{"id" => node_id}, socket) do
    {:noreply, navigate_to_node(socket, node_id)}
  end

  defp mount_graph(socket, graph_db, token_param) do
    {_graph_struct, graph} = GraphManager.get_graph(graph_db.title)

    graph_topic = "graph_update:#{graph_db.title}"
    highlights = Highlights.list_highlights_with_links(mudg_id: graph_db.title)
    base_url = DialecticWeb.Endpoint.url()
    canonical = canonical_graph_url(graph_db)
    description = reader_description(graph_db)

    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "name" => graph_db.title,
        "headline" => graph_db.title,
        "description" => description,
        "url" => canonical,
        "image" => base_url <> ~p"/images/graph_live.webp",
        "dateModified" => DateTime.to_iso8601(graph_db.updated_at),
        "datePublished" => DateTime.to_iso8601(graph_db.inserted_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "RationalGrid",
          "url" => base_url
        },
        "keywords" => graph_db.tags || [],
        "isAccessibleForFree" => true
      })

    if connected?(socket) do
      PubSub.subscribe(Dialectic.PubSub, graph_topic)
      Highlights.subscribe(graph_db.title)
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
      selected_node_id: nil,
      node: nil,
      selected_path: [],
      displayed_node_ids: MapSet.new(),
      reading_chain: [],
      reading_terminal: nil,
      next_choices: [],
      compare_context: nil,
      compare_branches: [],
      highlights: highlights,
      page_title: graph_db.title,
      page_description: description,
      canonical_url: canonical,
      og_type: "article",
      og_image: base_url <> ~p"/images/graph_live.webp",
      json_ld: json_ld,
      noindex: !indexable_graph?(graph_db)
    )
  end

  defp canonical_graph_url(%{slug: slug}) when is_binary(slug) and slug != "" do
    DialecticWeb.Endpoint.url() <> "/g/#{slug}"
  end

  defp canonical_graph_url(graph) do
    DialecticWeb.Endpoint.url() <> "/g/#{URI.encode(graph.title)}"
  end

  defp reader_description(graph_db) do
    "Explore \"#{graph_db.title}\" on RationalGrid. Read the main thread in order and follow nearby branches when the argument splits."
  end

  defp indexable_graph?(graph_db) do
    graph_db.is_public == true and graph_db.is_published == true and graph_db.is_deleted != true
  end

  defp refresh_outline(socket) do
    {_graph_struct, graph} = GraphManager.get_graph(socket.assigns.graph_id)
    outline_nodes = build_outline_nodes(socket.assigns.graph_id, graph)

    selected_node =
      current_selected_node(socket.assigns.graph_id, socket.assigns.selected_node_id) ||
        default_target_node(socket.assigns.graph_id)

    socket
    |> assign(outline_nodes: outline_nodes)
    |> assign_selected_node(selected_node)
  end

  defp assign_selected_node(socket, nil) do
    assign(socket,
      selected_node_id: nil,
      node: nil,
      selected_path: [],
      displayed_node_ids: MapSet.new(),
      reading_chain: [],
      reading_terminal: nil,
      next_choices: [],
      compare_context: nil,
      compare_branches: []
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

    reading_chain = build_reading_chain(socket.assigns.graph_id, selected_node)
    reading_terminal = List.last(reading_chain)
    next_choices = build_next_choices(socket.assigns.graph_id, reading_terminal)

    {compare_context, compare_branches} =
      build_compare_state(socket.assigns.graph_id, selected_node, selected_path)

    displayed_node_ids =
      selected_path
      |> Enum.map(& &1.id)
      |> Kernel.++(Enum.map(reading_chain, & &1.id))
      |> MapSet.new()

    assign(socket,
      selected_node_id: selected_node.id,
      node: selected_node,
      selected_path: selected_path,
      displayed_node_ids: displayed_node_ids,
      reading_chain: reading_chain,
      reading_terminal: reading_terminal,
      next_choices: next_choices,
      compare_context: compare_context,
      compare_branches: compare_branches
    )
  end

  defp maybe_scroll_to_top(socket, nil, _selected_node), do: socket
  defp maybe_scroll_to_top(socket, _previous_node_id, nil), do: socket

  defp maybe_scroll_to_top(socket, previous_node_id, selected_node) do
    if previous_node_id != selected_node.id do
      push_event(socket, "scroll_to_top", %{})
    else
      socket
    end
  end

  defp push_highlights(socket) do
    push_event(socket, "highlights_loaded", %{
      highlights: serialize_highlights(socket.assigns.highlights || [])
    })
  end

  defp resolve_target_node(graph_id, %{"node_id" => node_id})
       when is_binary(node_id) and node_id != "" do
    current_selected_node(graph_id, node_id) || default_target_node(graph_id)
  end

  defp resolve_target_node(graph_id, %{"node" => node_id})
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
    node = GraphManager.best_node(graph_id, nil)

    if visible_node?(node) do
      node
    else
      first_visible_node(graph_id)
    end
  end

  defp first_visible_node(graph_id) do
    {_graph_struct, graph} = GraphManager.get_graph(graph_id)

    graph
    |> ThreadedConv.prepare_conversation()
    |> Enum.find(&visible_node?/1)
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
        branch?: length(children) > 1
      }
    end)
  end

  defp build_reading_chain(_graph_id, nil), do: []

  defp build_reading_chain(graph_id, selected_node) do
    graph_id
    |> do_build_reading_chain(selected_node, MapSet.new())
    |> Enum.map(&enrich_node/1)
  end

  defp do_build_reading_chain(_graph_id, nil, _visited), do: []

  defp do_build_reading_chain(graph_id, node, visited) do
    if MapSet.member?(visited, node.id) do
      [node]
    else
      visited = MapSet.put(visited, node.id)

      case list_non_deleted_children(graph_id, node.id) do
        [child] ->
          [node | do_build_reading_chain(graph_id, child, visited)]

        _ ->
          [node]
      end
    end
  end

  defp build_next_choices(_graph_id, nil), do: []

  defp build_next_choices(graph_id, node) do
    children = list_non_deleted_children(graph_id, node.id)

    if length(children) > 1 do
      Enum.map(children, fn child ->
        segment = deepest_branch_segment(graph_id, child)
        leaf = List.last(segment) || child

        %{
          id: child.id,
          title: display_title(child),
          class: Map.get(child, :class, "default"),
          content_preview: preview_node_content(child, 140),
          leaf_title:
            if leaf.id != child.id do
              display_title(leaf)
            end
        }
      end)
    else
      []
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
          |> Enum.map(fn child ->
            segment = deepest_branch_segment(graph_id, child)
            enriched_segment = Enum.map(segment, &enrich_node/1)
            lead = List.first(enriched_segment)
            leaf = List.last(enriched_segment)

            %{
              id: child.id,
              lead: lead,
              leaf: leaf,
              active?: branch_active?(selected_node, branch_root, enriched_segment)
            }
          end)
          |> Enum.reject(&is_nil(&1.lead))

        if length(compare_branches) > 1 do
          compare_context = %{
            root: enrich_node(branch_root)
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

  defp deepest_branch_segment(graph_id, node) do
    deepest_branch_segment(graph_id, node, MapSet.new())
  end

  defp deepest_branch_segment(_graph_id, nil, _visited), do: []

  defp deepest_branch_segment(graph_id, node, visited) do
    if MapSet.member?(visited, node.id) do
      [node]
    else
      visited = MapSet.put(visited, node.id)

      children =
        graph_id
        |> list_non_deleted_children(node.id)
        |> Enum.reject(&MapSet.member?(visited, &1.id))

      case children do
        [] ->
          [node]

        _ ->
          best_segment =
            children
            |> Enum.map(fn child ->
              segment = deepest_branch_segment(graph_id, child, visited)
              leaf = List.last(segment) || child
              {length(segment), sort_key(leaf.id), segment}
            end)
            |> Enum.max_by(fn {depth, leaf_key, _segment} -> {depth, leaf_key} end)
            |> elem(2)

          [node | best_segment]
      end
    end
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
    |> Map.put(:full_title, display_title(node, max_length: :infinity))
    |> Map.put(:body_content, node_body_content(node))
    |> Map.put(:class, Map.get(node, :class, "default"))
  end

  defp visible_node?(nil), do: false
  defp visible_node?(%{deleted: true}), do: false
  defp visible_node?(%{compound: true}), do: false
  defp visible_node?(%{}), do: true
  defp visible_node?(_), do: false

  defp display_title(node, opts \\ []) do
    node
    |> NodeTitleHelper.extract_node_title(opts)
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
    |> sanitize_preview_text()
    |> case do
      "" -> "No content yet."
      cleaned -> String.slice(cleaned, 0, limit)
    end
  end

  defp preview_node_content(node, limit) do
    cleaned_content = sanitize_preview_text(Map.get(node, :content, ""))

    cleaned_body_content =
      node
      |> Map.get(:body_content, node_body_content(node))
      |> sanitize_preview_text()

    title = node |> display_title(max_length: :infinity) |> sanitize_preview_text()

    cleaned_body_content
    |> case do
      "" ->
        cleaned_content
        |> String.replace_prefix(title, "")
        |> String.trim()
        |> String.trim_leading(":.- ")

      body_content ->
        body_content
    end
    |> case do
      "" -> preview_content(cleaned_content, limit)
      deduped -> String.slice(deduped, 0, limit)
    end
  end

  defp node_body_content(node) do
    node
    |> then(fn current_node ->
      Map.get(current_node, :content) || Map.get(current_node, "content") || ""
    end)
    |> extract_body_content()
  end

  defp extract_body_content(content) do
    normalized_content =
      content
      |> to_string()
      |> String.replace(~r/\r\n|\r/, "\n")

    rest =
      normalized_content
      |> String.split("\n")
      |> Enum.drop(1)
      |> Enum.join("\n")
      |> String.trim_leading()

    case String.split(rest, "\n") do
      [first_line | remaining_lines] ->
        if String.match?(first_line, ~r/^\s*\#{1,6}\s+\S/) or
             String.match?(first_line, ~r/^\s*(title|Title)\s*:?\s*/) do
          Enum.join(remaining_lines, "\n")
        else
          rest
        end

      [] ->
        rest
    end
    |> String.trim()
  end

  defp sanitize_preview_text(content) do
    content
    |> to_string()
    |> String.replace(~r/[#*_`~\[\]\(\)>!\-]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_count, _singular, plural), do: plural

  defp serialize_highlights(highlights) do
    Enum.map(highlights, fn highlight ->
      %{
        id: highlight.id,
        node_id: highlight.node_id,
        selection_start: highlight.selection_start,
        selection_end: highlight.selection_end,
        selected_text_snapshot: highlight.selected_text_snapshot,
        links:
          Enum.map(highlight.links || [], fn link ->
            %{node_id: link.node_id, link_type: link.link_type}
          end)
      }
    end)
  end

  defp reading_flow_message(reading_chain, next_choices) do
    cond do
      length(reading_chain) > 1 and next_choices != [] ->
        "Showing this thread until the next split."

      length(reading_chain) > 1 ->
        "Showing the rest of this thread all the way to its current endpoint."

      next_choices != [] ->
        "This point splits into multiple paths."

      true ->
        "This path ends here."
    end
  end

  defp next_choices_message(reading_terminal, selected_node) do
    if reading_terminal.id == selected_node.id do
      "This point splits the conversation. Pick the direction you want to read next."
    else
      "The thread above leads to another split here. Pick the direction you want to read next."
    end
  end

  defp navigate_to_node(socket, node_id) do
    case current_selected_node(socket.assigns.graph_id, node_id) do
      nil ->
        put_flash(socket, :error, "Node not found")

      node ->
        push_patch(
          socket,
          to: graph_path(socket.assigns.graph_struct, node.id, socket.assigns.nav_params)
        )
    end
  end

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
