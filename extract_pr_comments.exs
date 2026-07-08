Mix.install([
  :req,
  {:jason, "~> 1.0"}
])

"copilot_comments.json"
|> File.read!()
|> Jason.decode!()
|> Enum.map(fn comment ->
  %{
    path: comment["path"],
    start_line: comment["start_line"],
    end_line: comment["end_line"],
    comment: comment["body"]
  }
end)
|> IO.inspect()
