defmodule DialecticWeb.ShareModalCompTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.Accounts.Graph
  alias Dialectic.GraphFixtures
  alias Dialectic.Repo
  alias DialecticWeb.ShareModalComp

  describe "share links" do
    test "share modal links to the graph view by default" do
      graph = GraphFixtures.insert_graph(%{title: "Share Modal Graph"})

      html =
        render_component(ShareModalComp,
          id: "share-modal",
          show: true,
          graph_struct: graph,
          current_user: nil,
          selected_node: %{id: "1"},
          presentation_mode: :off,
          presentation_slide_ids: [],
          presentation_title: "",
          share_node: false
        )

      expected_url =
        DialecticWeb.Endpoint.url() <>
          DialecticWeb.GraphPathHelper.graph_editor_path(graph)

      assert html =~ ~s(value="#{expected_url}")
    end

    test "share modal keeps graph mode for node and presentation links" do
      graph =
        GraphFixtures.insert_graph(%{
          title: "Private Share Modal Graph",
          is_public: false
        })
        |> Graph.changeset(%{share_token: "secret-token"})
        |> Repo.update!()

      html =
        render_component(ShareModalComp,
          id: "share-modal",
          show: true,
          graph_struct: graph,
          current_user: nil,
          selected_node: %{id: "9"},
          presentation_mode: :presenting,
          presentation_slide_ids: ["9", "12"],
          presentation_title: "My Talk",
          share_node: true
        )

      expected_url =
        DialecticWeb.Endpoint.url() <>
          DialecticWeb.GraphPathHelper.graph_editor_path(graph, "9", [
            {"title", "My Talk"},
            {"present", "true"},
            {"slides", "9,12"}
          ])

      escaped_expected_url =
        expected_url
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      assert html =~ ~s(value="#{escaped_expected_url}")
    end
  end
end
