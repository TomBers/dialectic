defmodule DialecticWeb.CommunityPeopleTest do
  use DialecticWeb.ConnCase, async: true

  import Dialectic.AccountsFixtures
  import Dialectic.GraphFixtures
  import Phoenix.LiveViewTest

  alias Dialectic.Repo

  test "grid creators link to profiles and topic creators exclude hidden grids and the viewer", %{
    conn: conn
  } do
    viewer = user_fixture()
    creator = user_fixture()
    hidden_creator = user_fixture()
    other_creator = user_fixture()

    grid = owned_grid(creator, "Shared question", ["Sociology"])
    owned_grid(viewer, "My public question", ["Sociology"])
    owned_grid(other_creator, "Biological question", ["Biology"])

    for attrs <- [%{is_public: false}, %{is_published: false}, %{is_deleted: true}] do
      owned_grid(hidden_creator, "Hidden question #{inspect(attrs)}", ["Sociology"], attrs)
    end

    anonymous = insert_graph(%{title: "Anonymous question"})

    {:ok, view, _} = live(log_in_user(conn, viewer), ~p"/community?category=all")

    assert has_element?(
             view,
             ~s(#community-grid-#{grid.slug}-creator[href="/u/#{creator.username}"])
           )

    refute has_element?(view, "#community-grid-#{anonymous.slug}")
    refute has_element?(view, "#community-creators a")

    render_patch(view, ~p"/community?tag=sociology")
    assert has_element?(view, "#creators-#{creator.id}[href='/u/#{creator.username}']")
    refute has_element?(view, "#creators-#{viewer.id}")
    refute has_element?(view, "#creators-#{hidden_creator.id}")
    refute has_element?(view, "#creators-#{other_creator.id}")

    render_patch(view, ~p"/community?tag=biology")
    assert has_element?(view, "#creators-#{other_creator.id}")
    refute has_element?(view, "#creators-#{creator.id}")
  end

  defp owned_grid(user, title, tags, attrs \\ %{}) do
    insert_graph(Map.merge(%{title: title}, attrs))
    |> Ecto.Changeset.change(user_id: user.id, tags: tags)
    |> Repo.update!()
  end
end
