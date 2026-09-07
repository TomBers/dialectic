defmodule DialecticWeb.QuestionArticle do
  use DialecticWeb, :html

  attr :page, :map, required: true
  attr :prefix, :string, default: "public-question"

  def article(assigns) do
    assigns =
      assign(assigns,
        content: assigns.page.published["content"],
        source: assigns.page.published["source"]
      )

    ~H"""
    <article id={@prefix} class="question-page" aria-labelledby={@prefix <> "-title"}>
      <div class="question-shell">
        <nav class="question-breadcrumb" aria-label="Breadcrumb">
          <.link href={~p"/community"}>Explore questions</.link>
          <span aria-hidden="true">/</span>
          <.link id={@prefix <> "-source-grid"} href={~p"/g/#{@page.graph_slug}"}>Source grid</.link>
        </nav>
        <header class="question-header">
          <p class="question-eyebrow">A question worth thinking about</p>
          <h1 id={@prefix <> "-title"}>{@content["title"]}</h1>
          <p :if={@page.published_at} class="question-meta">
            Published
            <time datetime={DateTime.to_iso8601(@page.published_at)}>{Calendar.strftime(
              @page.published_at,
              "%d %B %Y"
            )}</time>
          </p>
          <p :if={!@page.published_at} class="question-meta">Private draft preview</p>
        </header>
        <div class="question-layout">
          <aside class="question-contents">
            <nav aria-label="On this page">
              <p class="question-eyebrow">In this question</p>
              <a href={"##{@prefix}-answer"}>The short answer</a>
              <a href={"##{@prefix}-evidence"}>Evidence and its limits</a>
              <a href={"##{@prefix}-paths"}>Take a closer look</a>
              <a href={"##{@prefix}-exercise"}>Test your reasoning</a>
            </nav>
          </aside>
          <div class="question-reading">
            <section id={@prefix <> "-answer"} class="question-answer">
              <p class="question-eyebrow">The short answer</p>
              <h2>Start here.</h2>
              <p class="whitespace-pre-wrap">{@content["summary"]}</p>
              <.link
                id={@prefix <> "-answer-node"}
                href={node_path(@page, @source["selection"]["answer"])}
                class="question-source"
              >Read the original answer <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
              <p class="question-takeaway whitespace-pre-wrap">
                <strong>Our interpretation:</strong> {@content["interpretation"]}
              </p>
            </section>
            <section id={@prefix <> "-evidence"} class="question-section">
              <p class="question-eyebrow">Follow the evidence</p>
              <h2>What supports the answer?</h2>
              <p>
                An edited selection from the grid. Each section keeps its original context and the supporting links selected by the editor.
              </p>
              <article
                :for={{section, index} <- Enum.with_index(@content["evidence"])}
                id={"#{@prefix}-evidence-#{index}"}
                class="question-study"
              >
                <h3>{section["title"]}</h3>
                <p class="whitespace-pre-wrap">{section["body"]}</p>
                <p class="question-study-limit whitespace-pre-wrap">
                  <strong>The limit:</strong> {section["limitation"]}
                </p>
                <ul class="mt-3 space-y-1">
                  <li :for={source <- selected_sources(@source, section)}>
                    <.link href={source["url"]} class="question-source break-words">{source["title"]}<.icon
                      name="hero-arrow-up-right"
                      class="h-4 w-4 shrink-0"
                    /></.link>
                  </li>
                </ul>
                <p :if={selected_sources(@source, section) == []} class="question-meta">
                  No supporting source links selected. Treat this section as an unverified claim or argument.
                </p>
                <.link href={node_path(@page, section["node_id"])} class="question-source">Read this section’s original node</.link>
              </article>
              <div id={@prefix <> "-uncertainty"} class="question-uncertainty">
                <h3>What remains uncertain</h3><p class="whitespace-pre-wrap">
                  {@content["uncertainty"]}
                </p>
              </div>
            </section>
            <section id={@prefix <> "-paths"} class="question-section">
              <p class="question-eyebrow">Choose a direction</p><h2>
                Where does your curiosity take you?
              </h2>
              <details
                :for={{section, index} <- Enum.with_index(@content["paths"])}
                id={"#{@prefix}-path-#{index}"}
                class="question-path"
              >
                <summary>
                  <span>{section["title"]}</span><.icon name="hero-plus" class="h-5 w-5 shrink-0" />
                </summary>
                <div>
                  <p class="whitespace-pre-wrap">{section["body"]}</p><.link
                    href={node_path(@page, section["node_id"])}
                    class="question-source"
                  >Continue in the grid <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
                </div>
              </details>
            </section>
            <section id={@prefix <> "-exercise"} class="question-exercise">
              <p class="question-eyebrow">Think for yourself</p><h2>Put the idea to work.</h2>
              <p class="whitespace-pre-wrap">{@content["exercise_question"]}</p>
              <p class="question-meta">Form your own answer before opening ours.</p>
              <details id={@prefix <> "-exercise-answer"} class="question-path">
                <summary>
                  <span>Compare your reasoning</span><.icon name="hero-plus" class="h-5 w-5 shrink-0" />
                </summary>
                <div>
                  <p class="whitespace-pre-wrap">{@content["exercise_answer"]}</p>
                </div>
              </details>
            </section>
            <footer class="question-footer">
              <h2>Keep the question open.</h2>
              <.link id={@prefix <> "-grid"} href={~p"/g/#{@page.graph_slug}"} class="question-next">Explore the source grid
              <.icon name="hero-arrow-right" class="h-5 w-5" /></.link>
              <p class="question-meta">
                Prepared with AI assistance and edited before publication<span :if={
                  @page.published["reviewer"]
                }> by {@page.published["reviewer"]}</span>. This is a saved version; the source grid may have changed. Source links alone do not establish that a claim is correct.
              </p>
            </footer>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp node_path(page, id), do: ~p"/g/#{page.graph_slug}?node=#{id}"

  defp selected_sources(source, section) do
    node = Enum.find(source["nodes"], &(&1["id"] == section["node_id"]))

    if node,
      do: Enum.filter(node["sources"], &(&1["id"] in (section["source_ids"] || []))),
      else: []
  end
end
