defmodule Mix.Tasks.Llm.Benchmark do
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          model: :string,
          thinking: :string,
          case: :string,
          limit: :integer,
          concurrency: :integer,
          output: :string
        ]
      )

    if rest != [] or invalid != [],
      do:
        Mix.raise(
          "Use --model MODEL, --thinking minimal|low|medium|high, --case ID, --limit N, --concurrency 1..4 or --output PATH"
        )

    Mix.Task.run("app.start")
    report = Dialectic.Evaluation.AnswerBenchmark.run(opts)

    output =
      Keyword.get(opts, :output, "tmp/answer-benchmark-#{System.system_time(:second)}.json")

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(report, pretty: true))

    Mix.shell().info(
      "Saved #{length(report.results)} results to #{output}. Accuracy and source support require review against each case's rubric."
    )
  end
end
