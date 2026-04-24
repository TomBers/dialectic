defmodule DialecticWeb.InfographicGalleryLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "gallery page" do
    test "renders the gallery page with all infographics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/gallery")

      assert html =~ "Infographic Gallery"
      assert html =~ "Visual explorations of complex ideas"
      assert html =~ "Consciousness in AI"
      assert html =~ "Utopia"
      assert html =~ "Collective Subconscious"
      assert html =~ "Morality of AI for Lesson Planning"
    end

    test "displays infographic images", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/gallery")

      assert html =~ "/images/infographics/Consciousness_in_AI.jpg"
      assert html =~ "/images/infographics/Utopia.jpg"
      assert html =~ "/images/infographics/collective_subconscious.jpg"
      assert html =~ "/images/infographics/morality_of_ai_for_lesson_planning.jpg"
    end

    test "gallery cards are keyboard accessible", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/gallery")

      assert html =~ ~s(role="button")
      assert html =~ ~s(tabindex="0")
    end

    test "opens modal when clicking an infographic", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Initially, modal should not be visible
      refute has_element?(view, "#infographic-modal")

      # Click on an infographic
      view
      |> element("button[phx-value-id='consciousness_in_ai']")
      |> render_click()

      # Modal should now be visible
      assert has_element?(view, "#infographic-modal")
      assert has_element?(view, "#infographic-modal-title")
    end

    test "modal displays correct infographic details", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Open the Utopia infographic
      html =
        view
        |> element("button[phx-value-id='utopia']")
        |> render_click()

      assert html =~ "Utopia"
      assert html =~ "An exploration of utopian ideals and their implications"
      assert html =~ "Explore Interactive Grid"
    end

    test "closes modal when clicking close button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Open modal
      view
      |> element("button[phx-value-id='collective_subconscious']")
      |> render_click()

      assert has_element?(view, "#infographic-modal")

      # Close modal
      view
      |> element("button[aria-label='Close infographic zoom view']")
      |> render_click()

      refute has_element?(view, "#infographic-modal")
    end

    test "closes modal when clicking backdrop", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Open modal
      view
      |> element("button[phx-value-id='consciousness_in_ai']")
      |> render_click()

      assert has_element?(view, "#infographic-modal")

      # Click backdrop to close
      view
      |> element("div[aria-hidden='true']")
      |> render_click()

      refute has_element?(view, "#infographic-modal")
    end

    test "modal has proper accessibility attributes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Open modal
      html =
        view
        |> element("button[phx-value-id='utopia']")
        |> render_click()

      assert html =~ ~s(role="dialog")
      assert html =~ ~s(aria-modal="true")
      assert html =~ ~s(aria-labelledby="infographic-modal-title")
      assert html =~ ~s(aria-describedby="infographic-modal-description")
    end

    test "explore grid link navigates to correct graph", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      # Open modal
      view
      |> element("button[phx-value-id='consciousness_in_ai']")
      |> render_click()

      # Check that the explore link exists with correct path
      assert has_element?(view, "a[href='/g/consciousness-in-ai']")
    end

    test "back to home link is present", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/gallery")

      assert has_element?(view, "a[href='/']", "Back to Home")
    end
  end
end
