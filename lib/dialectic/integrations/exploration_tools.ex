defmodule Dialectic.Integrations.ExplorationTools do
  @thinking ~w(clarify assumptions counterexample implications blind_spots says_who who_disagrees steel_man what_if)a
  @extra [:explain, :related_ideas, :thesis, :antithesis, :synthesis, :learning_plan]
  @actions Map.new(@thinking ++ @extra, &{Atom.to_string(&1), &1})

  def actions, do: @actions

  def catalog do
    thinking =
      Dialectic.Responses.GuidedLearningPlan.tools()
      |> Enum.filter(&(&1.key in Enum.map(@thinking, fn key -> Atom.to_string(key) end)))
      |> Enum.map(&entry(&1.key, &1.label, &1.description, true))

    thinking ++
      [
        entry(
          "explain",
          "Explain an idea",
          "Explain a node or a selected passage in its context.",
          true
        ),
        entry(
          "related_ideas",
          "Find related ideas",
          "Find useful concepts and new directions connected to this idea.",
          true
        ),
        entry(
          "thesis",
          "Build the supporting case",
          "Develop the strongest reasons supporting this claim. Use with antithesis when comparing cases is useful.",
          true
        ),
        entry(
          "antithesis",
          "Build the challenging case",
          "Develop the strongest reasons against this claim. Opposing views are useful when they illuminate the question.",
          true
        ),
        entry(
          "synthesis",
          "Connect chosen branches",
          "Bring two to five existing nodes together, preserving disagreements and open questions. Supply context_node_ids for the other nodes.",
          false
        ),
        entry(
          "learning_plan",
          "Plan a deeper exploration",
          "Suggest content-specific thinking tools and five follow-up questions, with reasons. Read the plan before choosing which directions to follow.",
          true
        )
      ]
  end

  defp entry(key, label, description, selection?) do
    %{
      action: key,
      label: label,
      description: description,
      selection_supported: selection?,
      tool: if(key == "learning_plan", do: "create_learning_plan", else: "apply_grid_action")
    }
  end
end
