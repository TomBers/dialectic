defmodule Dialectic.Accounts.GravatarCache do
  @moduledoc """
  ETS-based cache for Gravatar profile data with a configurable TTL.

  Prevents redundant external API calls on every profile page mount by
  caching `Gravatar.get_profile_data/1` results. Entries expire after
  a configurable TTL (default: 5 minutes).

  ## Usage

  Start the cache as part of your supervision tree:

      children = [
        ...,
        Dialectic.Accounts.GravatarCache,
        ...
      ]

  Then use `fetch/1` instead of calling `Gravatar.get_profile_data/1` directly:

      case GravatarCache.fetch(gravatar_id) do
        {:ok, profile_data} -> # use cached or freshly fetched data
        {:error, reason}    -> # handle error
      end
  """

  use GenServer

  alias Dialectic.Accounts.Gravatar

  @table :gravatar_cache
  @default_ttl_ms :timer.minutes(5)

  # --- Public API ---

  @doc """
  Starts the cache GenServer and creates the underlying ETS table.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetches Gravatar profile data for the given `gravatar_id`.

  Returns `{:ok, profile_data}` on success (cache hit or fresh fetch)
  or `{:error, reason}` if the Gravatar API call fails and there is no
  cached entry.

  Stale cache entries are served while a background refresh would be
  handled on the next request after expiry — this keeps latency low.
  """
  def fetch(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    ttl = ttl_ms()

    case lookup(gravatar_id) do
      {:ok, data, inserted_at} ->
        if System.monotonic_time(:millisecond) - inserted_at < ttl do
          {:ok, data}
        else
          # Entry is stale — try to refresh, fall back to stale data
          case do_fetch_and_cache(gravatar_id) do
            {:ok, %{avatar_url: url} = fresh} when is_binary(url) and url != "" ->
              {:ok, fresh}

            _ ->
              {:ok, data}
          end
        end

      :miss ->
        do_fetch_and_cache(gravatar_id)
    end
  end

  def fetch(_), do: {:ok, Gravatar.get_profile_data(nil)}

  @doc """
  Invalidates the cached entry for the given `gravatar_id`.

  Useful after a user updates their Gravatar ID in settings so the
  next profile page load fetches fresh data.
  """
  def invalidate(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    try do
      :ets.delete(@table, gravatar_id)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  def invalidate(_), do: :ok

  @doc """
  Returns cached data for the given `gravatar_id` without triggering
  a fetch on cache miss. Useful for synchronous lookups in LiveView
  mounts where you want to apply cached data immediately and only
  start an async fetch if there's no cache entry.

  Returns `{:ok, profile_data}` on cache hit, or `:miss` if the
  entry is not cached (or the table doesn't exist yet).

  Stale entries are still returned — the caller can decide whether
  to trigger a background refresh.
  """
  def get(gravatar_id) when is_binary(gravatar_id) and gravatar_id != "" do
    case lookup(gravatar_id) do
      {:ok, data, _inserted_at} -> {:ok, data}
      :miss -> :miss
    end
  end

  def get(_), do: :miss

  @doc """
  Clears all cached entries. Primarily useful in tests.
  """
  def clear do
    try do
      :ets.delete_all_objects(@table)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  # --- Private helpers ---

  defp lookup(gravatar_id) do
    case :ets.lookup(@table, gravatar_id) do
      [{^gravatar_id, data, inserted_at}] -> {:ok, data, inserted_at}
      [] -> :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp do_fetch_and_cache(gravatar_id) do
    data = Gravatar.get_profile_data(gravatar_id)

    # Only cache if we got at least an avatar URL back (successful fetch)
    if data.avatar_url do
      store(gravatar_id, data)
      {:ok, data}
    else
      # Still return the data (with nils) but don't cache failures
      # so the next request retries
      {:ok, data}
    end
  end

  defp store(gravatar_id, data) do
    now = System.monotonic_time(:millisecond)

    try do
      :ets.insert(@table, {gravatar_id, data, now})
    rescue
      ArgumentError -> :ok
    end
  end

  defp ttl_ms do
    Application.get_env(:dialectic, __MODULE__, [])
    |> Keyword.get(:ttl_ms, @default_ttl_ms)
  end
end
