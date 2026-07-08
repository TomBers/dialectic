defmodule DialecticWeb.AdminSocialLive do
  use DialecticWeb, :live_view

  alias Dialectic.Content
  alias Dialectic.Content.DraftGenerator
  alias Dialectic.Highlights
  alias DialecticWeb.HighlightShare

  @default_post_type "contribution_prompt"
  @post_type_options [
    {"Contribution prompt", "contribution_prompt"},
    {"Question hook", "question_hook"},
    {"Unresolved disagreement", "unresolved_disagreement"},
    {"Quote or excerpt", "quote_excerpt"},
    {"Argument summary", "argument_summary"},
    {"Expert invitation", "expert_invitation"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    unless current_user && current_user.is_admin do
      {:ok,
       socket
       |> put_flash(:error, "Access denied.")
       |> redirect(to: ~p"/")}
    else
      {:ok,
       assign(socket,
         page_title: "Content Studio",
         search_form: to_form(%{"search" => ""}),
         generation_form: generation_form(),
         post_type_options: @post_type_options,
         search_term: "",
         graph_results: Content.list_candidate_graphs("", limit: 12),
         selected_graph: nil,
         candidate_nodes: [],
         selected_platforms: DraftGenerator.default_platforms(),
         generated_drafts: [],
         saved_drafts: Content.list_drafts(limit: 12),
         visual_assets: [],
         generating?: false
       )}
    end
  end

  @impl true
  def handle_event("search_graphs", %{"search" => term}, socket) do
    {:noreply,
     assign(socket,
       search_form: to_form(%{"search" => term}),
       search_term: term,
       graph_results: Content.list_candidate_graphs(term, limit: 20)
     )}
  end

  @impl true
  def handle_event("select_graph", %{"title" => title}, socket) do
    case Content.get_public_graph(title) do
      nil ->
        {:noreply, put_flash(socket, :error, "Could not find a public grid named #{title}.")}

      graph ->
        nodes = Content.list_graph_nodes(graph, limit: 40)

        {:noreply,
         assign(socket,
           selected_graph: graph,
           candidate_nodes: nodes,
           generation_form: generation_form(),
           generated_drafts: [],
           saved_drafts: Content.list_drafts(graph_title: graph.title, limit: 12),
           visual_assets: visual_assets(graph)
         )}
    end
  end

  @impl true
  def handle_event("toggle_platform", %{"platform" => platform}, socket) do
    selected = socket.assigns.selected_platforms

    selected =
      if platform in selected do
        List.delete(selected, platform)
      else
        selected ++ [platform]
      end

    {:noreply, assign(socket, selected_platforms: selected)}
  end

  @impl true
  def handle_event("update_generation", %{"content_generation" => params}, socket) do
    {:noreply, assign(socket, generation_form: generation_form(params))}
  end

  @impl true
  def handle_event("generate_drafts", %{"content_generation" => params}, socket) do
    socket = assign(socket, generation_form: generation_form(params))
    graph = socket.assigns.selected_graph
    platforms = socket.assigns.selected_platforms

    cond do
      is_nil(graph) ->
        {:noreply, put_flash(socket, :error, "Choose a public grid first.")}

      platforms == [] ->
        {:noreply, put_flash(socket, :error, "Choose at least one platform.")}

      true ->
        generator = Application.get_env(:dialectic, :content_draft_generator, DraftGenerator)

        opts = [
          platforms: platforms,
          node_id: Map.get(params, "node_id"),
          post_type: Map.get(params, "post_type", @default_post_type),
          url: public_graph_url(graph),
          utm_campaign: "content_studio"
        ]

        case generator.generate_pack(graph, opts) do
          {:ok, drafts} when is_list(drafts) and drafts != [] ->
            {:noreply,
             socket
             |> put_flash(:info, "Generated #{length(drafts)} draft#{plural(drafts)}.")
             |> assign(generated_drafts: attach_draft_forms(drafts))}

          {:ok, []} ->
            {:noreply, put_flash(socket, :error, "The generator returned no drafts.")}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not generate drafts: #{format_error(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("save_generated_draft", %{"draft" => %{"index" => index} = params}, socket) do
    with {index, ""} <- Integer.parse(index),
         draft when is_map(draft) <- Enum.at(socket.assigns.generated_drafts, index),
         attrs <- generated_draft_attrs(draft, params),
         {:ok, _saved} <- Content.create_draft(attrs, socket.assigns.current_user) do
      graph_title = socket.assigns.selected_graph && socket.assigns.selected_graph.title

      {:noreply,
       socket
       |> put_flash(:info, "Saved #{draft.platform_label} draft.")
       |> assign(saved_drafts: Content.list_drafts(graph_title: graph_title, limit: 12))}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not save this draft.")}
    end
  end

  @impl true
  def handle_event("mark_used", %{"id" => id}, socket) do
    draft = Content.get_draft!(id)

    case Content.mark_draft_used(draft) do
      {:ok, _draft} ->
        {:noreply, refresh_saved_drafts(socket, "Marked draft as used.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update draft.")}
    end
  end

  @impl true
  def handle_event("archive_draft", %{"id" => id}, socket) do
    draft = Content.get_draft!(id)

    case Content.archive_draft(draft) do
      {:ok, _draft} ->
        {:noreply, refresh_saved_drafts(socket, "Archived draft.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not archive draft.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="content-studio" phx-hook="ContentDrafts" class="mx-auto max-w-7xl px-6 py-10">
      <div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <.link
            navigate={~p"/admin/curated"}
            class="text-sm font-semibold text-indigo-600 hover:text-indigo-500"
          >
            <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to admin
          </.link>
          <h1 class="mt-4 text-2xl font-bold text-gray-900">Content Studio</h1>
          <p class="mt-2 max-w-3xl text-sm leading-6 text-gray-500">
            Generate text-first campaign drafts from public RationalGrid topics. Start with copy/export, then mark what you use.
          </p>
        </div>

        <div class="rounded-2xl border border-indigo-100 bg-indigo-50 px-4 py-3 text-sm text-indigo-900">
          <p class="font-semibold">Phase 1: draft assistant</p>
          <p class="mt-1 text-xs leading-5 text-indigo-700">
            No external posting yet. Review, edit, copy, and save before sharing.
          </p>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.35fr)]">
        <section class="space-y-6">
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">1. Choose a public grid</h2>
            <.form
              for={@search_form}
              id="content-graph-search-form"
              phx-change="search_graphs"
              class="mt-4"
            >
              <.input
                field={@search_form[:search]}
                type="search"
                label="Search grids"
                placeholder="Search by title..."
                autocomplete="off"
                phx-debounce="300"
              />
            </.form>

            <div
              id="content-graph-results"
              class="mt-4 max-h-80 divide-y divide-gray-100 overflow-y-auto rounded-xl border border-gray-100"
            >
              <%= for {graph, node_count, author} <- @graph_results do %>
                <button
                  id={"content-select-#{dom_id(graph.title)}"}
                  type="button"
                  phx-click="select_graph"
                  phx-value-title={graph.title}
                  class={[
                    "block w-full px-4 py-3 text-left transition hover:bg-gray-50",
                    @selected_graph && @selected_graph.title == graph.title && "bg-indigo-50"
                  ]}
                >
                  <span class="block text-sm font-semibold text-gray-900">{graph.title}</span>
                  <span class="mt-1 block text-xs text-gray-500">
                    {node_count} nodes{if author, do: " · by @#{author}", else: ""}
                  </span>
                  <span class="mt-2 flex flex-wrap gap-1">
                    <%= for tag <- Enum.take(graph.tags || [], 4) do %>
                      <span class="rounded-full bg-gray-100 px-2 py-0.5 text-[11px] font-medium text-gray-600">
                        {tag}
                      </span>
                    <% end %>
                  </span>
                </button>
              <% end %>
            </div>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">2. Select outputs</h2>
            <p class="mt-1 text-sm text-gray-500">
              Current channels are selected by default. Add others when a topic fits.
            </p>

            <div class="mt-4 grid grid-cols-2 gap-2">
              <%= for platform <- DraftGenerator.platform_options() do %>
                <button
                  id={"content-platform-#{platform.id}"}
                  type="button"
                  phx-click="toggle_platform"
                  phx-value-platform={platform.id}
                  class={[
                    "rounded-xl border px-3 py-2 text-left text-sm transition",
                    if(platform.id in @selected_platforms,
                      do: "border-indigo-300 bg-indigo-50 text-indigo-900 shadow-sm",
                      else: "border-gray-200 bg-white text-gray-700 hover:bg-gray-50"
                    )
                  ]}
                >
                  <span class="block font-semibold">{platform.label}</span>
                  <span class="mt-0.5 block text-[11px] text-gray-500">
                    {String.replace(platform.format, "_", " ")}
                  </span>
                </button>
              <% end %>
            </div>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">3. Generate a campaign pack</h2>

            <%= if @selected_graph do %>
              <div class="mt-3 rounded-xl bg-gray-50 p-3">
                <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">
                  Selected grid
                </p>
                <p class="mt-1 text-sm font-semibold text-gray-900">{@selected_graph.title}</p>
                <.link
                  navigate={graph_path(@selected_graph)}
                  class="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-indigo-600 hover:text-indigo-500"
                >
                  Open public reader
                  <.icon name="hero-arrow-top-right-on-square" class="h-3.5 w-3.5" />
                </.link>
              </div>
            <% else %>
              <p class="mt-3 text-sm text-gray-500">Choose a grid before generating drafts.</p>
            <% end %>

            <.form
              for={@generation_form}
              id="content-generate-form"
              phx-change="update_generation"
              phx-submit="generate_drafts"
              class="mt-4 space-y-4"
            >
              <.input
                field={@generation_form[:post_type]}
                type="select"
                label="Post angle"
                options={@post_type_options}
              />
              <.input
                field={@generation_form[:node_id]}
                type="select"
                label="Focus node"
                prompt="Whole grid"
                options={node_options(@candidate_nodes)}
              />

              <button
                id="content-generate-btn"
                type="submit"
                class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
                disabled={is_nil(@selected_graph) || @selected_platforms == []}
              >
                <.icon name="hero-sparkles" class="h-4 w-4" /> Generate drafts
              </button>
            </.form>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">4. Visual assets</h2>
            <p class="mt-1 text-sm text-gray-500">
              Reuse existing RationalGrid share-card generation for graph cards and highlighted quotes.
            </p>

            <%= cond do %>
              <% is_nil(@selected_graph) -> %>
                <div class="mt-4 rounded-xl border border-dashed border-gray-200 bg-gray-50 p-6 text-center text-sm text-gray-500">
                  Choose a grid to see available image assets.
                </div>
              <% @visual_assets == [] -> %>
                <div class="mt-4 rounded-xl border border-dashed border-gray-200 bg-gray-50 p-6 text-center text-sm text-gray-500">
                  No visual assets found for this grid yet.
                </div>
              <% true -> %>
                <div id="content-visual-assets" class="mt-4 space-y-4">
                  <%= for asset <- @visual_assets do %>
                    <article
                      id={"content-visual-asset-#{asset.id}"}
                      class="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm"
                    >
                      <img
                        src={asset.url}
                        alt={asset.title}
                        class="block aspect-[1200/630] w-full bg-gray-50 object-contain"
                        loading="lazy"
                      />
                      <div class="space-y-3 p-3">
                        <div>
                          <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">
                            {asset.kind}
                          </p>
                          <h3 class="mt-1 text-sm font-semibold text-gray-900">{asset.title}</h3>
                          <p class="mt-1 text-xs leading-5 text-gray-500">{asset.description}</p>
                        </div>
                        <div class="flex flex-wrap gap-2">
                          <button
                            type="button"
                            data-copy-text={asset.url}
                            class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
                          >
                            <.icon name="hero-link" class="h-3.5 w-3.5" /> Copy URL
                          </button>
                          <button
                            type="button"
                            data-download-svg-png={asset.url}
                            data-download-filename={asset.filename}
                            class="inline-flex items-center gap-1.5 rounded-lg border border-indigo-200 bg-indigo-50 px-2.5 py-1.5 text-xs font-semibold text-indigo-700 transition hover:bg-indigo-100 disabled:cursor-wait disabled:opacity-60"
                          >
                            <.icon name="hero-arrow-down-tray" class="h-3.5 w-3.5" /> Download PNG
                          </button>
                        </div>
                      </div>
                    </article>
                  <% end %>
                </div>
            <% end %>
          </div>
        </section>

        <section class="space-y-6">
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-base font-semibold text-gray-900">Generated drafts</h2>
                <p class="mt-1 text-sm text-gray-500">
                  Edit the text, copy it, or save it to the draft history.
                </p>
              </div>
            </div>

            <%= if @generated_drafts == [] do %>
              <div class="mt-5 rounded-xl border border-dashed border-gray-200 bg-gray-50 p-8 text-center text-sm text-gray-500">
                Generated campaign drafts will appear here.
              </div>
            <% else %>
              <div id="generated-content-drafts" class="mt-5 space-y-4">
                <%= for {draft, index} <- Enum.with_index(@generated_drafts) do %>
                  <article
                    id={draft.temp_id}
                    class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm"
                  >
                    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
                      <div>
                        <span class="rounded-full bg-indigo-50 px-2.5 py-1 text-xs font-semibold text-indigo-700">
                          {draft.platform_label}
                        </span>
                        <span class="ml-2 text-xs font-medium text-gray-500">
                          {String.replace(draft.format, "_", " ")}
                        </span>
                      </div>
                      <button
                        type="button"
                        data-copy-target={"#generated-draft-body-#{index}"}
                        class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
                      >
                        <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" /> Copy text
                      </button>
                    </div>

                    <.form
                      for={draft.form}
                      id={"generated-draft-form-#{index}"}
                      phx-submit="save_generated_draft"
                      class="space-y-3"
                    >
                      <input type="hidden" name="draft[index]" value={index} />
                      <.input
                        id={"generated-draft-title-#{index}"}
                        field={draft.form[:title]}
                        type="text"
                        label="Title"
                      />
                      <.input
                        id={"generated-draft-body-#{index}"}
                        field={draft.form[:body]}
                        type="textarea"
                        label="Body"
                        rows="10"
                        class="mt-2 block w-full rounded-lg border px-3 py-2 text-sm leading-6 text-zinc-900 focus:ring-0"
                      />
                      <.input
                        id={"generated-draft-excerpt-#{index}"}
                        field={draft.form[:excerpt]}
                        type="text"
                        label="Internal hook summary"
                      />

                      <button
                        type="submit"
                        class="inline-flex items-center gap-2 rounded-lg bg-gray-900 px-3 py-2 text-xs font-semibold text-white transition hover:bg-gray-700"
                      >
                        <.icon name="hero-bookmark" class="h-3.5 w-3.5" /> Save draft
                      </button>
                    </.form>
                  </article>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-base font-semibold text-gray-900">Saved drafts</h2>
                <p class="mt-1 text-sm text-gray-500">
                  Keep a history of copy you used or want to revisit.
                </p>
              </div>
            </div>

            <%= if @saved_drafts == [] do %>
              <div class="mt-5 rounded-xl border border-dashed border-gray-200 bg-gray-50 p-8 text-center text-sm text-gray-500">
                No saved drafts yet.
              </div>
            <% else %>
              <div id="saved-content-drafts" class="mt-5 space-y-3">
                <%= for draft <- @saved_drafts do %>
                  <article
                    id={"saved-content-draft-#{draft.id}"}
                    class="rounded-2xl border border-gray-200 p-4"
                  >
                    <div class="flex flex-wrap items-center justify-between gap-2">
                      <div>
                        <span class="rounded-full bg-gray-100 px-2.5 py-1 text-xs font-semibold text-gray-700">
                          {DraftGenerator.platform_label(draft.platform)}
                        </span>
                        <span class="ml-2 rounded-full bg-white px-2.5 py-1 text-xs font-semibold text-gray-500 ring-1 ring-gray-200">
                          {draft.status}
                        </span>
                      </div>
                      <div class="flex flex-wrap gap-2">
                        <button
                          type="button"
                          data-copy-target={"#saved-draft-body-#{draft.id}"}
                          class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
                        >
                          <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" /> Copy
                        </button>
                        <button
                          type="button"
                          phx-click="mark_used"
                          phx-value-id={draft.id}
                          class="inline-flex items-center gap-1.5 rounded-lg border border-green-200 bg-green-50 px-2.5 py-1.5 text-xs font-semibold text-green-700 transition hover:bg-green-100"
                        >
                          <.icon name="hero-check" class="h-3.5 w-3.5" /> Used
                        </button>
                        <button
                          type="button"
                          phx-click="archive_draft"
                          phx-value-id={draft.id}
                          class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-600 transition hover:bg-gray-50"
                        >
                          <.icon name="hero-archive-box" class="h-3.5 w-3.5" /> Archive
                        </button>
                      </div>
                    </div>

                    <h3 class="mt-3 text-sm font-semibold text-gray-900">
                      {draft.title || draft.graph_title}
                    </h3>
                    <textarea
                      id={"saved-draft-body-#{draft.id}"}
                      readonly
                      class="mt-3 min-h-32 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2 text-sm leading-6 text-gray-700"
                    >{draft.body}</textarea>
                  </article>
                <% end %>
              </div>
            <% end %>
          </div>
        </section>
      </div>
    </div>
    """
  end

  defp generation_form(params \\ %{}) do
    params =
      Map.merge(
        %{"post_type" => @default_post_type, "node_id" => ""},
        Map.new(params, fn {key, value} -> {to_string(key), value} end)
      )

    to_form(params, as: :content_generation)
  end

  defp attach_draft_forms(drafts) do
    drafts
    |> Enum.with_index()
    |> Enum.map(fn {draft, index} ->
      draft
      |> Map.put(:temp_id, "generated-content-draft-#{index}")
      |> Map.put(:form, generated_form(draft))
    end)
  end

  defp generated_form(draft) do
    to_form(
      %{
        "title" => Map.get(draft, :title, ""),
        "body" => Map.get(draft, :body, ""),
        "excerpt" => Map.get(draft, :excerpt, "")
      },
      as: :draft
    )
  end

  defp generated_draft_attrs(draft, params) do
    %{
      graph_title: draft.graph_title,
      node_id: draft.node_id,
      platform: draft.platform,
      format: draft.format,
      title: Map.get(params, "title", draft.title),
      body: Map.get(params, "body", draft.body),
      excerpt: Map.get(params, "excerpt", draft.excerpt),
      status: "draft",
      utm_source: draft.utm_source,
      utm_campaign: draft.utm_campaign,
      metadata: draft.metadata || %{}
    }
  end

  defp visual_assets(graph) do
    title_slug = filename_slug(graph.title)

    graph_asset = %{
      id: "grid-card",
      kind: "Grid card",
      title: graph.title,
      description: "Topic-level share card for link previews, newsletters, and social posts.",
      url: HighlightShare.graph_image_url(graph),
      filename: "#{title_slug}-rationalgrid-card.png"
    }

    highlight_assets =
      graph.title
      |> highlights_for_graph()
      |> Enum.take(4)
      |> Enum.map(fn highlight ->
        excerpt = Content.excerpt(highlight.selected_text_snapshot, 150)

        %{
          id: "highlight-#{highlight.id}",
          kind: "Quote card",
          title: "Highlighted quote",
          description: excerpt,
          url: HighlightShare.image_url(graph, highlight),
          filename: "#{title_slug}-quote-#{highlight.id}.png"
        }
      end)

    [graph_asset | highlight_assets]
  end

  defp highlights_for_graph(graph_title) do
    Highlights.list_highlights(mudg_id: graph_title)
  end

  defp node_options(nodes) do
    Enum.map(nodes, fn node -> {"#{node.title} · #{node.class}", node.id} end)
  end

  defp public_graph_url(graph), do: DialecticWeb.Endpoint.url() <> graph_path(graph)

  defp refresh_saved_drafts(socket, message) do
    graph_title = socket.assigns.selected_graph && socket.assigns.selected_graph.title

    socket
    |> put_flash(:info, message)
    |> assign(saved_drafts: Content.list_drafts(graph_title: graph_title, limit: 12))
  end

  defp plural([_one]), do: ""
  defp plural(_drafts), do: "s"

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp filename_slug(value), do: dom_id(value)

  defp dom_id(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "grid"
      dom_id -> dom_id
    end
  end
end
