defmodule DialecticWeb.AboutLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the essential about-page content", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/about")

    assert has_element?(view, "#about-team h1#about-team-heading", "The team behind RationalGrid")
    assert has_element?(view, "#about-team", "People behind the project")
    refute has_element?(view, "#about-hero")
    refute has_element?(view, "#about-visible-learning")
    refute has_element?(view, "#about-purpose")
    refute has_element?(view, "#about-tools")
    refute has_element?(view, "#about-audiences")
    assert has_element?(view, "#about-tom-berman", "one of the first engineers at Octopus Energy")

    assert has_element?(
             view,
             ~s(#about-tom-linkedin[href="https://www.linkedin.com/in/tom-berman-213a4711/"])
           )

    assert has_element?(view, "#about-key-facts", "Core offering")

    assert has_element?(
             view,
             ~s(#about-source-link[href="https://github.com/TomBers/dialectic"]),
             "Publicly available on GitHub"
           )

    refute has_element?(view, "#about-faq")
    refute has_element?(view, "#feedback-form")
  end
end
