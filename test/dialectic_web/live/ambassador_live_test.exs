defmodule DialecticWeb.AmbassadorLiveTest do
  use DialecticWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Dialectic.Ambassadors

  setup do
    owner = self()

    Req.Test.stub(Ambassadors, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(owner, {:google_submission, URI.decode_query(body)})
      Plug.Conn.resp(conn, 200, "Recorded")
    end)

    :ok
  end

  test "public landing page has a signup form and clear programme information", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    assert has_element?(view, "#amb-hero-title")
    assert has_element?(view, "#amb-hero-join[href='#join-programme']")
    assert has_element?(view, "#how-it-works")
    assert has_element?(view, "#student-referrals")
    assert has_element?(view, "#ambassador-interest-form #interest_email[type='email']")
    assert has_element?(view, "#ambassador-interest-form #interest_role")
    assert has_element?(view, "#amb-faq-earnings", "Rates, eligibility, and payment terms")
    assert has_element?(view, "#amb-faq-launch", "A launch date hasn’t been set yet")
    refute has_element?(view, "#userHeader")
  end

  test "submitting interest sends it to Google Forms and displays confirmation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form",
      interest: %{email: "educator@example.com", role: "educator"}
    )
    |> render_submit()

    assert has_element?(view, "#ambassador-success[role='status']")
    refute has_element?(view, "#ambassador-interest-form")

    assert_received {:google_submission,
                     %{"entry.100" => "educator@example.com", "entry.200" => "Educator"}}
  end

  test "invalid submissions stay editable and do not persist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form", interest: %{email: "invalid", role: "tutor"})
    |> render_submit()

    assert has_element?(view, "#ambassador-interest-form p", "Enter a valid email address")
    refute has_element?(view, "#ambassador-success")
    refute_received {:google_submission, _}

    view
    |> form("#ambassador-interest-form", interest: %{email: "tutor@example.com", role: "tutor"})
    |> render_change()

    refute has_element?(view, "#ambassador-interest-form p", "Enter a valid email address")
  end

  test "student referral action selects the student audience and preserves entered email", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form", interest: %{email: "student@example.com", role: "tutor"})
    |> render_change()

    view |> element("#amb-student-join") |> render_click()

    assert has_element?(view, "#interest_role option[value='student'][selected]")
    assert has_element?(view, "#interest_email[value='student@example.com']")

    view |> form("#ambassador-interest-form") |> render_submit()

    assert_received {:google_submission,
                     %{"entry.100" => "student@example.com", "entry.200" => "Student"}}
  end

  test "Other reveals a role field and submits the description", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")
    refute has_element?(view, "#interest_other_role")

    view
    |> form("#ambassador-interest-form", interest: %{email: "other@example.com", role: "other"})
    |> render_change()

    assert has_element?(view, "#interest_other_role[required]")

    view
    |> form("#ambassador-interest-form", interest: %{other_role: "Librarian"})
    |> render_submit()

    assert has_element?(view, "#ambassador-success")

    assert_received {:google_submission,
                     %{
                       "entry.200" => "__other_option__",
                       "entry.200.other_option_response" => "Librarian"
                     }}
  end

  test "Google Form failure preserves the form and allows a retry", %{conn: conn} do
    Req.Test.stub(Ambassadors, fn conn -> Plug.Conn.resp(conn, 503, "Unavailable") end)
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    view
    |> form("#ambassador-interest-form", interest: %{email: "retry@example.com", role: "tutor"})
    |> render_submit()

    assert has_element?(view, "#ambassador-submit-error[role='alert']")
    assert has_element?(view, "#interest_email[value='retry@example.com']")
    refute has_element?(view, "#ambassador-success")

    Req.Test.stub(Ambassadors, fn conn -> Plug.Conn.resp(conn, 200, "Recorded") end)
    view |> form("#ambassador-interest-form") |> render_submit()
    assert has_element?(view, "#ambassador-success")
  end

  test "the homepage header does not promote the trial", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#ambassador-nav-link")
    refute has_element?(view, "#userHeader a[href='/ambassadors']")
  end

  test "repeated attempts are limited with a recoverable error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ambassadors")

    for _ <- 1..6 do
      view
      |> form("#ambassador-interest-form", interest: %{email: "invalid", role: "educator"})
      |> render_submit()
    end

    assert has_element?(view, "#ambassador-submit-error[role='alert']", "wait a minute")
    assert has_element?(view, "#ambassador-interest-form")
    refute_received {:google_submission, _}
  end
end
