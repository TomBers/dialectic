defmodule Dialectic.DbActions.Sharing do
  import Ecto.Query
  alias Dialectic.Repo
  alias Dialectic.Accounts.{Graph, GraphShare, User}
  alias Dialectic.Notifications

  @doc """
  Generates a share token for a graph if one doesn't exist.
  Returns `{:ok, graph}`.
  """
  def ensure_share_token(%Graph{share_token: token} = graph) when is_binary(token) do
    {:ok, graph}
  end

  def ensure_share_token(%Graph{} = graph) do
    regenerate_share_token(graph)
  end

  @doc """
  Regenerates the share token for a graph.
  """
  def regenerate_share_token(%Graph{} = graph) do
    token = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    graph
    |> Graph.changeset(%{share_token: token})
    |> Repo.update()
  end

  @doc """
  Finds a graph by its share token.
  """
  def get_graph_by_token(token) do
    Repo.get_by(Graph, share_token: token)
  end

  @doc """
  Invites a user by email to a graph.
  """
  def invite_user(%Graph{} = graph, email) do
    result =
      %GraphShare{}
      |> GraphShare.changeset(%{
        graph_title: graph.title,
        email: email,
        permission: "edit"
      })
      |> Repo.insert(on_conflict: :nothing)

    case result do
      {:ok, %GraphShare{id: nil}} ->
        result

      {:ok, _share} ->
        record_graph_event(graph, %{
          event_type: "graph.shared",
          summary: "Grid shared with a collaborator",
          metadata: %{email: email}
        })

        result

      {:error, _changeset} ->
        result
    end
  end

  @doc """
  Removes a user's access to a graph.
  """
  def remove_invite(%Graph{} = graph, email) do
    result =
      from(gs in GraphShare,
        where: gs.graph_title == ^graph.title and gs.email == ^email
      )
      |> Repo.delete_all()

    case result do
      {count, _} when count > 0 ->
        record_graph_event(graph, %{
          event_type: "graph.unshared",
          summary: "Collaborator access removed",
          metadata: %{email: email}
        })

      _ ->
        :ok
    end

    result
  end

  @doc """
  Lists all shares for a graph.
  """
  def list_shares(%Graph{} = graph) do
    from(gs in GraphShare,
      where: gs.graph_title == ^graph.title,
      order_by: [desc: gs.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Checks if a user has access to a graph.
  Access is granted if:
  1. The graph is public.
  2. The user is the owner.
  3. The user's email is in the share list.
  """
  def can_access?(nil, %Graph{is_public: true}), do: true
  def can_access?(nil, _graph), do: false

  def can_access?(%User{} = user, %Graph{} = graph) do
    cond do
      graph.is_public -> true
      graph.user_id == user.id -> true
      has_email_access?(user.email, graph.title) -> true
      true -> false
    end
  end

  defp record_graph_event(%Graph{} = graph, attrs) do
    case Notifications.record_graph_event(graph, attrs) do
      {:ok, _event} -> :ok
      {:error, _changeset} -> :ok
    end
  end

  defp has_email_access?(email, graph_title) do
    Repo.exists?(
      from gs in GraphShare,
        where: gs.graph_title == ^graph_title and gs.email == ^email
    )
  end

  @doc """
  Returns all graphs shared with a specific email.
  """
  def list_shared_graphs(email) do
    from(g in Graph,
      join: gs in GraphShare,
      on: gs.graph_title == g.title,
      where: gs.email == ^email,
      preload: [:user]
    )
    |> Repo.all()
  end
end
