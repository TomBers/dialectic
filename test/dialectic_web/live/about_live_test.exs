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
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "About RationalGrid"
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
      html = render_async(view)

      assert html =~ "Thank you!"
      assert html =~ "Your feedback has been submitted"
    end
  end
end
