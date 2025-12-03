defmodule Dialectic.Highlights do
  @moduledoc """
  The Highlights context.
  """

  import Ecto.Query, warn: false
  alias Dialectic.Repo

  alias Dialectic.Highlights.Highlight

  @doc """
  Returns the list of highlights.

  ## Examples

      iex> list_highlights()
      [%Highlight{}, ...]

  """
  def list_highlights do
    Repo.all(Highlight)
  end

  @doc """
  Returns the list of highlights matching the given criteria.

  ## Options

    * `:mudg_id` - The ID (title) of the graph.
    * `:node_id` - The ID of the node.
    * `:created_by_user_id` - The ID of the user who created the highlight.

  ## Examples

      iex> list_highlights(mudg_id: "graph-title")
      [%Highlight{}, ...]

  """
  def list_highlights(criteria) do
    query = from(h in Highlight)

    query =
      Enum.reduce(criteria, query, fn
        {:mudg_id, mudg_id}, query ->
          from q in query, where: q.mudg_id == ^mudg_id

        {:created_by_user_id, user_id}, query ->
          from q in query, where: q.created_by_user_id == ^user_id

        {:node_id, node_id}, query ->
          from q in query, where: q.node_id == ^node_id

        _, query ->
          query
      end)

    Repo.all(query)
  end

  @doc """
  Gets a single highlight.

  Raises `Ecto.NoResultsError` if the Highlight does not exist.

  ## Examples

      iex> get_highlight!(123)
      %Highlight{}

      iex> get_highlight!(456)
      ** (Ecto.NoResultsError)

  """
  def get_highlight!(id), do: Repo.get!(Highlight, id)

  @doc """
  Creates a highlight.

  ## Examples

      iex> create_highlight(%{field: value})
      {:ok, %Highlight{}}

      iex> create_highlight(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_highlight(attrs \\ %{}) do
    %Highlight{}
    |> Highlight.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a highlight.

  ## Examples

      iex> update_highlight(highlight, %{field: new_value})
      {:ok, %Highlight{}}

      iex> update_highlight(highlight, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_highlight(%Highlight{} = highlight, attrs) do
    highlight
    |> Highlight.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a highlight.

  ## Examples

      iex> delete_highlight(highlight)
      {:ok, %Highlight{}}

      iex> delete_highlight(highlight)
      {:error, %Ecto.Changeset{}}

  """
  def delete_highlight(%Highlight{} = highlight) do
    Repo.delete(highlight)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking highlight changes.

  ## Examples

      iex> change_highlight(highlight)
      %Ecto.Changeset{data: %Highlight{}}

  """
  def change_highlight(%Highlight{} = highlight, attrs \\ %{}) do
    Highlight.changeset(highlight, attrs)
  end
end
