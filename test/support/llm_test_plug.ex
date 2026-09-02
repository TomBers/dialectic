defmodule Dialectic.Test.LLMTestPlug do
  @moduledoc """
  A Plug that returns Gemini-compatible mock LLM responses during tests.
  """
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    {:ok, body, conn} = read_body(conn)

    # Simple heuristic to detect AutoTagger request
    tagging_request? = String.contains?(body, "expert librarian and taxonomist")

    mock_text =
      if tagging_request? do
        # Return valid JSON array for AutoTagger
        "[\"Tag1\", \"Tag2\", \"Tag3\"]"
      else
        "Mocked LLM response for testing."
      end

    resp_body =
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

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, resp_body)
  end
end
