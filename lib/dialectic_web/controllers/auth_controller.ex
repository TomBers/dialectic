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
      provider_token: auth.credentials.token,
      provider_refresh_token: auth.credentials.refresh_token
    }

    case Accounts.find_or_create_oauth_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated with Google.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        reason = translate_errors(changeset)

        conn
        |> put_flash(:error, "Unable to create account: #{reason}")
        |> redirect(to: ~p"/users/log_in")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
