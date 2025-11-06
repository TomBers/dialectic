defmodule Dialectic.Responses.Mode do
  @moduledoc """
  Lightweight per-graph mode store using ETS.

  - Provides `get_mode/1` and `set_mode/2` helpers.
  - Stores modes by `graph_id` (string).
  - Defaults to `:structured` if no mode is set.
  - Designed to be simple and dependency-free; the ETS table is created on-demand.

  Current supported modes:
    - `:structured` (default)
    - `:creative`

  NOTE: This is an in-memory runtime store and does not persist across restarts.
  """

  @typedoc "Identifier for a graph (graph title/slug used throughout the app)."
  @type graph_id :: String.t()

  @typedoc "Current UI/LLM mode selection."
  @type mode :: :structured | :creative

  @table :dialectic_mode_store
  @default_mode :structured
  @modes [:structured, :creative]

  @doc """
  Returns the currently configured mode for the given `graph_id`.

  Falls back to `:structured` when nothing is configured.
  """
  @spec get_mode(graph_id) :: mode
  def get_mode(graph_id) when is_binary(graph_id) do
    ensure_table!()

    case :ets.lookup(@table, graph_id) do
      [{^graph_id, m}] when m in @modes -> m
      _ -> @default_mode
    end
  end

  @doc """
  Sets the mode for a given `graph_id`.

  Accepts atoms (`:structured` | `:creative`) or their string forms ("structured" | "creative").
  Returns `:ok` on success, or `{:error, reason}` if the mode is invalid.
  """
  @spec set_mode(graph_id, mode | String.t()) :: :ok | {:error, :invalid_mode}
  def set_mode(graph_id, mode) when is_binary(graph_id) do
    ensure_table!()

    with {:ok, normalized} <- normalize_mode(mode) do
      true = :ets.insert(@table, {graph_id, normalized})
      :ok
    end
  end

  @doc """
  Deletes the mode entry for `graph_id`. Subsequent `get_mode/1` calls fall back to the default.

  Returns `:ok` regardless of whether an entry existed.
  """
  @spec delete_mode(graph_id) :: :ok
  def delete_mode(graph_id) when is_binary(graph_id) do
    ensure_table!()
    :ets.delete(@table, graph_id)
    :ok
  end

  @doc """
  Returns the default mode used when no entry exists.
  """
  @spec default_mode() :: mode
  def default_mode, do: @default_mode

  @doc """
  Returns the list of all supported modes.
  """
  @spec supported_modes() :: [mode]
  def supported_modes, do: @modes

  @doc """
  Returns true if the value is a valid mode (atom or string).
  """
  @spec valid?(mode | String.t()) :: boolean
  def valid?(value) do
    case normalize_mode(value) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Returns all current assignments as a list of `{graph_id, mode}`.
  """
  @spec list_modes() :: [{graph_id, mode}]
  def list_modes do
    ensure_table!()
    :ets.tab2list(@table)
  end

  @doc """
  Resets the ETS table (clears all entries). Intended for test usage.
  """
  @spec reset() :: :ok
  def reset do
    case :ets.whereis(@table) do
      :undefined ->
        ensure_table!()
        :ok

      tid when is_reference(tid) ->
        :ets.delete_all_objects(@table)
        :ok
    end
  end

  # -- Internal helpers --------------------------------------------------------

  @spec ensure_table!() :: :ok
  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        _tid =
          :ets.new(@table, [
            :set,
            :named_table,
            :public,
            read_concurrency: true,
            write_concurrency: true
          ])

        :ok

      _tid ->
        :ok
    end
  end

  @spec normalize_mode(mode | String.t()) :: {:ok, mode} | {:error, :invalid_mode}
  defp normalize_mode(mode) when mode in @modes, do: {:ok, mode}

  defp normalize_mode(mode) when is_binary(mode) do
    mode
    |> String.downcase()
    |> String.to_existing_atom()
    |> normalize_mode()
  rescue
    ArgumentError ->
      {:error, :invalid_mode}
  end

  defp normalize_mode(_), do: {:error, :invalid_mode}
end
