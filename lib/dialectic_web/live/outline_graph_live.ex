defmodule DialecticWeb.OutlineGraphLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts.User
  alias Dialectic.DbActions.Notes
  alias Dialectic.Graph.GraphActions
  alias Dialectic.Follows
  alias Dialectic.Highlights
  alias Dialectic.Linear.ThreadedConv
  alias DialecticWeb.ColUtils
  alias DialecticWeb.GraphHelpers
  alias DialecticWeb.HighlightShare
  alias DialecticWeb.NodeSearch
  alias DialecticWeb.Utils.NodeTitleHelper
  alias DialecticWeb.Utils.UserUtils
  alias Phoenix.PubSub

  require Logger

  @max_outline_indent 4

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
    path_endpoint = current_selected_node(socket.assigns.graph_id, params["path"])

    selected_node =
      if params["node"] do
        resolve_target_node(socket.assigns.graph_id, params)
      else
        path_endpoint || resolve_target_node(socket.assigns.graph_id, params)
      end

    previous_node_id = socket.assigns.selected_node_id

    highlight_id = Map.get(params, "highlight")

    share_highlight =
      HighlightShare.highlight_for_graph(socket.assigns.graph_struct, highlight_id)

    requested_path_ids =
      if path_endpoint do
        socket.assigns.graph_id
        |> build_selected_path(path_endpoint)
        |> Enum.map(& &1.id)
      else
        []
      end

    path_focus_ids =
      if selected_node && selected_node.id in requested_path_ids,
        do: requested_path_ids,
        else: []

    socket =
      socket
      |> assign(:path_focus_ids, path_focus_ids)
      |> assign_selected_node(selected_node)
      |> maybe_scroll_to_reader_node(previous_node_id, selected_node)
      |> push_highlights()
      |> maybe_scroll_to_highlight(highlight_id)
      |> assign_share_metadata(share_highlight)

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
  def handle_info(:close_share_modal, socket) do
    {:noreply, assign(socket, show_share_modal: false, selected_share_highlight: nil)}
  end

  @impl true
  def handle_info({:selection_action, params}, socket) do
    case GraphHelpers.check_selection_action_allowed(socket) do
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "This graph is locked")}

      {:error, :unauthenticated} ->
        {:noreply, assign(socket, show_login_modal: true)}

      :ok ->
        {action, selected_text, node_id, offsets, existing_highlight, _extra} =
          GraphHelpers.unpack_selection_action(params)

        handle_reader_selection_action(
          action,
          selected_text,
          node_id,
          offsets,
          existing_highlight,
          socket
        )
    end
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

  @impl true
  def handle_event("reader_node_viewed", %{"id" => node_id}, socket) do
    reading_node =
      Enum.find(socket.assigns.visible_reading_chain, fn node -> node.id == node_id end)

    if reading_node do
      selected_path = build_selected_path(socket.assigns.graph_id, reading_node)
      selected_path_ids = MapSet.new(Enum.map(selected_path, & &1.id))

      focused_outline_nodes =
        build_chapter_outline_nodes(socket.assigns.outline_nodes, selected_path)

      can_choose_path? =
        can_choose_path?(
          socket.assigns.outline_nodes,
          focused_outline_nodes,
          reading_node.id
        )

      {:noreply,
       assign(socket,
         selected_node_id: node_id,
         share_node: reading_node,
         selected_path: selected_path,
         selected_path_ids: selected_path_ids,
         selected_focus_outline_nodes: focused_outline_nodes,
         can_choose_path?: can_choose_path?
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("choose_path", _params, socket) do
    if socket.assigns.can_choose_path? do
      params = Keyword.put(socket.assigns.nav_params, :path, socket.assigns.selected_node_id)

      {:noreply,
       push_patch(socket,
         to: graph_path(socket.assigns.graph_struct, socket.assigns.selected_node_id, params)
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_all_paths", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         graph_path(
           socket.assigns.graph_struct,
           socket.assigns.selected_node_id,
           socket.assigns.nav_params
         )
     )}
  end

  @impl true
  def handle_event("note", %{"node" => node_id}, socket) do
    update_reader_bookmark(socket, node_id, :note)
  end

  @impl true
  def handle_event("unnote", %{"node" => node_id}, socket) do
    update_reader_bookmark(socket, node_id, :unnote)
  end

  @impl true
  def handle_event("highlight_clicked", %{"id" => highlight_id} = params, socket) do
    node_id = params["node-id"] || params["node_id"]

    socket =
      if is_binary(node_id) and MapSet.member?(socket.assigns.highlight_node_ids, node_id) do
        push_event(socket, "scroll_to_highlight", %{id: highlight_id})
      else
        push_patch(socket, to: highlight_path(socket, node_id, highlight_id))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_node_highlights", %{"node-id" => node_id}, socket) do
    open_node_id = if socket.assigns.node_highlights_open == node_id, do: nil, else: node_id
    {:noreply, assign(socket, node_highlights_open: open_node_id)}
  end

  @impl true
  def handle_event("show_login_required", _params, socket) do
    {:noreply, assign(socket, show_login_modal: true)}
  end

  @impl true
  def handle_event("close_login_modal", _params, socket) do
    {:noreply, assign(socket, show_login_modal: false)}
  end

  @impl true
  def handle_event("open_share_modal", params, socket) do
    share_highlight =
      socket.assigns.graph_struct
      |> HighlightShare.highlight_for_graph(Map.get(params, "highlight_id"))

    {:noreply, assign(socket, show_share_modal: true, selected_share_highlight: share_highlight)}
  end

  @impl true
  def handle_event("search_nodes", params, socket) do
    search_term =
      (params["search_term"] || params["value"] || "")
      |> to_string()
      |> String.trim()

    {:noreply,
     socket
     |> assign(search_term: search_term)
     |> assign(search_results: search_reader_nodes(socket.assigns.graph_id, search_term))}
  end

  @impl true
  def handle_event("open_search_overlay_click", _params, socket) do
    {:noreply, assign(socket, show_search_overlay: true)}
  end

  @impl true
  def handle_event("open_search_overlay", params, socket) do
    meta = params["metaKey"] in [true, "true"]
    cmd = params["cmdKey"] in [true, "true"]
    editable = params["isEditable"] in [true, "true"]

    if (meta || cmd) && !editable do
      {:noreply, assign(socket, show_search_overlay: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_search_overlay", _params, socket) do
    {:noreply, clear_reader_search(socket)}
  end

  @impl true
  def handle_event("search_result_clicked", %{"id" => node_id}, socket) do
    socket =
      socket
      |> clear_reader_search()
      |> then(fn current_socket ->
        if current_socket.assigns.selected_node_id == node_id,
          do: current_socket,
          else: navigate_to_node(current_socket, node_id)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_presentation", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("close_presentation_setup", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("close_combine_setup", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("follow_graph", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:noreply, assign(socket, show_login_modal: true)}

      user ->
        case Follows.follow_graph(user, socket.assigns.graph_struct) do
          {:ok, _follow} ->
            {:noreply,
             socket
             |> assign(:following_graph?, true)
             |> put_flash(:info, "Grid followed.")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Could not follow this grid.")}
        end
    end
  end

  @impl true
  def handle_event("unfollow_graph", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:noreply, assign(socket, show_login_modal: true)}

      user ->
        {:ok, _count} = Follows.unfollow_graph(user, socket.assigns.graph_struct)

        {:noreply,
         socket
         |> assign(:following_graph?, false)
         |> put_flash(:info, "Grid unfollowed.")}
    end
  end

  defp mount_graph(socket, graph_db, token_param) do
    {_graph_struct, graph} = GraphManager.get_graph(graph_db.title)

    graph_topic = "graph_update:#{graph_db.title}"
    highlights = Highlights.list_highlights_with_links(mudg_id: graph_db.title)
    base_url = DialecticWeb.Endpoint.url()
    canonical = canonical_graph_url(graph_db)
    description = reader_description(graph_db, graph)

    json_ld =
      Jason.encode!(%{
        "@context" => "https://schema.org",
        "@type" => "Article",
        "name" => graph_db.title,
        "headline" => graph_db.title,
        "description" => description,
        "url" => canonical,
        "mainEntityOfPage" => %{"@type" => "WebPage", "@id" => canonical},
        "image" => base_url <> ~p"/images/graph_live.webp",
        "dateModified" => DateTime.to_iso8601(graph_db.updated_at),
        "datePublished" => DateTime.to_iso8601(graph_db.inserted_at),
        "publisher" => %{
          "@type" => "Organization",
          "name" => "RationalGrid",
          "url" => base_url
        },
        "keywords" => graph_db.tags || [],
        "inLanguage" => "en",
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
      user: UserUtils.current_identity(socket.assigns),
      bookmarked_node_ids:
        graph_db.title
        |> Notes.list_noted_node_ids(socket.assigns[:current_user])
        |> MapSet.new(),
      appearance_preferences: User.appearance_preferences(socket.assigns[:current_user]),
      token: token_param,
      nav_params: token_params(token_param),
      can_edit: !graph_db.is_locked,
      outline_nodes: outline_nodes,
      visible_outline_nodes: outline_nodes,
      selected_focus_outline_nodes: outline_nodes,
      path_focus_ids: [],
      paths_filtered?: false,
      can_choose_path?: false,
      selected_node_id: nil,
      node: nil,
      share_node: nil,
      selected_path: [],
      node_highlights_open: nil,
      highlight_node_ids: MapSet.new(),
      reading_chain: [],
      visible_reading_chain: [],
      reading_terminal: nil,
      next_choices: [],
      compare_context: nil,
      compare_branches: [],
      show_share_modal: false,
      selected_share_highlight: nil,
      show_login_modal: false,
      show_search_overlay: false,
      search_term: "",
      search_results: [],
      following_graph?: following_graph?(socket.assigns[:current_user], graph_db),
      highlights: highlights,
      page_title: graph_db.title,
      page_description: description,
      default_page_description: description,
      canonical_url: canonical,
      og_type: "article",
      og_image: base_url <> ~p"/images/graph_live.webp",
      json_ld: json_ld,
      noindex: !indexable_graph?(graph_db)
    )
  end

  defp update_reader_bookmark(socket, node_id, action) do
    case GraphHelpers.handle_note(socket, node_id, action) do
      {:noreply, updated_socket} ->
        {:noreply, updated_socket}

      {:ok, _graph_result, _operation} ->
        GraphManager.save_graph(socket.assigns.graph_id)

        bookmarked_node_ids =
          case action do
            :note -> MapSet.put(socket.assigns.bookmarked_node_ids, node_id)
            :unnote -> MapSet.delete(socket.assigns.bookmarked_node_ids, node_id)
          end

        {:noreply, assign(socket, :bookmarked_node_ids, bookmarked_node_ids)}
    end
  end

  defp canonical_graph_url(%{slug: slug}) when is_binary(slug) and slug != "" do
    DialecticWeb.Endpoint.url() <> "/g/#{slug}"
  end

  defp canonical_graph_url(graph) do
    DialecticWeb.Endpoint.url() <> "/g/#{URI.encode(graph.title)}"
  end

  defp reader_description(graph_db, graph) do
    summary =
      graph
      |> ThreadedConv.prepare_conversation()
      |> Enum.filter(&visible_node?/1)
      |> Enum.find_value(fn node ->
        body = node |> node_body_content() |> sanitize_preview_text()
        if String.length(body) >= 40, do: body
      end)

    case summary do
      nil ->
        "Explore \"#{graph_db.title}\" on RationalGrid. Follow the main thread and compare its branches."

      body ->
        truncate_description("#{graph_db.title}: #{body}", 160)
    end
  end

  defp assign_share_metadata(socket, %{id: _id} = highlight) do
    graph = socket.assigns.graph_struct

    assign(socket,
      page_title: HighlightShare.page_title(graph, highlight),
      page_description: HighlightShare.page_description(graph, highlight),
      canonical_url: HighlightShare.share_url(graph, highlight),
      og_image: HighlightShare.image_url(graph, highlight),
      noindex: true
    )
  end

  defp assign_share_metadata(socket, _highlight) do
    graph = socket.assigns.graph_struct
    canonical = canonical_graph_url(graph)
    description = socket.assigns.default_page_description
    base_url = DialecticWeb.Endpoint.url()

    assign(socket,
      page_title: graph.title,
      page_description: description,
      canonical_url: canonical,
      og_image: base_url <> ~p"/images/graph_live.webp",
      noindex: !indexable_graph?(graph)
    )
  end

  defp indexable_graph?(graph_db) do
    graph_db.is_public == true and graph_db.is_published == true and graph_db.is_deleted != true
  end

  defp following_graph?(%Dialectic.Accounts.User{} = user, graph) do
    Follows.following_graph?(user, graph)
  end

  defp following_graph?(_user, _graph), do: false

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
      share_node: nil,
      selected_path: [],
      selected_path_ids: MapSet.new(),
      highlight_node_ids: MapSet.new(),
      reading_chain: [],
      visible_reading_chain: [],
      reading_terminal: nil,
      next_choices: [],
      compare_context: nil,
      compare_branches: [],
      visible_outline_nodes: socket.assigns.outline_nodes,
      selected_focus_outline_nodes: socket.assigns.outline_nodes,
      path_focus_ids: [],
      paths_filtered?: false,
      can_choose_path?: false
    )
  end

  defp assign_selected_node(socket, selected_node) do
    selected_node = enrich_node(selected_node)

    selected_path = build_selected_path(socket.assigns.graph_id, selected_node)

    continuation = build_reading_chain(socket.assigns.graph_id, selected_node)

    reading_chain =
      selected_path
      |> Enum.drop(-1)
      |> Kernel.++(continuation)
      |> Enum.uniq_by(& &1.id)

    reading_terminal = List.last(reading_chain)
    next_choices = build_next_choices(socket.assigns.graph_id, reading_terminal)

    {compare_context, compare_branches} =
      build_compare_state(socket.assigns.graph_id, selected_node, selected_path)

    selected_path_ids = MapSet.new(Enum.map(selected_path, & &1.id))

    focused_outline_nodes =
      build_chapter_outline_nodes(socket.assigns.outline_nodes, selected_path)

    can_choose_path? =
      can_choose_path?(
        socket.assigns.outline_nodes,
        focused_outline_nodes,
        selected_node.id
      )

    active_focus_outline_nodes =
      outline_rows_for_ids(socket.assigns.outline_nodes, socket.assigns.path_focus_ids)

    paths_filtered? =
      socket.assigns.path_focus_ids != [] and
        Enum.map(active_focus_outline_nodes, & &1.id) !=
          Enum.map(socket.assigns.outline_nodes, & &1.id)

    visible_outline_nodes =
      if paths_filtered?, do: active_focus_outline_nodes, else: socket.assigns.outline_nodes

    visible_reading_chain =
      if paths_filtered? do
        reader_nodes_for_ids(socket.assigns.graph_id, socket.assigns.path_focus_ids)
      else
        reading_chain
      end

    highlight_node_ids =
      visible_reading_chain
      |> Enum.filter(&highlight_container_mounted?/1)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    assign(socket,
      selected_node_id: selected_node.id,
      node: selected_node,
      share_node: selected_node,
      selected_path: selected_path,
      selected_path_ids: selected_path_ids,
      highlight_node_ids: highlight_node_ids,
      reading_chain: reading_chain,
      visible_reading_chain: visible_reading_chain,
      reading_terminal: reading_terminal,
      next_choices: next_choices,
      compare_context: compare_context,
      compare_branches: compare_branches,
      visible_outline_nodes: visible_outline_nodes,
      selected_focus_outline_nodes: focused_outline_nodes,
      paths_filtered?: paths_filtered?,
      can_choose_path?: can_choose_path?
    )
  end

  defp can_choose_path?(outline_nodes, focused_outline_nodes, selected_node_id) do
    focused_path? =
      Enum.map(focused_outline_nodes, & &1.id) != Enum.map(outline_nodes, & &1.id)

    terminal_node? =
      case List.last(outline_nodes) do
        nil -> false
        node -> node.id == selected_node_id
      end

    focused_path? or terminal_node?
  end

  defp maybe_scroll_to_reader_node(socket, nil, _selected_node), do: socket
  defp maybe_scroll_to_reader_node(socket, _previous_node_id, nil), do: socket

  defp maybe_scroll_to_reader_node(socket, previous_node_id, selected_node) do
    if previous_node_id != selected_node.id do
      push_event(socket, "scroll_to_reader_node", %{id: selected_node.id})
    else
      socket
    end
  end

  defp push_highlights(socket) do
    push_event(socket, "highlights_loaded", %{
      highlights: serialize_highlights(socket.assigns.highlights || [])
    })
  end

  defp clear_reader_search(socket) do
    assign(socket, show_search_overlay: false, search_term: "", search_results: [])
  end

  defp search_reader_nodes(_graph_id, ""), do: []

  defp search_reader_nodes(graph_id, search_term) do
    try do
      graph_id
      |> GraphManager.vertices()
      |> Enum.reduce([], fn vertex_id, acc ->
        case GraphManager.vertex_label(graph_id, vertex_id) do
          %{} = node ->
            if visible_node?(node) do
              case node |> enrich_node() |> NodeSearch.annotate_result(search_term) do
                %{search_rank: rank} = enriched_node ->
                  [{rank, sort_key(enriched_node.id), enriched_node} | acc]

                nil ->
                  acc
              end
            else
              acc
            end

          _ ->
            acc
        end
      end)
      |> Enum.sort_by(fn {rank, sort_id, _node} -> {rank, sort_id} end)
      |> Enum.map(fn {_rank, _sort_id, node} -> node end)
      |> Enum.take(10)
    rescue
      _ -> []
    catch
      :exit, _reason -> []
    end
  end

  defp maybe_scroll_to_highlight(socket, highlight_id)
       when is_binary(highlight_id) and highlight_id != "" do
    push_event(socket, "scroll_to_highlight", %{id: highlight_id})
  end

  defp maybe_scroll_to_highlight(socket, _highlight_id), do: socket

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
        full_title: display_title(node, max_length: :infinity),
        class: Map.get(node, :class, "default"),
        response_level: Map.get(node, :response_level),
        branch?: length(children) > 1
      }
    end)
  end

  defp build_selected_path(graph_id, selected_node) do
    graph_id
    |> GraphManager.path_to_node(selected_node)
    |> Enum.reverse()
    |> Enum.filter(&visible_node?/1)
    |> Enum.map(&enrich_node/1)
  end

  defp reader_nodes_for_ids(graph_id, ids) do
    ids
    |> Enum.map(&GraphActions.find_node(graph_id, &1))
    |> Enum.filter(&visible_node?/1)
    |> Enum.map(&enrich_node/1)
  end

  defp build_chapter_outline_nodes(outline_nodes, selected_path) do
    outline_rows_for_ids(outline_nodes, Enum.map(selected_path, & &1.id))
  end

  defp outline_rows_for_ids(outline_nodes, ids) do
    rows_by_id = Map.new(outline_nodes, &{&1.id, &1})

    ids
    |> Enum.reduce({[], MapSet.new()}, fn id, {rows, seen} ->
      cond do
        MapSet.member?(seen, id) ->
          {rows, seen}

        row = Map.get(rows_by_id, id) ->
          chapter = row |> Map.put(:indent, 0) |> Map.put(:branch?, false)
          {rows ++ [chapter], MapSet.put(seen, id)}

        true ->
          {rows, seen}
      end
    end)
    |> elem(0)
  end

  defp build_reading_chain(graph_id, selected_node) do
    graph_id
    |> do_build_reading_chain(selected_node, MapSet.new())
    |> Enum.map(&enrich_node/1)
  end

  defp highlight_container_mounted?(node) do
    String.trim(Map.get(node, :body_content, "") || "") != ""
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
        %{
          id: child.id,
          title: display_title(child, max_length: :infinity),
          class: Map.get(child, :class, "default")
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

            %{
              id: child.id,
              lead: lead,
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

    [title_line | body_lines] = String.split(normalized_content, "\n")

    rest =
      body_lines
      |> Enum.join("\n")
      |> String.trim_leading()

    case String.split(rest, "\n") do
      [first_line | remaining_lines] ->
        duplicate_heading? =
          String.match?(first_line, ~r/^\s*\#{1,6}\s+\S/) and
            normalized_title_line(first_line) == normalized_title_line(title_line)

        if duplicate_heading? or String.match?(first_line, ~r/^\s*title\b\s*:?\s*/i) do
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

  defp truncate_description(text, limit) do
    if String.length(text) <= limit do
      text
    else
      text
      |> String.slice(0, limit + 1)
      |> String.split()
      |> Enum.drop(-1)
      |> Enum.join(" ")
      |> Kernel.<>("…")
    end
  end

  defp normalized_title_line(line) do
    line
    |> String.replace(~r/^\s*\#{1,6}\s*/, "")
    |> String.replace(~r/^\s*title\s*:?\s*/i, "")
    |> String.trim()
    |> String.downcase()
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

  defp next_choices_message(reading_terminal, selected_node) do
    if reading_terminal.id == selected_node.id do
      "This point splits the conversation. Pick the direction you want to read next."
    else
      "The thread above leads to another split here. Pick the direction you want to read next."
    end
  end

  defp handle_reader_selection_action(
         :highlight_only,
         selected_text,
         node_id,
         offsets,
         existing_highlight,
         socket
       ) do
    if existing_highlight do
      {:noreply, socket}
    else
      attrs = %{
        mudg_id: socket.assigns.graph_id,
        node_id: node_id,
        text_source_type: "node",
        selection_start: selection_offset(offsets, :start),
        selection_end: selection_offset(offsets, :end),
        selected_text_snapshot: selected_text,
        created_by_user_id: socket.assigns.current_user.id
      }

      case Highlights.create_highlight(attrs) do
        {:ok, _highlight} ->
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not save highlight")}
      end
    end
  end

  defp handle_reader_selection_action(
         _action,
         _selected_text,
         _node_id,
         _offsets,
         _highlight,
         socket
       ) do
    {:noreply, put_flash(socket, :error, "Reader view supports highlights only")}
  end

  defp selection_offset(offsets, key) do
    Map.get(offsets, key) || Map.get(offsets, Atom.to_string(key))
  end

  defp navigate_to_node(socket, node_id) do
    case current_selected_node(socket.assigns.graph_id, node_id) do
      nil ->
        put_flash(socket, :error, "Node not found")

      node ->
        push_patch(
          socket,
          to:
            graph_path(
              socket.assigns.graph_struct,
              node.id,
              reader_nav_params(socket.assigns.nav_params, socket.assigns.path_focus_ids)
            )
        )
    end
  end

  defp highlight_path(socket, node_id, highlight_id) do
    graph_path(
      socket.assigns.graph_struct,
      node_id,
      socket.assigns.nav_params
      |> reader_nav_params(socket.assigns.path_focus_ids)
      |> Keyword.put(:highlight, highlight_id)
    )
  end

  defp response_level_label("simple"), do: "Simple"
  defp response_level_label("high_school"), do: "Simple"
  defp response_level_label("university"), do: "Expanded"
  defp response_level_label("expert"), do: "In-depth"
  defp response_level_label(_response_level), do: nil

  defp response_level_badge_class("simple"), do: "bg-sky-50 text-sky-700 ring-sky-600/15"
  defp response_level_badge_class("high_school"), do: "bg-sky-50 text-sky-700 ring-sky-600/15"

  defp response_level_badge_class("university"),
    do: "bg-indigo-50 text-indigo-700 ring-indigo-600/15"

  defp response_level_badge_class("expert"),
    do: "bg-amber-50 text-amber-800 ring-amber-600/20"

  defp response_level_badge_class(_response_level),
    do: "bg-slate-100 text-slate-700 ring-slate-600/10"

  defp outline_indent_style(indent, step \\ 0.45) do
    visible_indent = min(max(indent, 0), @max_outline_indent)
    "padding-left: #{0.75 + visible_indent * step}rem;"
  end

  defp outline_indent_guides(indent) do
    visible_indent = min(max(indent, 0), @max_outline_indent)
    List.duplicate(:guide, visible_indent)
  end

  defp sort_key(id) do
    case Integer.parse(to_string(id)) do
      {int, _rest} -> {0, int}
      :error -> {1, to_string(id)}
    end
  end

  defp challenge_action_label(%{class: "answer"}), do: "Challenge this answer"
  defp challenge_action_label(%{class: "question"}), do: "Challenge this question"
  defp challenge_action_label(%{class: "user"}), do: "Challenge this comment"

  defp challenge_action_label(%{class: class}) do
    label =
      class
      |> ColUtils.node_type_label()
      |> String.split("/", parts: 2)
      |> List.first()
      |> String.trim()
      |> String.downcase()

    "Challenge this #{label}"
  end

  defp highlight_excerpt(%{selected_text_snapshot: text}) when is_binary(text) do
    case String.trim(text) do
      "" -> "Highlighted passage"
      trimmed -> String.slice(trimmed, 0, 120)
    end
  end

  defp highlight_excerpt(_highlight), do: "Highlighted passage"

  defp highlight_link_title(outline_nodes, node_id) do
    case Enum.find(outline_nodes, &(&1.id == node_id)) do
      nil -> "Connected idea"
      node -> node.full_title || node.title || "Connected idea"
    end
  end

  defp reader_nav_params(nav_params, []), do: nav_params

  defp reader_nav_params(nav_params, path_focus_ids) do
    Keyword.put(nav_params, :path, List.last(path_focus_ids))
  end

  defp token_params(token) when is_binary(token) and token != "", do: [token: token]
  defp token_params(_token), do: []
end
