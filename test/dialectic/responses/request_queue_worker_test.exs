defmodule Dialectic.Responses.RequestQueueWorkerTest do
  use DialecticWeb.ConnCase, async: false
  use Oban.Testing, repo: Dialectic.Repo

  alias Dialectic.Responses.RequestQueue

  describe "RequestQueue.add/5 (test env)" do
    test "enqueues LocalWorker job with core args; optional prompt args are ignored" do
      vertex = %Elixir.Dialectic.Graph.Vertex{id: "1"}

      RequestQueue.add("What is dialectics?", "SYSTEM", vertex, "GraphX", "topic-x")

      assert_enqueued(
        worker: Elixir.Dialectic.Workers.LocalWorker,
        queue: "api_request",
        args: %{
          "question" => "What is dialectics?",
          "to_node" => "1",
          "graph" => "GraphX",
          "live_view_topic" => "topic-x"
        }
      )
    end
  end
end
