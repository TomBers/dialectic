defmodule Dialectic.QuestionPageFixtures do
  alias Dialectic.QuestionPages

  def admin_fixture do
    Dialectic.AccountsFixtures.user_fixture()
    |> Ecto.Changeset.change(is_admin: true)
    |> Dialectic.Repo.update!()
  end

  def graph_fixture do
    unique = System.unique_integer([:positive])

    Dialectic.GraphFixtures.insert_graph(%{
      title: "Learning question #{unique}",
      data: %{
        "nodes" => [
          %{"id" => "1", "class" => "origin", "content" => "Can practice help us learn?"},
          %{
            "id" => "2",
            "class" => "answer",
            "content" => "## Practice\nTrying a fresh problem can reveal what you understand."
          },
          %{
            "id" => "3",
            "class" => "says_who",
            "content" => "## A limited study\nPerformance on this task improved.",
            "grounding_metadata" => %{
              "google" => %{
                "groundingChunks" => [
                  %{"web" => %{"uri" => "https://example.org/study", "title" => "Study"}}
                ]
              }
            }
          },
          %{
            "id" => "4",
            "class" => "question",
            "content" => "What would count as independent understanding?"
          }
        ],
        "edges" => []
      }
    })
  end

  def selection, do: %{"answer" => "2", "evidence" => ["3"], "paths" => ["4"]}

  def content_attrs(source) do
    %{
      "title" => source["graph_title"],
      "summary" => "Practice can reveal gaps in understanding.",
      "interpretation" => "Try a new example yourself.",
      "uncertainty" => "Transfer to other tasks is not established.",
      "exercise_question" => "How would you check whether you understood?",
      "exercise_answer" => "Try a fresh problem without assistance.",
      "evidence" => sections(source, "evidence"),
      "paths" => sections(source, "paths")
    }
  end

  def draft_fixture(user, graph) do
    {:ok, source, version} = QuestionPages.prepare(user, graph.slug, selection())
    {:ok, page} = QuestionPages.save_generated(user, source, version, content_attrs(source))
    page
  end

  defp sections(source, role) do
    Enum.map(source["selection"][role], fn id ->
      node = Enum.find(source["nodes"], &(&1["id"] == id))

      %{
        "node_id" => id,
        "title" => node["title"],
        "body" => "Read this idea in its original context.",
        "limitation" => "This does not establish a general learning effect.",
        "source_ids" => Enum.map(node["sources"], & &1["id"])
      }
    end)
  end
end
