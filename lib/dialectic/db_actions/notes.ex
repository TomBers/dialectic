defmodule Dialectic.DbActions.Notes do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Note

  import Ecto.Query

  def get_my_stats(nil), do: %{graphs: [], notes: []}

  def get_my_stats(user) do
    Repo.get(Dialectic.Accounts.User, user.id) |> Repo.preload([:notes, graphs: [:notes]])
  end

  def top_graphs do
    query =
      from g in Dialectic.Accounts.Graph,
        left_join: n in assoc(g, :notes),
        group_by: g.title,
        order_by: [desc: count(n.id)],
        limit: 10,
        select: {g, count(n.id)}

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
