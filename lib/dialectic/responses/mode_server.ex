defmodule Dialectic.Responses.ModeServer do
  @moduledoc """
  GenServer that owns the ETS table used to persist the per-graph prompt mode
  (e.g., `:university`, `:high_school`, or `:eli5`) for the duration of the BEAM session.

  Why this exists:
  - Centralizes creation/ownership of the ETS table to avoid scattered, ad-hoc creation.
  - Provides a small synchronous API to read/write modes via the server process.
  - Plays nicely with direct ETS access from other modules that reference the same table.

  Notes:
  - This is runtime persistence only (survives page refresh, resets across full app restarts).
  - To enable from boot, add this server to your supervision tree:
      {Dialectic.Responses.ModeServer, []}
  """

  use GenServer

  @typedoc "Identifier for a graph (graph title/slug used throughout the app)."
  @type graph_id :: String.t()

  @typedoc "Current UI/LLM mode selection."
  @type mode :: :university | :high_school | :eli5

  @table :dialectic_mode_store
  @default_mode :university
  @modes [:university, :high_school, :eli5]

  # -- Public API --------------------------------------------------------------

  @doc """
  Starts the ModeServer.

  Recommended to be supervised with a permanent restart strategy.
  """
  @spec start_link(term) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns the mode for the given `graph_id`. Falls back to `:structured` when unset.
  """
  @spec get_mode(graph_id) :: mode
  def get_mode(graph_id) when is_binary(graph_id) do
    GenServer.call(__MODULE__, {:get_mode, graph_id})
  end

  @doc """
  Sets the mode for a given `graph_id`.

  Accepts atoms (`:university` | `:high_school` | `:eli5`) or strings.
  Returns `:ok` or `{:error, :invalid_mode}` if the value isn't supported.
  """
  @spec set_mode(graph_id, mode | String.t()) :: :ok | {:error, :invalid_mode}
  def set_mode(graph_id, value) when is_binary(graph_id) do
    GenServer.call(__MODULE__, {:set_mode, graph_id, value})
  end

  @doc """
  Deletes the mode entry for `graph_id`. Subsequent `get_mode/1` calls will return the default.
  """
  @spec delete_mode(graph_id) :: :ok
  def delete_mode(graph_id) when is_binary(graph_id) do
    GenServer.call(__MODULE__, {:delete_mode, graph_id})
  end

  @doc """
  Lists all `{graph_id, mode}` assignments currently in the ETS table.
  """
  @spec list_modes() :: [{graph_id, mode}]
  def list_modes do
    GenServer.call(__MODULE__, :list_modes)
  end

  @doc "Returns the default mode (`:university`)."
  @spec default_mode() :: mode
  def default_mode, do: @default_mode

  @doc "Returns the list of supported modes."
  @spec supported_modes() :: [mode]
  def supported_modes, do: @modes

  # -- GenServer callbacks -----------------------------------------------------

  @impl true
  def init(:ok) do
    ensure_table!()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_mode, graph_id}, _from, state) when is_binary(graph_id) do
    ensure_table!()

    mode =
      case :ets.lookup(@table, graph_id) do
        [{^graph_id, m}] when m in @modes -> m
        _ -> @default_mode
      end

    {:reply, mode, state}
  end

  @impl true
  def handle_call({:set_mode, graph_id, value}, _from, state) when is_binary(graph_id) do
    ensure_table!()

    case normalize_mode(value) do
      {:ok, normalized} ->
        true = :ets.insert(@table, {graph_id, normalized})
        {:reply, :ok, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call({:delete_mode, graph_id}, _from, state) when is_binary(graph_id) do
    ensure_table!()
    :ets.delete(@table, graph_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list_modes, _from, state) do
    ensure_table!()
    {:reply, :ets.tab2list(@table), state}
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
  defp normalize_mode(value) when value in @modes, do: {:ok, value}

  defp normalize_mode(value) when is_binary(value) do
    case String.downcase(value) do
      "university" -> {:ok, :university}
      "high_school" -> {:ok, :high_school}
      "eli5" -> {:ok, :eli5}
      "structured" -> {:ok, :university}
      "creative" -> {:ok, :high_school}
      _ -> {:error, :invalid_mode}
    end
  end

  defp normalize_mode(_), do: {:error, :invalid_mode}
end
