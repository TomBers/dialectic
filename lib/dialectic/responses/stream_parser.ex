defmodule StreamParser do
  def process_stream({:data, data}, {req, resp}) do
    data
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(&parse_sse_line/1)
    |> Enum.map(&extract_content/1)
    |> Enum.join("")
    |> case do
      "" ->
        {:cont, {req, resp}}

      content ->
        IO.write(content)
        {:cont, {req, resp}}
    end
  end

  defp parse_sse_line(line) do
    line
    |> String.replace_prefix("data: ", "")
    |> String.trim()
    |> case do
      "" -> %{}
      json -> Jason.decode!(json)
    end
  end

  defp extract_content(%{"choices" => [%{"delta" => %{"content" => content}} | _]}) do
    content
  end

  defp extract_content(_), do: ""
end
