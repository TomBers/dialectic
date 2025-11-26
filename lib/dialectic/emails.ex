defmodule Dialectic.Emails do
  import Swoosh.Email

  def invite_email(to, inviter, graph_title, link) do
    new()
    |> to(to)
    |> from({"Dialectic", "no-reply@dialectic.app"})
    |> subject("#{inviter} invited you to edit '#{graph_title}'")
    |> html_body("""
    <h1>Invitation to Collaborate</h1>
    <p><strong>#{inviter}</strong> has invited you to view and edit the graph <strong>#{graph_title}</strong>.</p>
    <p>Click the link below to accept the invitation:</p>
    <p><a href="#{link}">#{link}</a></p>
    <p>If you did not expect this invitation, you can ignore this email.</p>
    """)
    |> text_body("""
    #{inviter} has invited you to view and edit the graph '#{graph_title}'.

    Access it here: #{link}
    """)
  end
end
