defmodule Dialectic.DbActions.Notes do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Note
  alias Dialectic.Accounts.Graph

  import Ecto.Query

  def get_my_stats(nil), do: %{graphs: [], notes: []}

  def get_my_stats(user) do
    # Load graphs without the heavy `data` column, computing counts in SQL
    graphs =
      from(g in Graph,
        where: g.user_id == ^user.id,
        left_join: n in Note,
        on: n.graph_title == g.title and n.is_noted == true,
        group_by: g.title,
        select: %{
          title: g.title,
          is_public: g.is_public,
          is_published: g.is_published,
          slug: g.slug,
          share_token: g.share_token,
          tags: g.tags,
          noted_count: count(n.id),
          node_count:
            fragment(
              "coalesce(jsonb_array_length(?.\"data\"->'nodes'), 0)",
              g
            )
        }
      )
      |> Repo.all()

    # Load notes with their associated graphs (need graph data for node title lookup)
    notes_query =
      from n in Note,
        where: n.user_id == ^user.id,
        preload: [:graph]

    notes = Repo.all(notes_query)

    %{
      graphs: graphs,
      notes: notes
    }
  end

  def top_graphs(limit \\ 12) do
    query =
      from g in Dialectic.Accounts.Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        left_join: n in assoc(g, :notes),
        group_by: g.title,
        order_by: [desc: count(n.id)],
        limit: ^limit,
        select: {g, count(n.id)}

    Dialectic.Repo.all(query)
  end

  def recent_graphs(limit \\ 5) do
    query =
      from g in Dialectic.Accounts.Graph,
        where: g.is_published == true,
        where: g.is_public == true,
        order_by: [desc: g.inserted_at],
        limit: ^limit,
        select: {g, 0}

    Dialectic.Repo.all(query)
  end

  # Marks a note as active (noted)
  def add_note(graph, node, user) do
    case Repo.get_by(Note, graph_title: graph, node_id: node, user_id: user.id) do
      nil ->
        %Note{}
        |> Note.changeset(%{graph_title: graph, node_id: node, user_id: user.id, is_noted: true})
        |> Repo.insert()

      note ->
        note
        |> Ecto.Changeset.change(is_noted: true)
        |> Repo.update()
    end
  end

  # Instead of deleting the note, mark it as inactive (unnoted)
  def remove_note(graph, node, user) do
    case Repo.get_by(Note, graph_title: graph, node_id: node, user_id: user.id) do
      nil ->
        {:error, :not_found}

      note ->
        note
        |> Ecto.Changeset.change(is_noted: false)
        |> Repo.update()
    end
  end

  # Optional: Toggles the note's state between noted and unnoted.
  # def toggle_note(graph, user) do
  #   case Repo.get_by(Notes, graph_id: graph.id, user_id: user.id) do
  #     nil ->
  #       # If no record exists, create one with is_noted set to true.
  #       %Notes{}
  #       |> Notes.changeset(%{graph_id: graph.id, user_id: user.id, is_noted: true})
  #       |> Repo.insert()

  #     note ->
  #       new_state = !note.is_noted

  #       note
  #       |> Ecto.Changeset.change(is_noted: new_state)
  #       |> Repo.update()
  #   end
  # end
end
