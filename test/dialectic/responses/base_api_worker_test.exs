defmodule Dialectic.Responses.BaseAPIWorkerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Phoenix.ChannelTest

  @endpoint DialecticWeb.Endpoint

  setup do
    Phoenix.PubSub.subscribe(Dialectic.PubSub, "test_topic")
    :ok
  end

  describe "BaseAPIWorker behavior" do
    test "defines the required callbacks" do
      # Verify that the behavior defines the expected callbacks
      callbacks = Dialectic.Workers.BaseAPIWorker.behaviour_info(:callbacks)

      # Map callbacks to just the names
      callback_names = Enum.map(callbacks, &elem(&1, 0))

      # Check each expected callback exists
      assert :api_key in callback_names
      assert :request_url in callback_names
      assert :headers in callback_names
      assert :build_request_body in callback_names
      assert :parse_chunk in callback_names
      assert :handle_result in callback_names
    end
  end

  describe "error handling" do
    defmodule TestAPIWorker do
      require Logger
      use Oban.Worker, queue: :api_request, max_attempts: 5
      @behaviour Dialectic.Workers.BaseAPIWorker

      @impl true
      def api_key, do: "test_api_key"

      @impl true
      def request_url, do: "https://example.com/api"

      @impl true
      def headers(api_key), do: [{"Authorization", "Bearer #{api_key}"}]

      @impl true
      def build_request_body(question), do: %{prompt: question}

      @impl true
      def parse_chunk(chunk) do
        case chunk do
          "error_chunk" -> {:error, "Test parse error"}
          _ -> {:ok, [%{"test" => "data"}]}
        end
      end

      @impl true
      def handle_result(
            %{"error" => %{"message" => message, "type" => error_type}} = error,
            _graph_id,
            to_node,
            live_view_topic
          ) do
        Logger.error("Test API error: #{inspect(error)}")

        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          live_view_topic,
          {:stream_error, "Error from Test API: #{message} (#{error_type})", :node_id, to_node}
        )

        :ok
      end

      @impl true
      def handle_result(other, _graph, _to_node, _live_view_topic) do
        Logger.info("Regular result: #{inspect(other)}")
        :ok
      end

      @impl Oban.Worker
      defdelegate perform(job), to: Dialectic.Workers.BaseAPIWorker
    end

    test "properly handles API errors in chunks" do
      # Test error in a chunk
      error_chunk = %{"error" => %{"message" => "Test error", "type" => "test_error"}}

      log =
        capture_log(fn ->
          TestAPIWorker.handle_result(error_chunk, "graph_1", "node_1", "test_topic")
          # Wait for the broadcast to complete
          Process.sleep(100)
        end)

      # Check that error was logged
      assert log =~ "Test API error"

      # Check that proper message was broadcast
      assert_receive {:stream_error, message, :node_id, "node_1"}
      assert message =~ "Error from Test API: Test error"
    end

    test "handles parse errors from API responses" do
      # Simulate parsing an error chunk
      log =
        capture_log(fn ->
          result = Dialectic.Responses.Utils.parse_chunk("error_chunk")
          assert {:error, _} = result
        end)

      assert log =~ "Error parsing chunk"
    end

    test "handles organization verification errors from OpenAI" do
      # Create a specific OpenAI organization verification error
      verification_error = %{
        "error" => %{
          "code" => "unsupported_value",
          "message" => "Your organization must be verified to stream this model.",
          "type" => "invalid_request_error"
        }
      }

      # Import the module to test
      worker = Dialectic.Workers.OpenAIWorker

      log =
        capture_log(fn ->
          worker.handle_result(verification_error, "graph_1", "node_1", "test_topic")
          # Wait for the broadcast to complete
          Process.sleep(100)
        end)

      # Check that error was logged
      assert log =~ "OpenAI organization verification error"

      # Check that proper message was broadcast with clear instructions
      assert_receive {:stream_error, message, :node_id, "node_1"}
      assert message =~ "Your OpenAI organization requires verification"
      assert message =~ "https://platform.openai.com/settings/organization/general"
    end
  end
end
