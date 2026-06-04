defmodule Dialectic.GridActivityTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts.User
  alias Dialectic.DbActions.Graphs
  alias Dialectic.GridActivity
  alias Dialectic.GridActivity.Log

  defp unique_title(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end

  describe "graph creation activity" do
    test "create_new_graph/3 records who created the grid" do
      user = user_fixture()
      title = unique_title("created")

      assert {:ok, graph} = Graphs.create_new_graph(title, user)
      assert graph.title == title

      assert [%Log{} = log] = GridActivity.list_for_graph(title)
      assert log.graph_title == title
      assert log.user_id == user.id
      assert log.actor_name == User.display_name(user)
      assert log.action == "graph.created"
      assert log.message == "#{User.display_name(user)} created this grid."
    end
  end

  describe "recording grid edits" do
    test "records node creation and deletion messages newest first" do
      user = user_fixture()
      title = unique_title("edits")
      assert {:ok, _graph} = Graphs.create_new_graph(title, user)

      assert {:ok, %Log{} = created} =
               GridActivity.record_node_created(
                 title,
                 user,
                 "#{User.display_name(user)} added a comment.",
                 "2"
               )

      assert created.action == "node.created"
      assert created.node_id == "2"

      assert {:ok, %Log{} = deleted} = GridActivity.record_node_deleted(title, user, "2")
      assert deleted.action == "node.deleted"
      assert deleted.node_id == "2"

      [latest, previous | _] = GridActivity.list_for_graph(title)
      assert latest.action == "node.deleted"
      assert previous.action == "node.created"
    end
  end
end
