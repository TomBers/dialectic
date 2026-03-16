defmodule Dialectic.Branding do
  @moduledoc """
  Single source of truth for branding values (app name, emails, links).

  All values are read from `config :dialectic, :branding` so they can be
  changed in one place without hunting through templates and modules.
  """

  @doc "The public-facing application name, e.g. \"RationalGrid\"."
  def app_name, do: get(:app_name)

  @doc "General contact email shown on public pages."
  def contact_email, do: get(:contact_email)

  @doc "No-reply address used as the From in transactional emails."
  def noreply_email, do: get(:noreply_email)

  @doc "URL of the project's GitHub repository."
  def github_url, do: get(:github_url)

  @doc "URL of the maintainer's GitHub profile."
  def github_profile_url, do: get(:github_profile_url)

  @doc "Returns `{app_name, noreply_email}` tuple suitable for `Swoosh.Email.from/2`."
  def email_from, do: {app_name(), noreply_email()}

  @doc "Returns a `mailto:` URI for the contact email."
  def contact_mailto, do: "mailto:#{contact_email()}"

  defp get(key) do
    :dialectic
    |> Application.get_env(:branding, [])
    |> Keyword.fetch!(key)
  end
end
