defmodule Dialectic.Integrations.Thinking do
  alias Dialectic.Responses.Prompts

  @methods %{
    "clarify" => {"Clarify terms", :clarify_selection},
    "assumptions" => {"Identify assumptions", :assumptions_selection},
    "counterexample" => {"Find a counterexample", :counterexample_selection},
    "implications" => {"Explore implications", :implications_selection},
    "blind_spots" => {"Find blind spots", :blind_spots_selection},
    "says_who" => {"Examine sources", :says_who_selection},
    "who_disagrees" => {"Explore opposing views", :who_disagrees_selection},
    "steel_man" => {"Steel-man an argument", :steel_man_selection},
    "what_if" => {"Explore a hypothetical", :what_if_selection}
  }

  def get(id) do
    case Map.fetch(@methods, id) do
      {:ok, {title, function}} ->
        {:ok,
         %{
           id: id,
           title: title,
           instructions:
             "Apply this method in your reply to the idea the user selected. Replace {{selected_idea}} with that idea locally; do not send conversation history to RationalGrid. This is method guidance, not a completed analysis. Use the user's preferred depth and concise Markdown. Separate evidence from inference, label hypothetical examples, and never invent sources. Do not create a grid unless asked.",
           prompt_template: apply(Prompts, function, ["", "{{selected_idea}}"])
         }}

      :error ->
        {:error, :not_found}
    end
  end
end
