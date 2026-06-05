defmodule Dialectic.GridActivityTest do
  use Dialectic.DataCase, async: false

  import Dialectic.AccountsFixtures

  alias Dialectic.Accounts.User
  alias Dialectic.DbActions.Graphs
  alias Dialectic.GridActivity
  alias Dialectic.GridActivity.{Actions, Log}

  defp unique_title(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}"
  end

  defp activity_node(id \\ "2") do
    %{
      id: id,
      class: "user",
      content: "## A useful comment\n\nThis is useful supporting detail.",
      parents: [
        %{
          id: "1",
          content: "## Parent node"
        }
      ]
    }
  end

  describe "graph creation activity" do
    test "create_new_graph/3 records who created the grid" do
      user = user_fixture()
      title = unique_title("created")

      assert {:ok, graph} = Graphs.create_new_graph(title, user)
      assert graph.title == title

      assert [%Log{} = log] = GridActivity.list_for_graph(title)
      assert log.graph_title == title
      assert log.actor_user_id == user.id
      assert log.actor_name == User.display_name(user)
      assert log.action == Actions.graph_created()
      assert log.metadata == %{"graph_title" => title}
      assert GridActivity.display_message(log) == "#{User.display_name(user)} created this grid."
    end
  end

  describe "recording grid edits" do
    test "records specific node actions and metadata newest first" do
      user = user_fixture()
      title = unique_title("edits")
      assert {:ok, _graph} = Graphs.create_new_graph(title, user)
      node = activity_node("2")

      assert {:ok, %Log{} = created} =
               GridActivity.record_node_comment_created(title, user, node, %{source: :test})

      assert created.action == Actions.node_comment_created()
      assert created.node_id == "2"
      assert created.actor_user_id == user.id
      assert created.metadata["node_class"] == "user"
      assert created.metadata["node_title"] == "A useful comment"
      assert created.metadata["content_snippet"] =~ "This is useful supporting detail."
      assert created.metadata["parent_node_ids"] == ["1"]
      assert created.metadata["parent_node_titles"] == ["Parent node"]
      assert created.metadata["source"] == "test"

      assert {:ok, %Log{} = deleted} = GridActivity.record_node_deleted(title, user, node)
      assert deleted.action == Actions.node_deleted()
      assert deleted.node_id == "2"
      assert deleted.metadata["node_title"] == "A useful comment"

      [latest, previous | _] = GridActivity.list_for_graph(title)
      assert latest.action == Actions.node_deleted()
      assert previous.action == Actions.node_comment_created()
    end

    test "rejects unknown action values" do
      user = user_fixture()
      title = unique_title("invalid-action")
      assert {:ok, _graph} = Graphs.create_new_graph(title, user)

      assert {:error, changeset} =
               GridActivity.record_node_event(title, user, "node.created", activity_node())

      assert {"is invalid", _} = changeset.errors[:action]
    end

    test "counts recent activity on owned graphs with action filtering" do
      owner = user_fixture()
      collaborator = user_fixture()
      owner_title = unique_title("owned")
      other_title = unique_title("not-owned")
      assert {:ok, _graph} = Graphs.create_new_graph(owner_title, owner)
      assert {:ok, _graph} = Graphs.create_new_graph(other_title, collaborator)

      assert {:ok, _log} =
               GridActivity.record_node_comment_created(
                 owner_title,
                 collaborator,
                 activity_node("2")
               )

      assert {:ok, _log} =
               GridActivity.record_node_comment_created(
                 other_title,
                 collaborator,
                 activity_node("3")
               )

      since = DateTime.add(DateTime.utc_now(), -7, :day)

      assert GridActivity.count_for_owned_graphs(owner, since,
               actions: [Actions.node_comment_created()]
             ) == 1

      assert [%Log{graph_title: ^owner_title}] =
               GridActivity.list_for_owned_graphs(owner,
                 since: since,
                 actions: Actions.node_comment_created()
               )
    end
  end
end
