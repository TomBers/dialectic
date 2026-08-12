defmodule DialecticWeb.AboutLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    Req.Test.stub(Dialectic.Feedback, fn conn ->
      Req.Test.json(conn, %{status: "ok"})
    end)

    :ok
  end

  describe "about page" do
    test "renders the about page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/about")

      assert html =~ "About RationalGrid"
      refute has_element?(view, "#about-connected-knowledge")

      assert has_element?(
               view,
               "#about-ai-artifacts",
               "AI helps you explore. The grid helps you remember."
             )

      assert has_element?(
               view,
               ~s(#about-ai-exploration-link[href="/intro/ai"]),
               "Read about AI and exploration"
             )

      assert has_element?(view, "#about-audiences", "Who is it for?")
      assert has_element?(view, "#about-audience-students", "Students and lifelong learners")
      assert has_element?(view, "#about-audience-teachers", "Teachers and tutors")

      assert has_element?(
               view,
               "#about-audience-researchers-writers",
               "Researchers, journalists, and writers"
             )

      assert has_element?(view, "#about-audience-debate-organisers", "Debate and discussion")
      assert has_element?(view, "#about-audience-teams", "Teams and decision-makers")
      assert has_element?(view, "#about-audience-book-clubs", "Book clubs and study groups")

      assert has_element?(
               view,
               "#about-audience-critical-thinkers",
               "Philosophers and critical thinkers"
             )

      assert has_element?(view, ~s(#about-start-grid-link[href="/?focus=grid#start-here"]))
    end

    test "shows error when submitting blank feedback", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      html =
        view
        |> form("#feedback-form", feedback: %{feedback: ""})
        |> render_submit()

      assert html =~ "Please enter some feedback before submitting."
    end

    test "shows thank you state after successful feedback submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/about")

      view
      |> form("#feedback-form", feedback: %{feedback: "Great tool, love using it!"})
      |> render_submit()

      # The submission is async, so we need to wait for the async task to complete
      html = render_async(view, 1_000)

      assert html =~ "Thank you!"
      assert html =~ "Your feedback has been submitted"
    end
  end
end
