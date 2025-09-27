defmodule Dialectic.Responses.RequestQueueWorkerTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  alias Dialectic.Responses.RequestQueue

  # Dummy modules to exercise BaseAPIWorker branches without doing real HTTP

  defmodule Elixir.Dialectic.Workers.DummyNoKey do
    @behaviour Elixir.Dialectic.Workers.BaseAPIWorker

    def api_key(), do: nil
    def request_url(), do: "http://example.test"
    def headers(_key), do: []
    def build_request_body(_q), do: %{}
    def parse_chunk(_data), do: {:ok, []}
    def handle_result(_chunk, _graph_id, _to_node, _topic), do: :ok
    def request_options(), do: []
  end

  defmodule Elixir.Dialectic.Workers.DummyBadBody do
    @behaviour Elixir.Dialectic.Workers.BaseAPIWorker

    def api_key(), do: "abc"
    def request_url(), do: "http://example.test"
    def headers(_key), do: []
    def build_request_body(_q), do: raise("boom")
    def parse_chunk(_data), do: {:ok, []}
    def handle_result(_chunk, _graph_id, _to_node, _topic), do: :ok
    def request_options(), do: []
  end

  describe "RequestQueue.add/4 (test env)" do
    test "enqueues LocalWorker job with expected args" do
      vertex = %Elixir.Dialectic.Graph.Vertex{id: "1"}

      RequestQueue.add("What is dialectics?", vertex, "GraphX", "topic-x")

      assert_enqueued(
        worker: Elixir.Dialectic.Workers.LocalWorker,
        queue: "api_request",
        args: %{
          "question" => "What is dialectics?",
          "to_node" => "1",
          "graph" => "GraphX",
          "live_view_topic" => "topic-x",
          "module" => "Elixir.Dialectic.Workers.LocalWorker"
        }
      )
    end
  end

  describe "BaseAPIWorker.perform/1 error branches" do
    test "returns {:error, \"API key not configured\"} when api_key/0 is nil" do
      job =
        %Oban.Job{
          args: %{
            "question" => "Q",
            "to_node" => "n1",
            "graph" => "G1",
            "module" => "Elixir.Dialectic.Workers.DummyNoKey",
            "live_view_topic" => "topic"
          }
        }

      _ = Code.ensure_loaded?(Elixir.Dialectic.Workers.DummyNoKey)
      assert {:error, _} = Elixir.Dialectic.Workers.BaseAPIWorker.perform(job)
    end

    test "returns {:error, \"Failed to encode request\"} when build_request_body/1 fails" do
      job =
        %Oban.Job{
          args: %{
            "question" => "Q",
            "to_node" => "n1",
            "graph" => "G1",
            "module" => "Elixir.Dialectic.Workers.DummyBadBody",
            "live_view_topic" => "topic"
          }
        }

      _ = Code.ensure_loaded?(Elixir.Dialectic.Workers.DummyBadBody)

      assert {:error, "Failed to encode request"} =
               Elixir.Dialectic.Workers.BaseAPIWorker.perform(job)
    end
  end
end
