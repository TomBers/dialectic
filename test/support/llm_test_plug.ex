defmodule Dialectic.Test.LLMTestPlug do
  @moduledoc """
  A Plug to mock LLM API responses during tests.
  It detects whether the request targets Google (Gemini) or OpenAI
  and returns the appropriate JSON structure so ReqLLM can parse it.
  """
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    {:ok, body, conn} = read_body(conn)

    # Simple heuristic to detect AutoTagger request
    is_tagging_request = String.contains?(body, "expert librarian and taxonomist")

    mock_text =
      if is_tagging_request do
        # Return valid JSON array for AutoTagger
        "[\"Tag1\", \"Tag2\", \"Tag3\"]"
      else
        "Mocked LLM response for testing."
      end

    resp_body =
      if String.contains?(conn.request_path, "generateContent") do
        # Google (Gemini) format
        ~s({
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": #{inspect(mock_text)}
                  }
                ]
              }
            }
          ]
        })
      else
        # OpenAI / Standard format
        ~s({
          "choices": [
            {
              "message": {
                "content": #{inspect(mock_text)}
              },
              "finish_reason": "stop"
            }
          ],
          "id": "mock-response-id",
          "object": "chat.completion",
          "created": 1677858242,
          "model": "gpt-3.5-turbo-0301",
          "usage": {
            "prompt_tokens": 10,
            "completion_tokens": 10,
            "total_tokens": 20
          }
        })
      end

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp_body)
  end
end
