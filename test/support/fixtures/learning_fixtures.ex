defmodule Dialectic.LearningFixtures do
  alias Dialectic.Accounts.Graph
  alias Dialectic.Repo

  def learning_grid_fixture(user, attrs \\ %{}) do
    suffix = System.unique_integer([:positive])

    defaults = %{
      title: "Learning grid #{suffix}",
      slug: "learning-grid-#{suffix}",
      user_id: user.id,
      is_public: true,
      is_published: true,
      is_deleted: false,
      data: %{
        "nodes" => [%{"id" => "1", "content" => "A learning question", "class" => "origin"}],
        "edges" => []
      }
    }

    Repo.insert!(struct!(Graph, Map.merge(defaults, attrs)))
  end
end
