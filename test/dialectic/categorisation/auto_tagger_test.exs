defmodule Dialectic.Categorisation.AutoTaggerTest do
  use ExUnit.Case, async: false

  alias Dialectic.Accounts.Graph
  alias Dialectic.Categorisation.AutoTagger

  setup do
    previous_generator = Application.get_env(:dialectic, :llm_generator_module)
    previous_test_pid = Application.get_env(:dialectic, :llm_generator_test_pid)

    Application.put_env(:dialectic, :llm_generator_module, Dialectic.Test.LLMGenerator)
    Application.put_env(:dialectic, :llm_generator_test_pid, self())

    on_exit(fn ->
      restore_env(:llm_generator_module, previous_generator)
      restore_env(:llm_generator_test_pid, previous_test_pid)
    end)

    :ok
  end

  test "uses the Google provider's configured model" do
    graph = %Graph{
      title: "Model selection",
      data: %{
        "nodes" => [
          %{
            "id" => "1",
            "content" => "The origin content",
            "class" => "origin",
            "user" => "",
            "parent" => nil,
            "noted_by" => [],
            "deleted" => false,
            "compound" => false
          }
        ],
        "edges" => []
      }
    }

    assert {:ok, task_pid} = AutoTagger.tag_graph(graph)
    task_ref = Process.monitor(task_pid)

    assert_receive {:llm_generate, prompt, opts}
    assert prompt =~ "Model selection"
    assert opts[:provider] == :google
    refute Keyword.has_key?(opts, :model)
    assert_receive {:DOWN, ^task_ref, :process, ^task_pid, :normal}
  end

  defp restore_env(key, nil), do: Application.delete_env(:dialectic, key)
  defp restore_env(key, value), do: Application.put_env(:dialectic, key, value)
end
