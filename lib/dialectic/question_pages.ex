defmodule Dialectic.QuestionPages do
  import Ecto.Query
  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.QuestionPages.{Content, Page, Source}
  alias Dialectic.Repo

  def admin?(%User{id: id}) when not is_nil(id),
    do: Repo.exists?(from u in User, where: u.id == ^id and u.is_admin == true)

  def admin?(_), do: false

  def search_graphs(user, term) do
    if admin?(user) do
      pattern = "%#{String.slice(String.trim(term), 0, 160)}%"

      Repo.all(
        from g in available_graphs(),
          where: ilike(g.title, ^pattern),
          order_by: [desc: g.updated_at],
          limit: 20,
          select: %{title: g.title, slug: g.slug}
      )
    else
      []
    end
  end

  def list_pages(user) do
    if admin?(user) do
      Repo.all(
        from p in Page,
          join: g in Graph,
          on: g.title == p.graph_title,
          order_by: [desc: p.updated_at],
          limit: 50,
          select: %{p | graph_slug: g.slug}
      )
    else
      []
    end
  end

  def editor(user, slug) do
    with true <- admin?(user),
         %Graph{} = graph <- Repo.one(from g in available_graphs(), where: g.slug == ^slug) do
      {:ok, graph, Repo.get_by(Page, graph_title: graph.title)}
    else
      _ -> {:error, :unavailable}
    end
  end

  def prepare(user, slug, selection) do
    with {:ok, graph, page} <- editor(user, slug),
         {:ok, source} <- Source.capture(graph, selection) do
      {:ok, source, if(page, do: page.lock_version, else: 0)}
    end
  end

  def generate(source) do
    generator =
      Application.get_env(:dialectic, :question_page_generator, Dialectic.QuestionPages.Generator)

    with {:ok, attrs} <- generator.generate(source),
         {:ok, content} <-
           Content.changeset(%Content{}, attrs) |> Ecto.Changeset.apply_action(:insert),
         :ok <- Source.validate_references(content, source) do
      {:ok, Content.dump(content)}
    else
      _ -> {:error, :generation_failed}
    end
  end

  def save_generated(user, source, version, attrs) do
    Repo.transact(fn ->
      authorize!(user)
      graph = lock_graph!(source["graph_title"])
      ensure_available!(graph)
      if Source.hash(graph) != source["hash"], do: Repo.rollback(:source_changed)
      page = Repo.one(from p in Page, where: p.graph_title == ^graph.title, lock: "FOR UPDATE")
      check_version!(page, version)
      content = validate_content!(%Content{}, attrs, source)

      (page || %Page{graph_title: graph.title, slug: graph.slug})
      |> Ecto.Changeset.change(
        draft: Content.dump(content),
        source: source,
        editor_id: user.id,
        lock_version: if(page, do: page.lock_version + 1, else: 1)
      )
      |> Ecto.Changeset.unique_constraint(:slug)
      |> Ecto.Changeset.unique_constraint(:graph_title)
      |> Repo.insert_or_update()
    end)
  end

  def save(user, %Page{} = expected, attrs, intent, reviewed \\ false)
      when intent in [:draft, :publish] do
    result =
      Repo.transact(fn ->
        authorize!(user)
        graph = lock_graph!(expected.graph_title)
        ensure_available!(graph)
        page = lock_page!(expected)
        content = validate_content!(Content.load(page.draft), attrs, page.source)

        changes = [
          draft: Content.dump(content),
          editor_id: user.id,
          lock_version: page.lock_version + 1
        ]

        changes =
          if intent == :publish do
            if reviewed not in [true, "true"], do: Repo.rollback(:review_required)
            if stale?(page, graph), do: Repo.rollback(:source_changed)
            now = DateTime.utc_now() |> DateTime.truncate(:second)
            reviewer = Repo.get!(User, user.id)

            changes ++
              [
                published: %{
                  "content" => Content.dump(content),
                  "source" => page.source,
                  "reviewer" => reviewer.username
                },
                published_at: now,
                first_published_at: page.first_published_at || now
              ]
          else
            changes
          end

        page |> Ecto.Changeset.change(changes) |> Repo.update()
      end)

    if intent == :publish, do: notify(result), else: result
  end

  def unpublish(user, %Page{} = expected) do
    Repo.transact(fn ->
      authorize!(user)
      lock_graph!(expected.graph_title)
      page = lock_page!(expected)

      page
      |> Ecto.Changeset.change(
        published: nil,
        published_at: nil,
        lock_version: page.lock_version + 1,
        editor_id: user.id
      )
      |> Repo.update()
    end)
    |> notify()
  end

  def stale?(page, graph), do: page.source["hash"] != Source.hash(graph)
  def published_stale?(%{published: nil}, _graph), do: false
  def published_stale?(page, graph), do: page.published["source"]["hash"] != Source.hash(graph)

  def get_public(slug),
    do:
      Repo.one(
        from [p, g] in published_query(),
          where: p.slug == ^slug,
          select: %Page{
            id: p.id,
            slug: p.slug,
            graph_title: p.graph_title,
            graph_slug: g.slug,
            published: p.published,
            published_at: p.published_at
          }
      )

  def list_public(limit \\ 12) do
    Repo.all(
      from p in published_query(),
        order_by: [desc: p.published_at],
        limit: ^limit,
        select: %{
          id: p.id,
          slug: p.slug,
          published_at: p.published_at,
          title: fragment("?->'content'->>'title'", p.published),
          summary: fragment("?->'content'->>'summary'", p.published)
        }
    )
  end

  def pilot_available? do
    not Repo.exists?(
      from p in Page,
        where: p.slug == "does-ai-make-us-better-thinkers" and not is_nil(p.first_published_at)
    )
  end

  defp available_graphs do
    from g in Graph,
      where:
        g.is_public == true and g.is_published == true and
          (g.is_deleted == false or is_nil(g.is_deleted)) and not is_nil(g.slug)
  end

  defp published_query do
    from p in Page,
      join: g in subquery(available_graphs()),
      on: g.title == p.graph_title,
      where: not is_nil(p.published_at) and not is_nil(p.published)
  end

  defp authorize!(user), do: unless(admin?(user), do: Repo.rollback(:forbidden))

  defp lock_graph!(title),
    do:
      Repo.one(from g in Graph, where: g.title == ^title, lock: "FOR UPDATE") ||
        Repo.rollback(:unavailable)

  defp ensure_available!(graph) do
    unless graph.is_public == true and graph.is_published == true and graph.is_deleted != true,
      do: Repo.rollback(:unavailable)
  end

  defp lock_page!(expected) do
    page =
      Repo.one(from p in Page, where: p.id == ^expected.id, lock: "FOR UPDATE") ||
        Repo.rollback(:unavailable)

    check_version!(page, expected.lock_version)
    page
  end

  defp check_version!(nil, 0), do: :ok
  defp check_version!(%{lock_version: version}, version), do: :ok
  defp check_version!(_, _), do: Repo.rollback(:conflict)

  defp validate_content!(existing, attrs, source) do
    with {:ok, content} <-
           Content.changeset(existing, attrs) |> Ecto.Changeset.apply_action(:update),
         :ok <- Source.validate_references(content, source) do
      content
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp notify({:ok, page} = result) do
    Phoenix.PubSub.broadcast(
      Dialectic.PubSub,
      "question_pages",
      {:question_page_published, page.slug}
    )

    result
  end

  defp notify(result), do: result
end
