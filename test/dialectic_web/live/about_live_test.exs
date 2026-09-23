defmodule DialecticWeb.AboutLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the essential about-page content", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/about")

    assert has_element?(view, "#about-value-proposition", "AI-assisted visual thinking tool")
    assert has_element?(view, "#about-purpose", "Make learning more rewarding.")
    assert has_element?(view, "#about-tools", "What RationalGrid does")
    assert has_element?(view, "#about-tool-explore", "Explore connected ideas")
    assert has_element?(view, "#about-tool-check", "Check claims and assumptions")
    assert has_element?(view, "#about-tool-keep", "Keep and share the thinking")
    assert has_element?(view, "#about-audiences", "Who RationalGrid is for")
    assert has_element?(view, "#about-team", "The team behind RationalGrid")
    assert has_element?(view, "#about-tom-berman", "one of the first engineers at Octopus Energy")

    assert has_element?(
             view,
             ~s(#about-tom-linkedin[href="https://www.linkedin.com/in/tom-berman-213a4711/"])
           )

    assert has_element?(view, "#about-key-facts", "Core offering")
    assert has_element?(view, ~s(#about-start-grid-link[href="/?focus=grid#start-here"]))

    assert has_element?(
             view,
             ~s(#about-mobile-community-link[href="/community"]),
             "Browse public grids"
           )

    assert has_element?(
             view,
             ~s(#about-source-link[href="https://github.com/TomBers/dialectic"]),
             "Publicly available on GitHub"
           )

    refute has_element?(view, "#about-faq")
    refute has_element?(view, "#feedback-form")
  end
end
