defmodule Dialectic.Notifications do
  import Ecto.Query, warn: false

  alias Dialectic.Accounts.{Graph, User}
  alias Dialectic.Notifications.{EmailSubscriber, GraphEvent, GraphFollow, Notifier}
  alias Dialectic.Repo

  @hash_algorithm :sha256
  @rand_size 32
  @confirm_validity_in_days 7

  def change_email_signup(attrs \\ %{}) do
    EmailSubscriber.signup_changeset(%EmailSubscriber{}, attrs)
  end

  def record_graph_event(%Graph{title: graph_title}, attrs) when is_map(attrs) do
    attrs = normalize_attrs(attrs)
    actor_user = Map.get(attrs, "actor_user")
    actor_user_id = Map.get(attrs, "actor_user_id") || actor_user_id(actor_user)

    attrs =
      attrs
      |> Map.drop(["actor_user"])
      |> Map.merge(%{
        "graph_title" => graph_title,
        "actor_user_id" => actor_user_id,
        "metadata" => stringify_metadata(Map.get(attrs, "metadata", %{})),
        "occurred_at" => Map.get(attrs, "occurred_at", DateTime.utc_now(:second))
      })

    %GraphEvent{}
    |> GraphEvent.changeset(attrs)
    |> Repo.insert()
  end

  def list_graph_events(%Graph{title: graph_title}, opts \\ []) do
    since = Keyword.get(opts, :since)
    limit = Keyword.get(opts, :limit, 100)

    GraphEvent
    |> where([e], e.graph_title == ^graph_title)
    |> maybe_since(since)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> preload([:actor_user, :graph])
    |> Repo.all()
  end

  def list_owned_graph_events(%User{id: user_id}, opts \\ []) do
    since = Keyword.get(opts, :since)
    limit = Keyword.get(opts, :limit, 100)

    GraphEvent
    |> join(:inner, [e], g in assoc(e, :graph))
    |> where([_e, g], g.user_id == ^user_id)
    |> maybe_since(since)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> preload([:actor_user, :graph])
    |> Repo.all()
  end

  def list_followed_graph_events(%User{id: user_id}, opts \\ []) do
    since = Keyword.get(opts, :since)
    limit = Keyword.get(opts, :limit, 100)
    include_self? = Keyword.get(opts, :include_self?, false)

    GraphEvent
    |> join(:inner, [e], f in GraphFollow,
      on: f.graph_title == e.graph_title and f.user_id == ^user_id
    )
    |> maybe_since(since)
    |> maybe_exclude_self(user_id, include_self?)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> preload([:actor_user, :graph])
    |> Repo.all()
  end

  def follow_graph(%User{id: user_id} = user, %Graph{title: graph_title} = graph, attrs \\ %{}) do
    result =
      %GraphFollow{}
      |> GraphFollow.changeset(
        attrs
        |> normalize_attrs()
        |> Map.merge(%{"user_id" => user_id, "graph_title" => graph_title})
      )
      |> Repo.insert(
        on_conflict: {:replace, [:frequency, :updated_at]},
        conflict_target: [:user_id, :graph_title]
      )

    case result do
      {:ok, _follow} ->
        record_graph_event(graph, %{
          event_type: "graph.followed",
          actor_user: user,
          summary: "Grid followed"
        })

      {:error, _changeset} ->
        :ok
    end

    result
  end

  def unfollow_graph(%User{id: user_id} = user, %Graph{title: graph_title} = graph) do
    from(f in GraphFollow, where: f.user_id == ^user_id and f.graph_title == ^graph_title)
    |> Repo.delete_all()
    |> case do
      {count, _} when count > 0 ->
        record_graph_event(graph, %{
          event_type: "graph.unfollowed",
          actor_user: user,
          summary: "Grid unfollowed"
        })

      _ ->
        :ok
    end

    :ok
  end

  def list_graph_follows(%User{id: user_id}) do
    GraphFollow
    |> where([f], f.user_id == ^user_id)
    |> order_by([f], desc: f.updated_at)
    |> preload([:graph])
    |> Repo.all()
  end

  def following_graph?(%User{id: user_id}, %Graph{title: graph_title}) do
    from(f in GraphFollow,
      where: f.user_id == ^user_id and f.graph_title == ^graph_title,
      select: true
    )
    |> Repo.exists?()
  end

  def following_graph?(_, _), do: false

  def get_graph_follow(%User{id: user_id}, %Graph{title: graph_title}) do
    Repo.get_by(GraphFollow, user_id: user_id, graph_title: graph_title)
  end

  def get_email_subscriber_by_email(email) when is_binary(email) do
    Repo.get_by(EmailSubscriber, email: normalize_email(email))
  end

  def subscribe_to_updates(attrs, opts \\ []) when is_map(attrs) do
    source = Keyword.get(opts, :source) || Map.get(attrs, "source") || Map.get(attrs, :source)
    user = Keyword.get(opts, :user)
    confirmation_url_fun = Keyword.fetch!(opts, :confirmation_url_fun)

    with {:ok, subscriber} <- upsert_email_subscriber(attrs, source, user),
         {:ok, _email} <-
           Notifier.deliver_confirmation_instructions(
             subscriber,
             confirmation_url_fun.(subscriber.confirmation_token)
           ) do
      {:ok, subscriber}
    end
  end

  def confirm_email_subscription(token) when is_binary(token) do
    with {:ok, hashed_token} <- decode_token(token),
         %EmailSubscriber{} = subscriber <- get_confirmable_subscriber(hashed_token),
         {:ok, subscriber} <- subscriber |> EmailSubscriber.confirm_changeset() |> Repo.update() do
      {:ok, subscriber}
    else
      _ -> :error
    end
  end

  def unsubscribe_email_subscription(token) when is_binary(token) do
    with {:ok, hashed_token} <- decode_token(token),
         %EmailSubscriber{} = subscriber <-
           Repo.get_by(EmailSubscriber, unsubscribe_token: hashed_token),
         {:ok, subscriber} <-
           subscriber |> EmailSubscriber.unsubscribe_changeset() |> Repo.update() do
      {:ok, subscriber}
    else
      _ -> :error
    end
  end

  defp upsert_email_subscriber(attrs, source, user) do
    normalized_attrs = normalize_attrs(attrs)

    case EmailSubscriber.signup_changeset(%EmailSubscriber{}, normalized_attrs) do
      %{valid?: true} = changeset ->
        email = Ecto.Changeset.get_field(changeset, :email)

        case Repo.get_by(EmailSubscriber, email: email) do
          nil -> insert_email_subscriber(normalized_attrs, source, user)
          %EmailSubscriber{} = subscriber -> refresh_email_subscriber(subscriber, source, user)
        end

      changeset ->
        {:error, changeset}
    end
  end

  defp insert_email_subscriber(attrs, source, user) do
    {confirmation_token, confirmation_token_hash} = build_hashed_token()
    {_unsubscribe_token, unsubscribe_token_hash} = build_hashed_token()

    changeset =
      %EmailSubscriber{}
      |> EmailSubscriber.subscription_changeset(attrs)
      |> Ecto.Changeset.put_change(:confirmation_token, confirmation_token_hash)
      |> Ecto.Changeset.put_change(:unsubscribe_token, unsubscribe_token_hash)
      |> Ecto.Changeset.put_change(:source, source)
      |> maybe_put_user(user)

    case Repo.insert(changeset) do
      {:ok, subscriber} -> {:ok, %{subscriber | confirmation_token: confirmation_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp refresh_email_subscriber(%EmailSubscriber{} = subscriber, source, user) do
    {confirmation_token, confirmation_token_hash} = build_hashed_token()

    changeset =
      subscriber
      |> EmailSubscriber.token_changeset(%{
        confirmation_token: confirmation_token_hash,
        unsubscribe_token: subscriber.unsubscribe_token,
        confirmed_at: nil,
        unsubscribed_at: nil,
        source: source || subscriber.source
      })
      |> maybe_put_user(user)

    case Repo.update(changeset) do
      {:ok, subscriber} -> {:ok, %{subscriber | confirmation_token: confirmation_token}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp get_confirmable_subscriber(hashed_token) do
    EmailSubscriber
    |> where([s], s.confirmation_token == ^hashed_token)
    |> where([s], s.updated_at > ago(@confirm_validity_in_days, "day"))
    |> Repo.one()
  end

  defp build_hashed_token do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)
    {Base.url_encode64(token, padding: false), hashed_token}
  end

  defp decode_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} -> {:ok, :crypto.hash(@hash_algorithm, decoded_token)}
      :error -> :error
    end
  end

  defp maybe_since(query, nil), do: query

  defp maybe_since(query, %DateTime{} = since) do
    where(query, [e], e.occurred_at >= ^since)
  end

  defp maybe_since(query, %NaiveDateTime{} = since) do
    where(query, [e], e.occurred_at >= ^since)
  end

  defp maybe_exclude_self(query, _user_id, true), do: query

  defp maybe_exclude_self(query, user_id, false) do
    where(query, [e], is_nil(e.actor_user_id) or e.actor_user_id != ^user_id)
  end

  defp actor_user_id(%User{id: user_id}), do: user_id
  defp actor_user_id(_), do: nil

  defp stringify_metadata(metadata) when is_map(metadata) do
    Enum.into(metadata, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp stringify_metadata(_metadata), do: %{}

  defp normalize_attrs(attrs) do
    Enum.into(attrs, %{}, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      entry -> entry
    end)
  end

  defp normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  defp maybe_put_user(changeset, %User{id: user_id}) do
    Ecto.Changeset.put_change(changeset, :user_id, user_id)
  end

  defp maybe_put_user(changeset, _), do: changeset
end
