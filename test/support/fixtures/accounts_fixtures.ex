defmodule Dialectic.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dialectic.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Dialectic.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def valid_oauth_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      provider: "google",
      provider_id: "google_#{System.unique_integer()}",
      provider_token: "test_access_token_#{System.unique_integer()}",
      provider_refresh_token: "test_refresh_token_#{System.unique_integer()}"
    })
  end

  def oauth_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_oauth_attributes()
      |> Dialectic.Accounts.find_or_create_oauth_user()

    user
  end
end
