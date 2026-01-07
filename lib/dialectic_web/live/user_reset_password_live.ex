defmodule DialecticWeb.UserResetPasswordLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="border-b border-zinc-100 px-6 py-5">
          <h1 class="text-xl font-semibold tracking-tight text-zinc-900">
            Reset password
          </h1>
          <p class="mt-1 text-sm text-zinc-600">
            Choose a new password for your account.
          </p>
        </div>

        <div class="px-6 py-6">
          <.simple_form
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            phx-change="validate"
          >
            <.error :if={@form.errors != []}>
              Oops, something went wrong! Please check the errors below.
            </.error>

            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              required
              class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
            />

            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              required
              class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
            />

            <:actions>
              <.button
                phx-disable-with="Resetting..."
                class="w-full inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Reset password
              </.button>
            </:actions>
          </.simple_form>

          <div class="mt-6 flex items-center justify-between">
            <.link
              href={~p"/users/log_in"}
              class="text-sm font-semibold text-indigo-600 hover:text-indigo-500"
            >
              Back to log in
            </.link>

            <.link
              href={~p"/users/register"}
              class="text-sm font-semibold text-zinc-700 hover:text-zinc-900"
            >
              Create an account
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
