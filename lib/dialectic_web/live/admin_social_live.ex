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
         selected_platforms: [],
         generated_posts: [],
         follow_up_source_markdown: "",
         visual_assets: []
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
        {:noreply,
         assign(socket,
           selected_graph: graph,
           generation_form: generation_form(),
           generated_posts: [],
           follow_up_source_markdown: first_answer_markdown(graph),
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
  def handle_event("generate_posts", %{"content_generation" => params}, socket) do
    socket = assign(socket, generation_form: generation_form(params))
    graph = socket.assigns.selected_graph
    platforms = socket.assigns.selected_platforms

    cond do
      is_nil(graph) ->
        {:noreply, put_flash(socket, :error, "Choose a public grid first.")}

      platforms == [] ->
        {:noreply, put_flash(socket, :error, "Choose at least one platform.")}

      true ->
        generator = Application.get_env(:dialectic, :content_post_generator, DraftGenerator)

        opts = [
          platforms: platforms,
          post_type: Map.get(params, "post_type", @default_post_type),
          follow_up_questions: Map.get(params, "follow_up_questions", []),
          url: public_graph_url(graph),
          utm_campaign: "content_studio"
        ]

        case generator.generate_pack(graph, opts) do
          {:ok, posts} when is_list(posts) and posts != [] ->
            {:noreply,
             socket
             |> put_flash(:info, "Generated #{length(posts)} post#{plural(posts)}.")
             |> assign(generated_posts: posts)}

          {:ok, []} ->
            {:noreply, put_flash(socket, :error, "The generator returned no posts.")}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not generate posts: #{format_error(reason)}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="content-studio" phx-hook="ContentStudio" class="mx-auto max-w-7xl px-6 py-10">
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
            Generate post copy and visual assets from public RationalGrid topics.
          </p>
        </div>

        <div class="rounded-2xl border border-indigo-100 bg-indigo-50 px-4 py-3 text-sm text-indigo-900">
          <p class="font-semibold">Simple campaign helper</p>
          <p class="mt-1 text-xs leading-5 text-indigo-700">
            Choose a grid, tick platforms, generate copy, then copy or download assets.
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
            <h2 class="text-base font-semibold text-gray-900">2. Pick platforms</h2>
            <p class="mt-1 text-sm text-gray-500">
              Nothing is selected by default. Tick only the platforms you want copy for.
            </p>

            <div class="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
              <%= for platform <- DraftGenerator.platform_options() do %>
                <label
                  for={"content-platform-#{platform.id}"}
                  class={[
                    "flex cursor-pointer items-start gap-3 rounded-xl border px-3 py-2.5 text-sm transition",
                    if(platform.id in @selected_platforms,
                      do: "border-indigo-300 bg-indigo-50 text-indigo-900 shadow-sm",
                      else: "border-gray-200 bg-white text-gray-700 hover:bg-gray-50"
                    )
                  ]}
                >
                  <input
                    id={"content-platform-#{platform.id}"}
                    type="checkbox"
                    checked={platform.id in @selected_platforms}
                    phx-click="toggle_platform"
                    phx-value-platform={platform.id}
                    class="mt-0.5 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                  />
                  <span>
                    <span class="block font-semibold">{platform.label}</span>
                    <span class="mt-0.5 block text-[11px] text-gray-500">
                      {String.replace(platform.format, "_", " ")}
                    </span>
                  </span>
                </label>
              <% end %>
            </div>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">3. Generate post copy</h2>

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

              <div
                id="content-key-follow-up-questions"
                data-follow-up-question-source={@follow_up_source_markdown}
                data-follow-up-card-url-template={follow_up_card_url_template(@selected_graph)}
                data-follow-up-card-filename-prefix={filename_slug(@selected_graph.title)}
                class="mt-3 rounded-xl border border-sky-100 bg-white p-3"
              >
                <div class="flex items-start gap-2">
                  <span class="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-sky-100 text-sky-700">
                    <.icon name="hero-question-mark-circle" class="h-4 w-4" />
                  </span>
                  <div class="min-w-0 flex-1">
                    <p class="text-xs font-semibold uppercase tracking-wide text-sky-700">
                      Key follow-up questions
                    </p>
                    <p class="mt-1 text-xs leading-5 text-slate-500">
                      Parsed with the same follow-up question logic used in the graph view.
                    </p>
                  </div>
                </div>
                <p data-follow-up-question-empty class="mt-3 text-sm text-slate-500">
                  No follow-up question block found in the first answer yet.
                </p>
                <ol data-follow-up-question-list class="mt-3 hidden space-y-2"></ol>
              </div>
            <% else %>
              <p class="mt-3 text-sm text-gray-500">Choose a grid before generating copy.</p>
            <% end %>

            <.form
              for={@generation_form}
              id="content-generate-form"
              phx-change="update_generation"
              phx-submit="generate_posts"
              class="mt-4 space-y-4"
            >
              <.input
                field={@generation_form[:post_type]}
                type="select"
                label="Post angle"
                options={@post_type_options}
              />

              <div data-follow-up-question-inputs></div>

              <button
                id="content-generate-btn"
                type="submit"
                class="inline-flex w-full items-center justify-center gap-2 rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-60"
                disabled={is_nil(@selected_graph) || @selected_platforms == []}
              >
                <.icon name="hero-sparkles" class="h-4 w-4" /> Generate post copy
              </button>
            </.form>
          </div>

          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 class="text-base font-semibold text-gray-900">4. Visual assets</h2>
            <p class="mt-1 text-sm text-gray-500">
              Reuse existing RationalGrid share-card generation for topic cards, highlighted quotes, and follow-up questions.
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
                  <div data-follow-up-asset-list class="space-y-4"></div>
                </div>
            <% end %>
          </div>
        </section>

        <section class="space-y-6">
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-base font-semibold text-gray-900">Generated post copy</h2>
                <p class="mt-1 text-sm text-gray-500">
                  Edit a textarea if needed, then copy the text for that platform.
                </p>
              </div>
            </div>

            <%= if @generated_posts == [] do %>
              <div class="mt-5 rounded-xl border border-dashed border-gray-200 bg-gray-50 p-8 text-center text-sm text-gray-500">
                Generated post copy will appear here.
              </div>
            <% else %>
              <div id="generated-content-posts" class="mt-5 space-y-4">
                <%= for {post, index} <- Enum.with_index(@generated_posts) do %>
                  <article
                    id={"generated-post-#{index}"}
                    class="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm"
                  >
                    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
                      <div>
                        <span class="rounded-full bg-indigo-50 px-2.5 py-1 text-xs font-semibold text-indigo-700">
                          {post.platform_label}
                        </span>
                        <span class="ml-2 text-xs font-medium text-gray-500">
                          {String.replace(post.format, "_", " ")}
                        </span>
                      </div>
                      <button
                        type="button"
                        data-copy-target={"#generated-post-body-#{index}"}
                        class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50"
                      >
                        <.icon name="hero-clipboard-document" class="h-3.5 w-3.5" /> Copy text
                      </button>
                    </div>

                    <p class="text-sm font-semibold text-gray-900">{post.title}</p>
                    <textarea
                      id={"generated-post-body-#{index}"}
                      class="mt-3 min-h-56 w-full rounded-xl border border-gray-200 bg-gray-50 px-3 py-2 text-sm leading-6 text-gray-800 focus:border-indigo-300 focus:outline-none focus:ring-2 focus:ring-indigo-100"
                    >{post.body}</textarea>
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
        %{"post_type" => @default_post_type},
        Map.new(params, fn {key, value} -> {to_string(key), value} end)
      )

    to_form(params, as: :content_generation)
  end

  defp first_answer_markdown(graph) do
    graph
    |> first_answer_node()
    |> case do
      nil -> ""
      node -> Map.get(node, "content") || Map.get(node, :content) || ""
    end
  end

  defp follow_up_card_url_template(graph) do
    node_id =
      graph
      |> first_answer_node()
      |> case do
        nil -> "1"
        node -> Map.get(node, "id") || Map.get(node, :id) || "1"
      end
      |> to_string()

    identifier = graph.slug || URI.encode(graph.title, &URI.char_unreserved?/1)

    DialecticWeb.Endpoint.url() <>
      "/g/#{identifier}/follow-up-card.svg?" <>
      URI.encode_query(%{node: node_id, question: "__QUESTION__"})
  end

  defp first_answer_node(graph) do
    graph
    |> Content.graph_nodes()
    |> Enum.find(fn node ->
      (Map.get(node, "class") || Map.get(node, :class)) == "answer" and
        Map.get(node, "deleted") != true and Map.get(node, :deleted) != true
    end)
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

  defp public_graph_url(graph), do: DialecticWeb.Endpoint.url() <> graph_path(graph)

  defp plural([_one]), do: ""
  defp plural(_posts), do: "s"

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
