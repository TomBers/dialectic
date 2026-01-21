defmodule DialecticWeb.AuthController do
  use DialecticWeb, :controller
  plug Ueberauth

  alias Dialectic.Accounts
  alias DialecticWeb.UserAuth

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate with Google. Please try again.")
    |> redirect(to: ~p"/users/log_in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      provider: to_string(auth.provider),
      provider_id: auth.uid,
      access_token: auth.credentials.token
    }

    case Accounts.find_or_create_oauth_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated with Google.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
          |> Enum.join("; ")

        conn
        |> put_flash(:error, "Unable to create account: #{errors}")
        |> redirect(to: ~p"/users/log_in")
    end
  end
end
