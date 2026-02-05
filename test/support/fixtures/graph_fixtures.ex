defmodule Dialectic.GraphFixtures do
  alias Dialectic.Repo
  alias Dialectic.Accounts.Graph
  alias Dialectic.Graph.Serialise
  alias Dialectic.DbActions.Graphs

  def insert_graph_fixture(graph_name) do
    data =
      case Serialise.load_graph_as_json(graph_name) do
        %{} = m when map_size(m) == 0 -> build_sample_graph(graph_name)
        nil -> build_sample_graph(graph_name)
        other -> other
      end

    insert_data(data, graph_name)
  end

  def insert_data(data, title) do
    slug = Graphs.generate_unique_slug(title)

    graph =
      %Graph{}
      |> Graph.changeset(%{
        title: title,
        user_id: nil,
        data: data,
        is_public: true,
        is_locked: false,
        is_deleted: false,
        is_published: true,
        slug: slug,
        prompt_mode: "university"
      })
      |> Repo.insert!()

    {:ok, graph}
  end

  defp build_sample_graph("What is ethics?") do
    nodes = [
      %{
        "id" => "1",
        "content" => "What is ethics?",
        "class" => "origin",
        "user" => nil,
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      },
      %{
        "id" => "2",
        "content" => "What are the principles of Ethics?",
        "class" => "user",
        "user" => nil,
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      },
      %{
        "id" => "3",
        "content" => "What are the different principles of Ethics?",
        "class" => "user",
        "user" => nil,
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      },
      %{
        "id" => "6",
        "content" => "",
        "class" => "answer",
        "user" => nil,
        "parent" => nil,
        "noted_by" => [],
        "deleted" => false,
        "compound" => false
      }
    ]

    edges = [
      %{"data" => %{"id" => "1_2", "source" => "1", "target" => "2"}},
      %{"data" => %{"id" => "2_3", "source" => "2", "target" => "3"}},
      %{"data" => %{"id" => "3_6", "source" => "3", "target" => "6"}}
    ]

    %{"nodes" => nodes, "edges" => edges}
  end

  defp build_sample_graph(_graph_name) do
    %{
      "nodes" => [],
      "edges" => []
    }
  end
end
