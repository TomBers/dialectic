defmodule DialecticWeb.UserSessionController do
  use DialecticWeb, :controller

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias DialecticWeb.UserAuth

  @registration_profile_message "Account created successfully! Your profile is your personal thinking homepage — customise it and use it to keep track of your own thinking, including graphs, noted nodes, and highlights."

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, @registration_profile_message, &profile_path/1)
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    create(conn, %{"user" => user_params}, info, fn _user ->
      get_session(conn, :user_return_to)
    end)
  end

  defp create(conn, %{"user" => user_params}, info, return_path_fun) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_session(:user_return_to, return_path_fun.(user))
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  defp profile_path(%User{} = user) do
    ~p"/u/#{User.effective_username(user)}"
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
