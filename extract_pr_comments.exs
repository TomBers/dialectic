Mix.install([
  {:jason, "~> 1.0"}
])

defmodule ExtractPrComments do
  @api_headers [
    "-H",
    "Accept: application/vnd.github+json",
    "-H",
    "X-GitHub-Api-Version: 2026-03-10"
  ]

  @usage """
  Usage:
    elixir extract_pr_comments.exs [options]

  Options:
    --all                 Include comments from all authors. Defaults to Copilot only.
    --file PATH           Read a previously downloaded GitHub comments JSON file.
    --repo OWNER/REPO     Override repository. Defaults to `gh repo view`.
    --pr NUMBER           Override PR number. Defaults to the PR for the current branch.
    --verbose             Include diff hunk, IDs, timestamps, commit info, and position metadata.
    --raw                 Print raw GitHub comment JSON instead of the compact list.

  Examples:
    elixir extract_pr_comments.exs
    elixir extract_pr_comments.exs --verbose
    elixir extract_pr_comments.exs --all
    elixir extract_pr_comments.exs --pr 350
    elixir extract_pr_comments.exs --file copilot_comments.json
  """

  def main(args) do
    if "--help" in args or "-h" in args do
      IO.write(@usage)
      System.halt(0)
    end

    opts = parse_args(args, %{})
    include_all? = Map.get(opts, :all, false)
    raw? = Map.get(opts, :raw, false)
    verbose? = Map.get(opts, :verbose, false)

    comments =
      case Map.get(opts, :file) do
        nil ->
          repo = Map.get(opts, :repo) || gh_repo!()
          pr_number = Map.get(opts, :pr) || gh_current_pr_number!()
          gh_pr_comments!(repo, pr_number)

        file ->
          file
          |> File.read!()
          |> Jason.decode!()
      end

    comments =
      if include_all? do
        comments
      else
        Enum.filter(comments, &copilot_comment?/1)
      end

    output =
      cond do
        raw? -> comments
        verbose? -> Enum.map(comments, &verbose_comment/1)
        true -> Enum.map(comments, &compact_comment/1)
      end

    IO.inspect(output, limit: :infinity, pretty: true)
  end

  defp parse_args([], opts), do: opts

  defp parse_args(["--all" | rest], opts), do: parse_args(rest, Map.put(opts, :all, true))
  defp parse_args(["--verbose" | rest], opts), do: parse_args(rest, Map.put(opts, :verbose, true))
  defp parse_args(["--raw" | rest], opts), do: parse_args(rest, Map.put(opts, :raw, true))
  defp parse_args(["--file", file | rest], opts), do: parse_args(rest, Map.put(opts, :file, file))
  defp parse_args(["--repo", repo | rest], opts), do: parse_args(rest, Map.put(opts, :repo, repo))
  defp parse_args(["--pr", pr | rest], opts), do: parse_args(rest, Map.put(opts, :pr, pr))

  defp parse_args([unknown | _rest], _opts) do
    Mix.raise("Unknown option #{inspect(unknown)}. Run with --help for usage.")
  end

  defp gh_repo! do
    case run_gh(["repo", "view", "--json", "nameWithOwner"]) do
      {:ok, json} ->
        json
        |> Jason.decode!()
        |> Map.fetch!("nameWithOwner")

      {:error, message} ->
        Mix.raise("Could not determine GitHub repository with `gh repo view`: #{message}")
    end
  end

  defp gh_current_pr_number! do
    case run_gh(["pr", "view", "--json", "number,headRefName,url"]) do
      {:ok, json} ->
        json
        |> Jason.decode!()
        |> Map.fetch!("number")
        |> to_string()

      {:error, message} ->
        branch = current_branch()

        Mix.raise("""
        Could not determine the pull request for the current branch#{if branch, do: " #{inspect(branch)}", else: ""}.

        `gh pr view --json number,headRefName,url` failed with:
        #{message}

        If this branch has no open PR, pass one explicitly:
          elixir extract_pr_comments.exs --pr 350
        """)
    end
  end

  defp gh_pr_comments!(repo, pr_number) do
    endpoint = "/repos/#{repo}/pulls/#{pr_number}/comments"

    case run_gh(["api"] ++ @api_headers ++ [endpoint]) do
      {:ok, json} -> Jason.decode!(json)
      {:error, message} -> Mix.raise("Could not fetch PR comments from #{endpoint}: #{message}")
    end
  end

  defp run_gh(args) do
    case System.cmd("gh", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _status} -> {:error, String.trim(output)}
    end
  rescue
    error in ErlangError ->
      {:error, "failed to run gh: #{Exception.message(error)}"}
  end

  defp current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> branch |> String.trim() |> blank_to_nil()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp copilot_comment?(%{"user" => %{"login" => login}}) do
    login in ["Copilot", "copilot-pull-request-reviewer[bot]"]
  end

  defp copilot_comment?(_comment), do: false

  defp compact_comment(comment) do
    %{
      path: comment["path"],
      start_line: comment["start_line"] || comment["line"],
      end_line: comment["line"],
      comment: comment["body"],
      url: comment["html_url"]
    }
  end

  defp verbose_comment(comment) do
    %{
      id: comment["id"],
      review_id: comment["pull_request_review_id"],
      author: get_in(comment, ["user", "login"]),
      path: comment["path"],
      start_line: comment["start_line"] || comment["line"],
      end_line: comment["line"],
      original_start_line: comment["original_start_line"] || comment["original_line"],
      original_line: comment["original_line"],
      side: comment["side"],
      start_side: comment["start_side"],
      subject_type: comment["subject_type"],
      commit_id: comment["commit_id"],
      original_commit_id: comment["original_commit_id"],
      created_at: comment["created_at"],
      updated_at: comment["updated_at"],
      in_reply_to_id: comment["in_reply_to_id"],
      url: comment["html_url"],
      diff_hunk: comment["diff_hunk"],
      comment: comment["body"]
    }
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end

ExtractPrComments.main(System.argv())
