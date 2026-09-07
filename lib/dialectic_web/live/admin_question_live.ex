defmodule DialecticWeb.AdminQuestionLive do
  use DialecticWeb, :live_view
  alias Dialectic.QuestionPages
  alias Dialectic.QuestionPages.{Content, Source}

  @impl true
  def mount(_params, _session, socket) do
    if QuestionPages.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(
         page_title: "Publish question pages",
         noindex: true,
         graph: nil,
         page: nil,
         generating: false,
         generation_timer: nil,
         pending: nil,
         form: nil,
         preview: nil,
         reviewed: false,
         stale?: false,
         published_stale?: false,
         search_form: to_form(%{"query" => ""}, as: :search)
       )
       |> stream(:graphs, [], dom_id: &"question-grid-#{&1.slug}")
       |> stream(:pages, QuestionPages.list_pages(socket.assigns.current_user)), layout: false}
    else
      {:ok, socket |> put_flash(:error, "Access denied.") |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      if socket.assigns.generating,
        do: stop_generation(cancel_async(socket, :generate_draft)),
        else: socket

    if slug = params["grid"] do
      case QuestionPages.editor(socket.assigns.current_user, slug) do
        {:ok, graph, page} ->
          selection =
            if(page,
              do: page.source["selection"],
              else: %{"answer" => "", "evidence" => [], "paths" => []}
            )

          nodes = Source.nodes(graph)
          options = Enum.map(nodes, &{"#{&1["id"]} · #{&1["title"]}", &1["id"]})

          {:noreply,
           socket
           |> assign(
             graph: graph,
             page: page,
             node_options: options,
             selection_form: to_form(selection, as: :selection)
           )
           |> assign_draft(page)
           |> assign_source_status()}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Choose a public, published grid.")
           |> push_patch(to: ~p"/admin/questions")}
      end
    else
      {:noreply, assign(socket, graph: nil, page: nil, form: nil, preview: nil)}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     socket
     |> assign(search_form: to_form(%{"query" => query}, as: :search))
     |> stream(:graphs, QuestionPages.search_graphs(socket.assigns.current_user, query),
       reset: true
     )}
  end

  def handle_event("generate", _params, %{assigns: %{generating: true}} = socket),
    do: {:noreply, socket}

  def handle_event("generate", %{"selection" => selection}, socket) do
    case QuestionPages.prepare(socket.assigns.current_user, socket.assigns.graph.slug, selection) do
      {:ok, source, version} ->
        timer = Process.send_after(self(), :generation_timeout, 120_000)

        {:noreply,
         socket
         |> assign(
           generating: true,
           generation_timer: timer,
           pending: {source, version},
           reviewed: false,
           selection_form: to_form(selection, as: :selection)
         )
         |> start_async(:generate_draft, fn -> QuestionPages.generate(source) end)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("validate", %{"content" => attrs} = params, socket) do
    changeset =
      Content.changeset(Content.load(socket.assigns.page.draft), attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, as: :content), reviewed: params["reviewed"] == "true")
     |> assign_preview()}
  end

  def handle_event("save", _params, %{assigns: %{generating: true}} = socket),
    do: {:noreply, socket}

  def handle_event("save", %{"content" => attrs} = params, socket) do
    intent = if params["intent"] == "publish", do: :publish, else: :draft

    case QuestionPages.save(
           socket.assigns.current_user,
           socket.assigns.page,
           attrs,
           intent,
           params["reviewed"]
         ) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign_draft(page)
         |> assign_source_status()
         |> stream(:pages, QuestionPages.list_pages(socket.assigns.current_user), reset: true)
         |> put_flash(
           :info,
           if(intent == :publish,
             do: "Question page published.",
             else: "Draft saved. The published page has not changed."
           )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :content))}

      {:error, reason} ->
        {:noreply, socket |> refresh_graph() |> put_flash(:error, error_message(reason))}
    end
  end

  def handle_event("refresh_source", _params, socket), do: {:noreply, refresh_graph(socket)}

  def handle_event("unpublish", _params, socket) do
    case QuestionPages.unpublish(socket.assigns.current_user, socket.assigns.page) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign_draft(page)
         |> stream(:pages, QuestionPages.list_pages(socket.assigns.current_user), reset: true)
         |> put_flash(:info, "Question page unpublished.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  @impl true
  def handle_async(:generate_draft, _result, %{assigns: %{generating: false}} = socket),
    do: {:noreply, socket}

  def handle_async(:generate_draft, {:ok, {:ok, content}}, socket) do
    {source, version} = socket.assigns.pending
    socket = stop_generation(socket)

    case QuestionPages.save_generated(socket.assigns.current_user, source, version, content) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign_draft(page)
         |> refresh_graph()
         |> stream(:pages, QuestionPages.list_pages(socket.assigns.current_user), reset: true)
         |> put_flash(
           :info,
           "Draft ready. Review the claims, supporting links and limitations before publishing."
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_async(:generate_draft, _result, socket),
    do:
      {:noreply,
       socket |> stop_generation() |> put_flash(:error, error_message(:generation_failed))}

  @impl true
  def handle_info(:generation_timeout, socket) do
    if socket.assigns.generating do
      {:noreply,
       socket
       |> cancel_async(:generate_draft)
       |> stop_generation()
       |> put_flash(:error, "Draft generation timed out. Your saved draft is intact; try again.")}
    else
      {:noreply, socket}
    end
  end

  defp stop_generation(socket) do
    if socket.assigns.generation_timer, do: Process.cancel_timer(socket.assigns.generation_timer)
    assign(socket, generating: false, generation_timer: nil, pending: nil)
  end

  defp assign_draft(socket, nil),
    do: assign(socket, page: nil, form: nil, preview: nil, reviewed: false)

  defp assign_draft(socket, page) do
    socket
    |> assign(
      page: page,
      reviewed: false,
      form: to_form(Content.changeset(Content.load(page.draft), %{}), as: :content)
    )
    |> assign_preview()
  end

  defp assign_preview(socket) do
    content = socket.assigns.form.source |> Ecto.Changeset.apply_changes() |> Content.dump()

    assign(socket,
      preview: %{
        published: %{"content" => content, "source" => socket.assigns.page.source},
        published_at: nil,
        graph_slug: socket.assigns.graph.slug
      }
    )
  end

  defp refresh_graph(socket) do
    case QuestionPages.editor(socket.assigns.current_user, socket.assigns.graph.slug) do
      {:ok, graph, _} -> socket |> assign(graph: graph) |> assign_source_status()
      _ -> put_flash(socket, :error, "The source grid is no longer available for publishing.")
    end
  end

  defp assign_source_status(%{assigns: %{page: nil}} = socket),
    do: assign(socket, stale?: false, published_stale?: false)

  defp assign_source_status(socket),
    do:
      assign(socket,
        stale?: QuestionPages.stale?(socket.assigns.page, socket.assigns.graph),
        published_stale?:
          QuestionPages.published_stale?(socket.assigns.page, socket.assigns.graph)
      )

  defp source_node(source, id),
    do:
      Enum.find(source["nodes"], &(&1["id"] == id)) ||
        %{"title" => "Unknown node", "content" => "", "sources" => []}

  defp source_options(source, id),
    do: source_node(source, id)["sources"] |> Enum.map(&{&1["title"], &1["id"]})

  defp error_message(:source_changed),
    do:
      "The grid changed after this draft was generated. Refresh your selected nodes and generate a new draft before publishing."

  defp error_message(:conflict),
    do: "Another editor saved this page. Reload it before making more changes."

  defp error_message(:review_required),
    do: "Confirm that you reviewed the claims, sources and limitations before publishing."

  defp error_message(:invalid_selection),
    do: "Choose an answer, one to three evidence nodes, and one to three exploration nodes."

  defp error_message(:selection_too_large),
    do: "The selected text is too long. Choose shorter nodes (60,000 characters maximum)."

  defp error_message(:invalid_references),
    do: "Each section must reference its selected node and only that node’s recorded sources."

  defp error_message(:generation_failed),
    do:
      "Could not generate a valid draft. Your saved draft is intact; try again or edit it manually."

  defp error_message(_),
    do: "This change could not be saved. Check your admin access and the grid’s public status."
end
