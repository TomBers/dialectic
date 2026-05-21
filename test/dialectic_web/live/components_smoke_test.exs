defmodule DialecticWeb.ComponentsSmokeTest do
  use DialecticWeb.ConnCase, async: true

  @moduledoc """
  Basic smoke tests for component modules to ensure they are compiled.
  Keeping this intentionally minimal to avoid brittleness.
  """

  import Phoenix.LiveViewTest

  @action_toolbar_mod DialecticWeb.ActionToolbarComp
  @document_menu_mod DialecticWeb.DocumentMenuComp

  describe "ActionToolbarComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@action_toolbar_mod)
    end
  end

  describe "DocumentMenuComp smoke" do
    test "module loads" do
      assert Code.ensure_loaded?(@document_menu_mod)
    end

    test "renders direct help, present, and settings actions" do
      html =
        render_component(@document_menu_mod,
          id: "document-menu",
          graph_id: "graph-123",
          graph_struct: %{title: "Test graph"},
          can_edit: true,
          layout_target: "#graph-layout"
        )

      assert html =~ ~s(id="document-menu-help-document-menu")
      assert html =~ ~s(id="document-menu-present-document-menu")
      assert html =~ ~s(id="document-menu-settings-document-menu")
      assert html =~ "How to use"
      assert html =~ "Present"
      assert html =~ "Settings"
    end
  end

  describe "HighlightsPanelComp" do
    test "renders an obvious add-note action for highlights without notes" do
      highlight = %{
        id: 123,
        node_id: "node_abc123",
        selected_text_snapshot: "important selected text",
        note: nil,
        links: [],
        created_by_user_id: 1
      }

      html =
        render_component(DialecticWeb.HighlightsPanelComp,
          id: "highlights-panel",
          highlights: [highlight],
          current_user: %{id: 1},
          graph_struct: %{slug: "test-graph"},
          node_titles: %{"node_abc123" => "Important idea"}
        )

      assert html =~ ~s(id="highlight-card-123")
      assert html =~ ~s(id="highlight-note-edit-123")
      assert html =~ "Add note"
      assert html =~ "Important idea"
      assert html =~ "Copy link"
      assert html =~ "/g/test-graph?node=node_abc123&amp;highlight=123"
    end

    test "renders a note form with stable controls when a highlight is being edited" do
      highlight = %{
        id: 456,
        node_id: "node_def456",
        selected_text_snapshot: "another selected text",
        note: "Existing note",
        links: [],
        created_by_user_id: 1
      }

      html =
        render_component(DialecticWeb.HighlightsPanelComp,
          id: "highlights-panel",
          highlights: [highlight],
          current_user: %{id: 1},
          graph_struct: %{slug: "test-graph"},
          node_titles: %{"node_def456" => "Another idea"},
          editing_highlight_id: 456
        )

      assert html =~ ~s(id="highlight-note-form-456")
      assert html =~ ~s(id="highlight-note-456")
      assert html =~ "Note"
      assert html =~ "Existing note"
    end

    test "shows summary stats and linked ideas for saved highlights" do
      highlight = %{
        id: 789,
        node_id: "node_ghi789",
        selected_text_snapshot: "linked idea",
        note: "Remember this",
        links: [%{node_id: "node_xyz", link_type: "question"}],
        created_by_user_id: 2
      }

      html =
        render_component(DialecticWeb.HighlightsPanelComp,
          id: "highlights-panel",
          highlights: [highlight],
          current_user: %{id: 2},
          graph_struct: %{slug: "test-graph"},
          node_titles: %{"node_ghi789" => "Linked idea", "node_xyz" => "Open question"},
          visible_node_ids: ["node_ghi789"]
        )

      assert html =~ "Highlights"
      assert html =~ "Question"
      assert html =~ "Open question"
      assert html =~ "Visible in the current view"
    end
  end
end
