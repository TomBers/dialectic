defmodule Dialectic.Workers.EmailWorker do
  use Oban.Worker, queue: :api_request

  alias Dialectic.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "email_type" => "invite",
          "to" => to,
          "inviter" => inviter,
          "graph_title" => title,
          "link" => link
        }
      }) do
    Dialectic.Emails.invite_email(to, inviter, title, link)
    |> Mailer.deliver()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
