defmodule Dialectic.DbActions.Notes do
  alias Dialectic.Repo
  # alias Dialectic.Accounts.Graph
  alias Dialectic.Accounts.Note

  import Ecto.Query

  def tst do
    user =
      Repo.get(Dialectic.Accounts.User, "1")

    # |> IO.inspect(label: "User")

    # add_note("Bill", "1", user)
    remove_note("Bill", "1", user)
  end

  def count_notes_for_user(user_id) do
    query =
      from n in Note,
        join: g in assoc(n, :graph),
        where: g.user_id == ^user_id,
        preload: [graph: g]

    notes = Repo.all(query)
    IO.inspect(notes)
  end

  # Marks a note as active (noted)
  def add_note(graph, node, user) do
    case Repo.get_by(Note, graph_id: graph, node_id: node, user_id: user.id) do
      nil ->
        %Note{}
        |> Note.changeset(%{graph_id: graph, node_id: node, user_id: user.id, is_noted: true})
        |> Repo.insert()

      note ->
        note
        |> Ecto.Changeset.change(is_noted: true)
        |> Repo.update()
    end
  end

  # Instead of deleting the note, mark it as inactive (unnoted)
  def remove_note(graph, node, user) do
    case Repo.get_by(Note, graph_id: graph, node_id: node, user_id: user.id) do
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
