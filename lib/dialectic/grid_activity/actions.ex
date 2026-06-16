defmodule Dialectic.GridActivity.Actions do
  @graph_created "graph.created"
  @node_comment_created "node.comment.created"
  @node_follow_up_created "node.follow_up.created"
  @node_branch_created "node.branch.created"
  @node_synthesis_created "node.synthesis.created"
  @node_related_ideas_created "node.related_ideas.created"
  @node_selection_explained "node.selection_explained"
  @node_selection_question_created "node.selection_question.created"
  @node_deep_dive_created "node.deep_dive.created"
  @node_critical_tool_created "node.critical_tool.created"
  @node_starting_point_created "node.starting_point.created"
  @node_regenerated "node.regenerated"
  @node_deleted "node.deleted"

  @valid_actions [
    @graph_created,
    @node_comment_created,
    @node_follow_up_created,
    @node_branch_created,
    @node_synthesis_created,
    @node_related_ideas_created,
    @node_selection_explained,
    @node_selection_question_created,
    @node_deep_dive_created,
    @node_critical_tool_created,
    @node_starting_point_created,
    @node_regenerated,
    @node_deleted
  ]

  def valid_actions, do: @valid_actions

  def graph_created, do: @graph_created
  def node_comment_created, do: @node_comment_created
  def node_follow_up_created, do: @node_follow_up_created
  def node_branch_created, do: @node_branch_created
  def node_synthesis_created, do: @node_synthesis_created
  def node_related_ideas_created, do: @node_related_ideas_created
  def node_selection_explained, do: @node_selection_explained
  def node_selection_question_created, do: @node_selection_question_created
  def node_deep_dive_created, do: @node_deep_dive_created
  def node_critical_tool_created, do: @node_critical_tool_created
  def node_starting_point_created, do: @node_starting_point_created
  def node_regenerated, do: @node_regenerated
  def node_deleted, do: @node_deleted

  def for_graph_operation("comment"), do: @node_comment_created
  def for_graph_operation("user"), do: @node_comment_created
  def for_graph_operation("answer"), do: @node_follow_up_created
  def for_graph_operation("branch"), do: @node_branch_created
  def for_graph_operation("combine"), do: @node_synthesis_created
  def for_graph_operation("ideas"), do: @node_related_ideas_created
  def for_graph_operation("explain"), do: @node_selection_explained
  def for_graph_operation("selection_question"), do: @node_selection_question_created
  def for_graph_operation("deepdive"), do: @node_deep_dive_created

  def for_graph_operation(operation)
      when operation in [
             "clarify",
             "assumptions",
             "counterexample",
             "implications",
             "blind_spots",
             "says_who",
             "who_disagrees",
             "steel_man",
             "what_if"
           ],
      do: @node_critical_tool_created

  def for_graph_operation("start_stream"), do: @node_starting_point_created
  def for_graph_operation("regenerate"), do: @node_regenerated
  def for_graph_operation(_operation), do: nil
end
