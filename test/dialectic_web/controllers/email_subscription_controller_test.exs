defmodule DialecticWeb.EmailSubscriptionControllerTest do
  use DialecticWeb.ConnCase, async: true

  alias Dialectic.Notifications
  alias Dialectic.Notifications.EmailSubscriber
  alias Dialectic.Repo

  test "confirms a subscription token", %{conn: conn} do
    {:ok, subscriber} =
      Notifications.subscribe_to_updates(
        %{"email" => "person@example.com"},
        confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
      )

    conn = get(conn, ~p"/updates/confirm/#{subscriber.confirmation_token}")

    assert redirected_to(conn) == ~p"/updates"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "confirmed"
    assert Notifications.get_email_subscriber_by_email("person@example.com").confirmed_at
  end

  test "rejects an invalid confirmation token", %{conn: conn} do
    conn = get(conn, ~p"/updates/confirm/oops")

    assert redirected_to(conn) == ~p"/updates"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
  end

  test "unsubscribes a valid token", %{conn: conn} do
    raw_token = :crypto.strong_rand_bytes(32)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed_token = :crypto.hash(:sha256, raw_token)

    {:ok, _subscriber} =
      %EmailSubscriber{}
      |> EmailSubscriber.subscription_changeset(%{"email" => "person@example.com"})
      |> Ecto.Changeset.put_change(:confirmation_token, :crypto.hash(:sha256, "confirm"))
      |> Ecto.Changeset.put_change(:unsubscribe_token, hashed_token)
      |> Repo.insert()

    conn = get(conn, ~p"/updates/unsubscribe/#{encoded_token}")

    assert redirected_to(conn) == ~p"/updates"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "unsubscribed"
    assert Notifications.get_email_subscriber_by_email("person@example.com").unsubscribed_at
  end
end
