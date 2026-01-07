defmodule DialecticWeb.UserConfirmationLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-md px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="border-b border-zinc-100 px-6 py-5">
          <h1 class="text-xl font-semibold tracking-tight text-zinc-900">
            Confirm your account
          </h1>

          <p class="mt-1 text-sm text-zinc-600">
            Click confirm to finish setting up your account.
          </p>
        </div>

        <div class="px-6 py-6">
          <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

            <:actions>
              <.button
                phx-disable-with="Confirming..."
                class="w-full inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Confirm my account
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

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "User confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
