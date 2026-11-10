defmodule Dialectic.Integrations.GridContentTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.McpFixtures
  alias Dialectic.Integrations.{ChatGrids, GridAction, GridContent}

  test "native regeneration overrides a completed MCP status only in live content" do
    user = user_fixture()
    {:ok, grid} = ChatGrids.create(user, grid_draft())

    Repo.insert!(%GridAction{
      user_id: user.id,
      request_id: Ecto.UUID.generate(),
      graph_title: grid.title,
      action: "clarify",
      parent_node_id: "1",
      node_id: "2",
      status: "completed",
      completed_revision: grid.data_revision
    })

    saved = GridContent.serialize(grid.data, grid.title, grid.data_revision)
    assert Enum.find(saved.nodes, &(&1.id == "2")).generation_status == "completed"

    job =
      %{graph: grid.title, to_node: "2"} |> Dialectic.Workers.LLMWorker.new() |> Oban.insert!()

    job |> Ecto.Changeset.change(state: "executing") |> Repo.update!()
    live = GridContent.serialize(grid.data, grid.title)
    assert Enum.find(live.nodes, &(&1.id == "2")).generation_status == "generating"
    assert Enum.find(live.nodes, &(&1.id == "2")).content_status == "partial"
    assert GridContent.serialize(grid.data, grid.title, grid.data_revision) == saved
  end

  test "parent links are sorted, unique and exclude deleted or dangling sources" do
    nodes =
      for id <- ~w(1 2 3 4),
          do: %{
            "id" => id,
            "content" => "Idea #{id}",
            "class" => "answer",
            "deleted" => id == "4"
          }

    edges =
      for {source, target} <- [
            {"3", "2"},
            {"1", "2"},
            {"1", "2"},
            {"4", "2"},
            {"missing", "2"},
            {"2", "missing"}
          ],
          do: %{"data" => %{"source" => source, "target" => target}}

    result = GridContent.serialize(%{"nodes" => nodes, "edges" => edges}, "parent-filter", 1)
    child = Enum.find(result.nodes, &(&1.id == "2"))
    assert child.parent_node_id == "1"
    assert child.parent_node_ids == ["1", "3"]
    assert result.edges == [%{from: "1", to: "2"}, %{from: "3", to: "2"}]
    assert Enum.map(result.nodes, & &1.id) == ["1", "2", "3"]
  end

  test "serializing a larger connected grid does not perform quadratic work" do
    small = connected_grid(500)
    large = connected_grid(2000)
    GridContent.serialize(connected_grid(50), "complexity-warmup", 1)
    {small_result, small_reductions} = measured_serialize(small)
    {large_result, large_reductions} = measured_serialize(large)

    assert length(small_result.nodes) == 500
    assert length(large_result.nodes) == 2000
    assert length(large_result.edges) == 11_979

    assert List.last(large_result.nodes).parent_node_ids ==
             Enum.map(1994..1999, &Integer.to_string/1)

    assert large_reductions < small_reductions * 8,
           "4x the content used #{large_reductions} reductions versus #{small_reductions} for the smaller grid"
  end

  defp connected_grid(size) do
    nodes =
      for id <- 1..size,
          do: %{
            "id" => Integer.to_string(id),
            "content" => "Connected idea #{id}",
            "class" => "answer"
          }

    edges =
      for target <- 2..size,
          source <- max(1, target - 6)..(target - 1),
          do: %{
            "data" => %{
              "source" => Integer.to_string(source),
              "target" => Integer.to_string(target)
            }
          }

    %{"nodes" => nodes, "edges" => edges}
  end

  defp measured_serialize(data) do
    {:reductions, before_count} = :erlang.process_info(self(), :reductions)
    result = GridContent.serialize(data, "serialization-complexity", 1)
    {:reductions, after_count} = :erlang.process_info(self(), :reductions)
    {result, after_count - before_count}
  end
end
