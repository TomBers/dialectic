defmodule Dialectic.NotificationsTest do
  use Dialectic.DataCase, async: true

  import Dialectic.AccountsFixtures

  alias Dialectic.Notifications
  alias Dialectic.Notifications.{EmailSubscriber, GraphEvent, GraphFollow}

  describe "graph events" do
    test "records a graph event with actor and metadata" do
      user = user_fixture()
      graph = Dialectic.GraphFixtures.insert_graph(%{title: "Event Graph"})

      assert {:ok, %GraphEvent{} = event} =
               Notifications.record_graph_event(graph, %{
                 event_type: "graph.updated",
                 actor_user: user,
                 summary: "Grid updated",
                 metadata: %{operation: "comment", node_id: "2"}
               })

      assert event.graph_title == graph.title
      assert event.actor_user_id == user.id
      assert event.event_type == "graph.updated"
      assert event.metadata["operation"] == "comment"
      assert event.metadata["node_id"] == "2"
      assert event.occurred_at
    end

    test "lists owned graph events since a timestamp" do
      owner = user_fixture()
      other_user = user_fixture()

      owned_graph =
        Dialectic.GraphFixtures.insert_graph(%{title: "Owned Events", user_id: owner.id})

      other_graph =
        Dialectic.GraphFixtures.insert_graph(%{title: "Other Events", user_id: other_user.id})

      since = DateTime.add(DateTime.utc_now(:second), -60, :second)

      {:ok, owned_event} =
        Notifications.record_graph_event(owned_graph, %{
          event_type: "graph.updated",
          actor_user: other_user,
          summary: "Owned graph changed"
        })

      {:ok, _other_event} =
        Notifications.record_graph_event(other_graph, %{
          event_type: "graph.updated",
          actor_user: other_user,
          summary: "Other graph changed"
        })

      assert [event] = Notifications.list_owned_graph_events(owner, since: since)
      assert event.id == owned_event.id
      assert event.graph.title == owned_graph.title
      assert event.actor_user.id == other_user.id
    end

    test "lists followed graph events and excludes self-authored events by default" do
      follower = user_fixture()
      actor = user_fixture()
      graph = Dialectic.GraphFixtures.insert_graph(%{title: "Followed Events"})
      since = DateTime.add(DateTime.utc_now(:second), -60, :second)

      {:ok, _follow} = Notifications.follow_graph(follower, graph)

      {:ok, actor_event} =
        Notifications.record_graph_event(graph, %{
          event_type: "graph.updated",
          actor_user: actor,
          summary: "Someone else changed the graph"
        })

      {:ok, _self_event} =
        Notifications.record_graph_event(graph, %{
          event_type: "graph.updated",
          actor_user: follower,
          summary: "Follower changed the graph"
        })

      assert [event] = Notifications.list_followed_graph_events(follower, since: since)
      assert event.id == actor_event.id
      assert event.graph.title == graph.title

      events =
        Notifications.list_followed_graph_events(follower, since: since, include_self?: true)

      assert length(events) == 3
    end
  end

  describe "graph follows" do
    test "follows and unfollows a graph" do
      user = user_fixture()
      graph = Dialectic.GraphFixtures.insert_graph(%{title: "Followed Graph"})

      refute Notifications.following_graph?(user, graph)

      assert {:ok, %GraphFollow{} = follow} = Notifications.follow_graph(user, graph)
      assert follow.user_id == user.id
      assert follow.graph_title == graph.title
      assert follow.frequency == "weekly"
      assert Notifications.following_graph?(user, graph)
      assert %GraphFollow{} = Notifications.get_graph_follow(user, graph)

      assert :ok = Notifications.unfollow_graph(user, graph)
      refute Notifications.following_graph?(user, graph)
      refute Notifications.get_graph_follow(user, graph)
    end

    test "updates an existing follow frequency" do
      user = user_fixture()
      graph = Dialectic.GraphFixtures.insert_graph(%{title: "Frequency Graph"})

      assert {:ok, _follow} = Notifications.follow_graph(user, graph)
      assert {:ok, _follow} = Notifications.follow_graph(user, graph, %{frequency: "daily"})

      assert Notifications.get_graph_follow(user, graph).frequency == "daily"
    end
  end

  describe "change_email_signup/1" do
    test "validates email" do
      changeset = Notifications.change_email_signup(%{"email" => "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end
  end

  describe "subscribe_to_updates/2" do
    test "stores a pending subscriber and sends a confirmation token" do
      assert {:ok, subscriber} =
               Notifications.subscribe_to_updates(
                 %{"email" => "  PERSON@Example.COM "},
                 source: "test",
                 confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
               )

      assert subscriber.email == "person@example.com"
      assert subscriber.source == "test"
      assert is_binary(subscriber.confirmation_token)
      refute subscriber.confirmed_at
      refute subscriber.unsubscribed_at

      {:ok, decoded_token} = Base.url_decode64(subscriber.confirmation_token, padding: false)
      stored = Notifications.get_email_subscriber_by_email("person@example.com")

      assert stored.confirmation_token == :crypto.hash(:sha256, decoded_token)
      assert stored.unsubscribe_token
    end

    test "refreshes an existing subscriber and requires confirmation again" do
      {:ok, subscriber} =
        Notifications.subscribe_to_updates(
          %{"email" => "person@example.com"},
          source: "first",
          confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
        )

      assert {:ok, confirmed_subscriber} =
               Notifications.confirm_email_subscription(subscriber.confirmation_token)

      assert confirmed_subscriber.confirmed_at

      assert {:ok, refreshed_subscriber} =
               Notifications.subscribe_to_updates(
                 %{"email" => "person@example.com"},
                 source: "second",
                 confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
               )

      refute refreshed_subscriber.confirmed_at
      assert refreshed_subscriber.source == "second"
      assert refreshed_subscriber.confirmation_token != subscriber.confirmation_token
    end
  end

  describe "confirm_email_subscription/1" do
    test "confirms with a valid token once" do
      {:ok, subscriber} =
        Notifications.subscribe_to_updates(
          %{"email" => "person@example.com"},
          confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
        )

      assert {:ok, confirmed_subscriber} =
               Notifications.confirm_email_subscription(subscriber.confirmation_token)

      assert confirmed_subscriber.confirmed_at
      refute confirmed_subscriber.confirmation_token
      assert Notifications.confirm_email_subscription(subscriber.confirmation_token) == :error
    end

    test "does not confirm with an invalid or expired token" do
      {:ok, subscriber} =
        Notifications.subscribe_to_updates(
          %{"email" => "person@example.com"},
          confirmation_url_fun: &"https://example.com/updates/confirm/#{&1}"
        )

      assert Notifications.confirm_email_subscription("oops") == :error

      Repo.update_all(EmailSubscriber, set: [updated_at: ~U[2020-01-01 00:00:00Z]])
      assert Notifications.confirm_email_subscription(subscriber.confirmation_token) == :error
    end
  end

  describe "unsubscribe_email_subscription/1" do
    test "unsubscribes with a valid token" do
      raw_token = :crypto.strong_rand_bytes(32)
      encoded_token = Base.url_encode64(raw_token, padding: false)
      hashed_token = :crypto.hash(:sha256, raw_token)

      {:ok, subscriber} =
        %EmailSubscriber{}
        |> EmailSubscriber.subscription_changeset(%{"email" => "person@example.com"})
        |> Ecto.Changeset.put_change(:confirmation_token, :crypto.hash(:sha256, "confirm"))
        |> Ecto.Changeset.put_change(:unsubscribe_token, hashed_token)
        |> Repo.insert()

      assert {:ok, unsubscribed_subscriber} =
               Notifications.unsubscribe_email_subscription(encoded_token)

      assert unsubscribed_subscriber.id == subscriber.id
      assert unsubscribed_subscriber.unsubscribed_at
    end
  end
end
