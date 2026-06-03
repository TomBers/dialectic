defmodule DialecticWeb.EmailSubscriptionController do
  use DialecticWeb, :controller

  alias Dialectic.Notifications

  def confirm(conn, %{"token" => token}) do
    case Notifications.confirm_email_subscription(token) do
      {:ok, _subscriber} ->
        conn
        |> put_flash(:info, "Your email subscription has been confirmed.")
        |> redirect(to: ~p"/updates")

      :error ->
        conn
        |> put_flash(:error, "The subscription confirmation link is invalid or has expired.")
        |> redirect(to: ~p"/updates")
    end
  end

  def unsubscribe(conn, %{"token" => token}) do
    case Notifications.unsubscribe_email_subscription(token) do
      {:ok, _subscriber} ->
        conn
        |> put_flash(:info, "You have been unsubscribed from email updates.")
        |> redirect(to: ~p"/updates")

      :error ->
        conn
        |> put_flash(:error, "The unsubscribe link is invalid.")
        |> redirect(to: ~p"/updates")
    end
  end
end
