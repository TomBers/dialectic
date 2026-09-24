defmodule Dialectic.AmbassadorsTest do
  use ExUnit.Case, async: false

  import Dialectic.DataCase, only: [errors_on: 1]
  alias Dialectic.Ambassadors

  test "submits normalized email and role to the separate Google Form" do
    Req.Test.expect(Ambassadors, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "docs.google.com"
      assert conn.request_path == "/forms/d/e/ambassador-test/formResponse"
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert URI.decode_query(body) == %{
               "entry.100" => "teacher@example.com",
               "entry.200" => "Educator"
             }

      Plug.Conn.resp(conn, 200, "Recorded")
    end)

    assert {:ok, :submitted} =
             Ambassadors.register_interest(%{email: "  Teacher@Example.com  ", role: "educator"})
  end

  test "Other uses Google Forms' custom response encoding" do
    Req.Test.expect(Ambassadors, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert URI.decode_query(body) == %{
               "entry.100" => "other@example.com",
               "entry.200" => "__other_option__",
               "entry.200.other_option_response" => "Librarian"
             }

      Plug.Conn.resp(conn, 200, "Recorded")
    end)

    assert {:ok, :submitted} =
             Ambassadors.register_interest(%{
               email: "other@example.com",
               role: "other",
               other_role: " Librarian "
             })
  end

  test "Other requires a description before submitting" do
    assert {:error, changeset} =
             Ambassadors.register_interest(%{
               email: "other@example.com",
               role: "other",
               other_role: " "
             })

    assert errors_on(changeset).other_role == ["can't be blank"]
  end

  test "invalid emails and roles never submit" do
    assert {:error, changeset} =
             Ambassadors.register_interest(%{email: "not-an-email", role: "invented"})

    assert errors_on(changeset).email == ["Enter a valid email address"]
    assert errors_on(changeset).role == ["is invalid"]
  end

  test "both email and role are required" do
    assert {:error, changeset} = Ambassadors.register_interest(%{})
    assert errors_on(changeset).email == ["can't be blank"]
    assert errors_on(changeset).role == ["can't be blank"]
  end

  test "rejects oversized email addresses" do
    assert {:error, changeset} =
             Ambassadors.register_interest(%{
               email: String.duplicate("a", 250) <> "@example.com",
               role: "student"
             })

    assert "should be at most 254 character(s)" in errors_on(changeset).email
  end

  test "failed responses and redirects are not treated as success or retried" do
    for status <- [302, 400, 500] do
      Req.Test.expect(Ambassadors, fn conn -> Plug.Conn.resp(conn, status, "Not recorded") end)

      assert {:error, :submission_failed} =
               Ambassadors.register_interest(%{email: "test@example.com", role: "tutor"})
    end
  end

  test "transport errors allow the caller to show a recoverable error" do
    Req.Test.expect(Ambassadors, fn conn -> Req.Test.transport_error(conn, :timeout) end)

    assert {:error, :submission_failed} =
             Ambassadors.register_interest(%{email: "test@example.com", role: "tutor"})
  end

  test "missing configuration prevents submission to any form" do
    original = Application.fetch_env!(:dialectic, Ambassadors)
    on_exit(fn -> Application.put_env(:dialectic, Ambassadors, original) end)
    Application.put_env(:dialectic, Ambassadors, form_url: nil, email_entry: nil, role_entry: nil)

    refute Ambassadors.configured?()

    assert {:error, :not_configured} =
             Ambassadors.register_interest(%{email: "test@example.com", role: "tutor"})
  end
end
