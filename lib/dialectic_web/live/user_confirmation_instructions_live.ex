defmodule DialecticWeb.UserConfirmationInstructionsLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="border-b border-zinc-100 px-6 py-5">
          <h1 class="text-xl font-semibold tracking-tight text-zinc-900">
            Resend confirmation instructions
          </h1>
          <p class="mt-1 text-sm text-zinc-600">
            If you didn’t receive an email, we’ll send a new confirmation link to your inbox.
          </p>
        </div>

        <div class="px-6 py-6">
          <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="you@example.com"
              required
              class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
            />

            <:actions>
              <.button
                phx-disable-with="Sending..."
                class="w-full inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Resend confirmation link
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

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
