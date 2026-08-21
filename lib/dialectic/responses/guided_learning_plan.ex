defmodule Dialectic.Responses.GuidedLearningPlan do
  @moduledoc false

  @tools [
    %{
      key: "clarify",
      label: "Clarify terms",
      executor: {:thinking_tool, :clarify},
      icon: "hero-light-bulb",
      description: "What do we mean?"
    },
    %{
      key: "assumptions",
      label: "Surface assumptions",
      executor: {:thinking_tool, :assumptions},
      icon: "hero-cube-transparent",
      description: "What has to be true?"
    },
    %{
      key: "counterexample",
      label: "Test with a counterexample",
      executor: {:thinking_tool, :counterexample},
      icon: "hero-x-mark",
      description: "Is that always true?"
    },
    %{
      key: "implications",
      label: "Explore implications",
      executor: {:thinking_tool, :implications},
      icon: "hero-arrow-trending-up",
      description: "If true, then what?"
    },
    %{
      key: "blind_spots",
      label: "Find blind spots",
      executor: {:thinking_tool, :blind_spots},
      icon: "hero-eye-slash",
      description: "What are we missing?"
    },
    %{
      key: "says_who",
      label: "Check sources",
      executor: {:thinking_tool, :says_who},
      icon: "hero-user",
      description: "Says who?"
    },
    %{
      key: "who_disagrees",
      label: "Consider opposing views",
      executor: {:thinking_tool, :who_disagrees},
      icon: "hero-users",
      description: "Who disagrees?"
    },
    %{
      key: "steel_man",
      label: "Steel-man the argument",
      executor: {:thinking_tool, :steel_man},
      icon: "hero-star",
      description: "Build the strongest argument."
    },
    %{
      key: "what_if",
      label: "Try a what-if",
      executor: {:thinking_tool, :what_if},
      icon: "hero-question-mark-circle",
      description: "Explore a hypothetical scenario."
    },
    %{
      key: "branch",
      label: "Test both sides",
      executor: :branch,
      icon: "hero-scale",
      description: "Compare the strongest case for and against this idea."
    },
    %{
      key: "related_ideas",
      label: "Find related ideas",
      executor: :related_ideas,
      icon: "hero-light-bulb",
      description: "Find concepts and directions connected to this idea."
    }
  ]

  @tools_by_key Map.new(@tools, &{&1.key, &1})
  @tools_by_label Map.new(@tools, &{&1.label, &1})

  def tools, do: @tools
  def labels, do: Enum.map(@tools, & &1.label)

  def fetch(key) when is_binary(key), do: Map.fetch(@tools_by_key, key)
  def fetch(_key), do: :error

  def fetch_by_label(label) when is_binary(label),
    do: Map.fetch(@tools_by_label, String.trim(label))

  def fetch_by_label(_label), do: :error

  def executor(key) do
    case fetch(key) do
      {:ok, tool} -> {:ok, tool.executor}
      :error -> :error
    end
  end

  def result_classes(key) do
    case executor(key) do
      {:ok, :branch} -> ["thesis", "antithesis"]
      {:ok, :related_ideas} -> ["ideas"]
      {:ok, {:thinking_tool, _tool}} -> [key]
      :error -> []
    end
  end

  def actions(content) when is_binary(content) do
    content
    |> parsed_actions()
    |> Enum.take(3)
    |> Enum.with_index()
    |> Enum.map(fn {recommendation, index} ->
      Map.put(recommendation, :recommended, index == 0)
    end)
  end

  def actions(plan) when is_map(plan) do
    case normalize(plan) do
      {:ok, normalized_plan} ->
        normalized_plan.actions
        |> Enum.map(fn action ->
          {:ok, tool} = fetch(action.key)

          %{
            action: tool.key,
            label: tool.label,
            reason: action.reason,
            icon: tool.icon,
            tool_description: tool.description
          }
        end)
        |> Enum.with_index()
        |> Enum.map(fn {recommendation, index} ->
          Map.put(recommendation, :recommended, index == 0)
        end)

      {:error, _errors} ->
        []
    end
  end

  def actions(_content), do: []

  def paths(content) when is_binary(content) do
    content
    |> parsed_paths()
    |> Enum.take(5)
    |> Enum.with_index()
    |> Enum.map(fn {path, index} -> Map.merge(path, %{index: index, disabled: false}) end)
  end

  def paths(plan) when is_map(plan) do
    case normalize(plan) do
      {:ok, normalized_plan} ->
        normalized_plan.paths
        |> Enum.with_index()
        |> Enum.map(fn {path, index} -> Map.merge(path, %{index: index, disabled: false}) end)

      {:error, _errors} ->
        []
    end
  end

  def paths(_content), do: []

  def submission_reserved?(plan, submission_key)
      when is_map(plan) and is_binary(submission_key) do
    plan
    |> value(:reservations)
    |> List.wrap()
    |> Enum.member?(submission_key)
  end

  def submission_reserved?(_plan, _submission_key), do: false

  def resolve(%{guided_plan: guided_plan, content: content}) do
    case normalize(guided_plan) do
      {:ok, plan} -> {:ok, plan}
      {:error, _errors} -> validate(content)
    end
  end

  def resolve(%{"guided_plan" => guided_plan, "content" => content}) do
    resolve(%{guided_plan: guided_plan, content: content})
  end

  def resolve(_node), do: {:error, ["invalid structured learning plan"]}

  def validate(content) when is_binary(content) do
    parsed_actions = parsed_actions(content)
    parsed_paths = parsed_paths(content)
    action_bullets = action_bullet_lines(content)
    path_bullets = path_bullet_lines(content)

    errors =
      []
      |> require_match(
        Regex.match?(~r/^## Learning plan: \S.*$/m, content),
        "missing or invalid learning-plan heading"
      )
      |> require_match(
        heading_count(content, "### Best next actions") == 1,
        "expected exactly one Best next actions heading"
      )
      |> require_match(
        heading_count(content, "### Paths to explore") == 1,
        "expected exactly one Paths to explore heading"
      )
      |> require_match(length(parsed_actions) == 3, "expected exactly three recognised actions")
      |> require_match(length(action_bullets) == 3, "expected exactly three action bullets")
      |> require_match(length(parsed_paths) == 5, "expected exactly five valid paths")
      |> require_match(length(path_bullets) == 5, "expected exactly five path bullets")
      |> require_match(
        Enum.all?(parsed_paths, &(String.length(&1.label) < 40)),
        "path titles must be under 40 characters"
      )
      |> require_match(
        Enum.all?(path_bullets, &(String.length(&1) < 280)),
        "path bullets must be under 280 characters"
      )

    case Enum.reverse(errors) do
      [] ->
        content
        |> build_plan(parsed_actions, parsed_paths)
        |> normalize()

      validation_errors ->
        {:error, validation_errors}
    end
  end

  def validate(_content), do: {:error, ["response must be text"]}

  def normalize(plan) when is_map(plan) do
    version = value(plan, :version)
    title = value(plan, :title)
    actions = value(plan, :actions)
    paths = value(plan, :paths)
    normalized_title = if is_binary(title), do: clean(title)

    with 1 <- version,
         true <- is_binary(normalized_title) and normalized_title != "",
         true <- is_list(actions) and length(actions) == 3,
         true <- is_list(paths) and length(paths) == 5,
         {:ok, normalized_actions} <- normalize_actions(actions),
         {:ok, normalized_paths} <- normalize_paths(paths) do
      {:ok,
       %{
         version: 1,
         title: normalized_title,
         actions: normalized_actions,
         paths: normalized_paths
       }}
    else
      _invalid -> {:error, ["invalid structured learning plan"]}
    end
  end

  def normalize(_plan), do: {:error, ["invalid structured learning plan"]}

  def render(plan) do
    with {:ok, normalized_plan} <- normalize(plan) do
      action_lines =
        Enum.map_join(normalized_plan.actions, "\n", fn action ->
          {:ok, tool} = fetch(action.key)
          "- **#{tool.label}** — #{action.reason}"
        end)

      path_lines =
        Enum.map_join(normalized_plan.paths, "\n", fn path ->
          "- **#{path.label}** — #{path.question} — #{path.reason}"
        end)

      {:ok,
       """
       ## Learning plan: #{normalized_plan.title}
       ### Best next actions
       #{action_lines}
       ### Paths to explore
       #{path_lines}
       """
       |> String.trim()}
    end
  end

  def repair_prompt(original_instruction, invalid_response, errors) do
    error_list = Enum.map_join(errors, "\n", &"- #{&1}")
    invalid_response = String.slice(to_string(invalid_response), 0, 8_000)

    """
    The previous learning-plan response failed validation. Rewrite it completely.

    Validation failures:
    #{error_list}

    Follow the original task exactly:
    #{original_instruction}

    Invalid response to replace:
    <<<BEGIN INVALID RESPONSE>>>
    #{invalid_response}
    <<<END INVALID RESPONSE>>>

    Return only the corrected learning plan. Do not discuss the validation failures.
    """
  end

  defp parse_action(line) do
    case Regex.run(~r/^\s*(?:[-*+]|\d+[.)])\s+\*\*(.+?)\*\*\s+—\s+(.+?)\s*$/u, line) do
      [_, label, reason] ->
        case fetch_by_label(label) do
          {:ok, tool} ->
            [
              %{
                action: tool.key,
                label: tool.label,
                reason: clean(reason),
                icon: tool.icon,
                tool_description: tool.description
              }
            ]

          :error ->
            []
        end

      _no_match ->
        []
    end
  end

  defp parse_path(line) do
    case Regex.run(
           ~r/^\s*(?:[-*+]|\d+[.)])\s+\*\*(.+?)\*\*\s+—\s+(.+\?)\s+—\s+(.+?)\s*$/u,
           line
         ) do
      [_, label, question, reason] ->
        [%{label: clean(label), question: clean(question), reason: clean(reason)}]

      _no_match ->
        []
    end
  end

  defp build_plan(content, parsed_actions, parsed_paths) do
    %{
      version: 1,
      title: extract_title(content),
      actions:
        Enum.map(parsed_actions, fn action ->
          %{key: action.action, reason: action.reason}
        end),
      paths:
        parsed_paths
        |> Enum.with_index(1)
        |> Enum.map(fn {path, index} ->
          %{
            id: "path-#{index}",
            label: path.label,
            question: path.question,
            reason: path.reason
          }
        end)
    }
  end

  defp extract_title(content) do
    case Regex.run(~r/^## Learning plan:\s*(.+?)\s*$/m, content) do
      [_, title] -> clean(title)
      _no_title -> "Learning plan"
    end
  end

  defp normalize_actions(actions) do
    normalized =
      Enum.flat_map(actions, fn action ->
        key = value(action, :key)
        reason = value(action, :reason)
        normalized_reason = if is_binary(reason), do: clean(reason)

        if is_binary(key) and is_binary(normalized_reason) and normalized_reason != "" and
             match?({:ok, _}, fetch(key)) do
          [%{key: key, reason: normalized_reason}]
        else
          []
        end
      end)

    if length(normalized) == 3 and Enum.uniq_by(normalized, & &1.key) == normalized,
      do: {:ok, normalized},
      else: {:error, :invalid_actions}
  end

  defp normalize_paths(paths) do
    normalized =
      paths
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {path, index} ->
        id = value(path, :id)
        label = value(path, :label)
        question = value(path, :question)
        reason = value(path, :reason)
        normalized_label = if is_binary(label), do: clean(label)
        normalized_question = if is_binary(question), do: clean(question)
        normalized_reason = if is_binary(reason), do: clean(reason)

        if is_binary(id) and id == "path-#{index}" and is_binary(normalized_label) and
             normalized_label != "" and String.length(normalized_label) < 40 and
             is_binary(normalized_question) and String.ends_with?(normalized_question, "?") and
             is_binary(normalized_reason) and normalized_reason != "" do
          [
            %{
              id: id,
              label: normalized_label,
              question: normalized_question,
              reason: normalized_reason
            }
          ]
        else
          []
        end
      end)

    unique_ids? = Enum.uniq_by(normalized, & &1.id) == normalized
    unique_questions? = Enum.uniq_by(normalized, &normalize_question(&1.question)) == normalized

    if length(normalized) == 5 and unique_ids? and unique_questions?,
      do: {:ok, normalized},
      else: {:error, :invalid_paths}
  end

  defp value(map, key) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp value(_map, _key), do: nil

  defp parsed_actions(content) do
    content
    |> section_lines("### Best next actions", "### Paths to explore")
    |> Enum.flat_map(&parse_action/1)
    |> Enum.uniq_by(& &1.action)
  end

  defp parsed_paths(content) do
    content
    |> section_lines("### Paths to explore", nil)
    |> Enum.flat_map(&parse_path/1)
    |> Enum.uniq_by(&normalize_question(&1.question))
  end

  defp section_lines(content, start_heading, end_heading) do
    lines = String.split(content, ~r/\r\n|\r|\n/)

    case Enum.find_index(lines, &(String.trim(&1) == start_heading)) do
      nil ->
        []

      start_index ->
        lines
        |> Enum.drop(start_index + 1)
        |> take_until_heading(end_heading)
    end
  end

  defp take_until_heading(lines, nil), do: lines

  defp take_until_heading(lines, heading) do
    Enum.take_while(lines, &(String.trim(&1) != heading))
  end

  defp path_bullet_lines(content) do
    section_lines(content, "### Paths to explore", nil)
    |> Enum.filter(&Regex.match?(~r/^\s*(?:[-*+]|\d+[.)])\s+/, &1))
  end

  defp action_bullet_lines(content) do
    section_lines(content, "### Best next actions", "### Paths to explore")
    |> Enum.filter(&Regex.match?(~r/^\s*(?:[-*+]|\d+[.)])\s+/, &1))
  end

  defp heading_count(content, heading) do
    content
    |> String.split(~r/\r\n|\r|\n/)
    |> Enum.count(&(String.trim(&1) == heading))
  end

  defp require_match(errors, true, _message), do: errors
  defp require_match(errors, false, message), do: [message | errors]

  defp clean(value) do
    value
    |> String.replace(~r/(\*\*|__|`)/, "")
    |> String.trim()
    |> String.slice(0, 500)
  end

  defp normalize_question(question) do
    question
    |> to_string()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.downcase()
  end
end
