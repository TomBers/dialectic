defmodule DialecticWeb.HomeCreationTest do
  use DialecticWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Dialectic.AccountsFixtures

  alias Dialectic.DbActions.Graphs

  test "legacy creation links keep their collection and question", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: path}}} =
             live(conn, ~p"/?focus=grid&collection=42&initial_prompt=A%20question")

    assert URI.parse(path).path == "/my/learning"

    assert URI.decode_query(URI.parse(path).query) == %{
             "new" => "true",
             "collection" => "42",
             "initial_prompt" => "A question"
           }
  end

  test "legacy draft links resume in private creation", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/?resume=grid")
    assert URI.parse(path).path == "/my/learning"
    assert URI.decode_query(URI.parse(path).query) == %{"new" => "true", "resume" => "grid"}
  end

  test "simultaneous creations of the same question produce distinct grids" do
    title = "Concurrent creation #{System.unique_integer([:positive])}"
    owner = user_fixture()

    graphs =
      1..4
      |> Task.async_stream(fn _ -> Graphs.create_unique_graph(title, owner, "expert") end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {:ok, graph}} -> graph end)

    assert length(Enum.uniq_by(graphs, & &1.title)) == 4
    assert length(Enum.uniq_by(graphs, & &1.slug)) == 4
    assert Enum.all?(graphs, &(&1.user_id == owner.id && &1.prompt_mode == "expert"))
  end
end
