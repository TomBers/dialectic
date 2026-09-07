defmodule DialecticWeb.QuestionLive do
  use DialecticWeb, :live_view
  alias Dialectic.QuestionPages

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(params, _session, socket) do
    slug = params["slug"] || "does-ai-make-us-better-thinkers"
    page = QuestionPages.get_public(slug)

    unless page || (slug == "does-ai-make-us-better-thinkers" && QuestionPages.pilot_available?()),
      do: raise(Ecto.NoResultsError, queryable: Dialectic.QuestionPages.Page)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Dialectic.PubSub, "question_pages")
      if page, do: Phoenix.PubSub.subscribe(Dialectic.PubSub, "graph_update:#{page.graph_title}")
    end

    {:ok,
     assign(socket,
       published_page: page,
       question_slug: slug,
       page_title:
         if(page,
           do: page.published["content"]["title"] <> " | RationalGrid",
           else: "Does AI make us better thinkers? | RationalGrid"
         ),
       page_title_suffix: "",
       page_description:
         if(page,
           do: String.slice(page.published["content"]["summary"], 0, 180),
           else:
             "AI can improve an answer without improving its author. Explore three studies, their limits, and how to use AI while keeping your own judgement."
         ),
       canonical_url: DialecticWeb.Endpoint.url() <> ~p"/questions/#{slug}",
       og_type: "article"
     ), layout: false}
  end

  @impl true
  def handle_info({:question_page_published, slug}, %{assigns: %{question_slug: slug}} = socket) do
    {:noreply, redirect(socket, to: ~p"/questions/#{slug}")}
  end

  def handle_info({:graph_access_updated, _title}, socket) do
    if QuestionPages.get_public(socket.assigns.question_slug) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_flash(:error, "This question page is no longer public.")
       |> redirect(to: ~p"/community")}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
