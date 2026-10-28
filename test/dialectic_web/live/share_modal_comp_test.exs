defmodule DialecticWeb.ShareModalCompTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Dialectic.Accounts.Graph
  alias Dialectic.GraphFixtures
  alias Dialectic.Repo
  alias DialecticWeb.ShareModalComp

  describe "share links" do
    test "share modal opens reader links by default without image download controls" do
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
          DialecticWeb.GraphPathHelper.graph_path(graph)

      assert html =~ ~s(value="#{expected_url}")
      document = LazyHTML.from_fragment(html)
      assert LazyHTML.query(document, "#share-copy-btn") |> Enum.count() == 1
      assert LazyHTML.query(document, "#share-social-whatsapp") |> Enum.count() == 1

      assert LazyHTML.query(document, "#share-image-options, #share-download-image, canvas")
             |> Enum.count() == 0
    end

    test "reader share keeps link sharing without image downloads" do
      graph = GraphFixtures.insert_graph(%{title: "Reader Share Modal Graph", is_public: true})

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
          share_node: true,
          share_target: :reader,
          show_preview: false
        )

      document = LazyHTML.from_fragment(html)
      assert LazyHTML.query(document, "#share-copy-btn, #share-social-email") |> Enum.count() == 2
      assert LazyHTML.query(document, "#share-download-image, canvas") |> Enum.count() == 0
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
      document = LazyHTML.from_fragment(html)
      assert LazyHTML.query(document, "#share-social-whatsapp") |> Enum.count() == 1
      assert LazyHTML.query(document, "#share-social-email") |> Enum.count() == 1
      assert LazyHTML.query(document, "#share-social-x") |> Enum.count() == 0
      assert LazyHTML.query(document, "#share-social-linkedin") |> Enum.count() == 0
    end

    test "share modal keeps quote-specific URLs and sharing text for highlights" do
      graph = GraphFixtures.insert_graph(%{title: "Quote Share Modal Graph", is_public: true})

      selected_highlight = %{
        id: 77,
        node_id: "5",
        selected_text_snapshot:
          "Philosophy is a battle against the bewitchment of our intelligence by means of language."
      }

      html =
        render_component(ShareModalComp,
          id: "share-modal",
          show: true,
          graph_struct: graph,
          current_user: nil,
          selected_node: %{id: "1"},
          selected_highlight: selected_highlight,
          presentation_mode: :off,
          presentation_slide_ids: [],
          presentation_title: "",
          share_node: false,
          share_target: :reader,
          show_preview: false
        )

      expected_url =
        DialecticWeb.Endpoint.url() <>
          DialecticWeb.GraphPathHelper.graph_path(graph, "5", highlight: 77)

      escaped_expected_url =
        expected_url
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      assert html =~ "Share Quote"
      assert html =~ "Quote Share Link"
      assert html =~ ~s(value="#{escaped_expected_url}")
      assert html =~ "Philosophy is a battle against the bewitchment"
      document = LazyHTML.from_fragment(html)
      assert LazyHTML.query(document, "#share-download-image, canvas") |> Enum.count() == 0
      assert html =~ "Quote link copied to clipboard!"
      refute html =~ "Link to current node"
    end
  end
end
