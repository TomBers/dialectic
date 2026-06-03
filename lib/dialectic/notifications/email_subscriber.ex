defmodule Dialectic.Notifications.EmailSubscriber do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_subscribers" do
    field :email, :string
    field :source, :string
    field :confirmed_at, :utc_datetime
    field :unsubscribed_at, :utc_datetime
    field :confirmation_token, :binary, redact: true
    field :unsubscribe_token, :binary, redact: true

    belongs_to :user, Dialectic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def signup_changeset(email_subscriber, attrs) do
    email_subscriber
    |> cast(attrs, [:email])
    |> normalize_email()
    |> validate_email()
  end

  def subscription_changeset(email_subscriber, attrs) do
    email_subscriber
    |> signup_changeset(attrs)
    |> cast(attrs, [:source])
    |> validate_length(:source, max: 120)
    |> unique_constraint(:email)
  end

  def token_changeset(email_subscriber, attrs) do
    email_subscriber
    |> cast(attrs, [
      :confirmation_token,
      :unsubscribe_token,
      :confirmed_at,
      :unsubscribed_at,
      :source,
      :user_id
    ])
    |> validate_required([:confirmation_token, :unsubscribe_token])
    |> unique_constraint(:confirmation_token)
    |> unique_constraint(:unsubscribe_token)
  end

  def confirm_changeset(email_subscriber) do
    change(email_subscriber,
      confirmed_at: DateTime.utc_now(:second),
      confirmation_token: nil,
      unsubscribed_at: nil
    )
  end

  def unsubscribe_changeset(email_subscriber) do
    change(email_subscriber, unsubscribed_at: DateTime.utc_now(:second))
  end

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn email ->
      email
      |> String.trim()
      |> String.downcase()
    end)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end
end
