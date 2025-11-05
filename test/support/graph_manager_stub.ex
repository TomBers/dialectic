defmodule Dialectic.TestSupport.GraphManagerStub do
  @moduledoc """
  A lightweight, shared stub for GraphManager context-building used in tests.

  Why
  - Some prompt-composition tests only need a deterministic context string.
  - Redefining `GraphManager` in multiple test files causes duplicate module definition errors.
  - This stub provides a single, reusable module to return a predictable context.

  Usage in tests
  - Call the stub directly in places where you would otherwise redefine GraphManager:
      Dialectic.TestSupport.GraphManagerStub.build_context("graph", node)
      Dialectic.TestSupport.GraphManagerStub.build_context("graph", node, 5000)

  - Optionally set a custom context string for the duration of a test:
      Dialectic.TestSupport.GraphManagerStub.with_context("DEMO_CONTEXT", fn ->
        # ... run assertions that rely on the context ...
      end)

    or globally for the test process:
      :ok = Dialectic.TestSupport.GraphManagerStub.put_context("DEMO_CONTEXT")
      on_exit(fn -> Dialectic.TestSupport.GraphManagerStub.reset_context() end)

  Notes
  - This does NOT replace or redefine the real GraphManager.
  - Tests should explicitly call this stub when they need deterministic context.
  """

  @app :dialectic
  @env_key :graph_manager_stub_context
  @default_context "TEST_CONTEXT"

  @doc """
  Returns the current stub context, defaulting to #{@default_context} if not set.
  """
  def current_context do
    Application.get_env(@app, @env_key, @default_context)
  end

  @doc """
  Sets the stub context for subsequent calls to `build_context/2,3` in this BEAM instance.
  The setting is not persistent and intended for test runtime only.
  """
  @spec put_context(String.t()) :: :ok
  def put_context(value) when is_binary(value) do
    Application.put_env(@app, @env_key, value, persistent: false)
    :ok
  end

  @doc """
  Clears any custom stub context, returning to the default of #{@default_context}.
  """
  @spec reset_context() :: :ok
  def reset_context do
    Application.delete_env(@app, @env_key)
    :ok
  end

  @doc """
  Runs `fun` with a temporary stub context, restoring the previous value afterwards.
  """
  @spec with_context(String.t(), (-> any)) :: any
  def with_context(value, fun) when is_function(fun, 0) and is_binary(value) do
    prev = Application.get_env(@app, @env_key)
    Application.put_env(@app, @env_key, value, persistent: false)

    try do
      fun.()
    after
      case prev do
        nil -> Application.delete_env(@app, @env_key)
        _ -> Application.put_env(@app, @env_key, prev, persistent: false)
      end
    end
  end

  @doc """
  Minimal stub equivalent for `GraphManager.build_context/2` expected by prompt code.
  """
  @spec build_context(any, any) :: String.t()
  def build_context(_graph_id, _node), do: current_context()

  @doc """
  Minimal stub equivalent for `GraphManager.build_context/3` expected by prompt code.
  """
  @spec build_context(any, any, any) :: String.t()
  def build_context(_graph_id, _node, _limit), do: current_context()
end
