defmodule Dialectic.Notifications.Notifier do
  import Swoosh.Email

  alias Dialectic.Mailer
  alias Dialectic.Notifications.EmailSubscriber

  def deliver_confirmation_instructions(%EmailSubscriber{} = subscriber, url) do
    email =
      new()
      |> to(subscriber.email)
      |> from(Mailer.default_from())
      |> subject("Confirm your RationalGrid updates subscription")
      |> text_body("""

      ==============================

      Hi,

      Please confirm that you want to receive RationalGrid updates by visiting the URL below:

      #{url}

      If you did not request this, you can ignore this email.

      ==============================
      """)
      |> html_body("""
      <p>Hi,</p>
      <p>Please confirm that you want to receive RationalGrid updates by clicking the link below:</p>
      <p><a href=\"#{url}\">Confirm your subscription</a></p>
      <p>If you did not request this, you can ignore this email.</p>
      """)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
