defmodule DialecticWeb.UserSettingsLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="flex flex-col gap-4 border-b border-zinc-100 px-6 py-5 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 class="text-xl font-semibold tracking-tight text-zinc-900">
              Account settings
            </h1>
            <p class="mt-1 text-sm text-zinc-600">
              Manage your account email address and password settings.
            </p>
          </div>

          <div class="flex items-center gap-3">
            <.link
              href={~p"/users/log_out"}
              method="delete"
              id="user-settings-logout"
              class="inline-flex items-center justify-center rounded-xl bg-zinc-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-900"
            >
              Log out
            </.link>
          </div>
        </div>

        <div class="px-6 py-6">
          <div class="space-y-10">
            <section id="user-settings-email-section" class="space-y-4">
              <div class="flex items-start gap-3">
                <div class="mt-0.5 flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 ring-1 ring-indigo-100">
                  <.icon name="hero-envelope" class="h-5 w-5 text-indigo-700" />
                </div>

                <div>
                  <h2 class="text-base font-semibold text-zinc-900">Email</h2>
                  <p class="mt-1 text-sm text-zinc-600">
                    Update the email address associated with your account.
                  </p>
                </div>
              </div>

              <div class="rounded-2xl border border-zinc-200/60 bg-zinc-50/50 p-5 sm:p-6">
                <.simple_form
                  for={@email_form}
                  id="email_form"
                  phx-submit="update_email"
                  phx-change="validate_email"
                >
                  <.input
                    field={@email_form[:email]}
                    type="email"
                    label="Email"
                    required
                    class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                  />

                  <.input
                    field={@email_form[:current_password]}
                    name="current_password"
                    id="current_password_for_email"
                    type="password"
                    label="Current password"
                    value={@email_form_current_password}
                    required
                    class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                  />

                  <:actions>
                    <.button
                      phx-disable-with="Changing..."
                      class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                    >
                      Change email
                    </.button>
                  </:actions>
                </.simple_form>
              </div>
            </section>

            <div class="h-px bg-zinc-100"></div>

            <section id="user-settings-password-section" class="space-y-4">
              <div class="flex items-start gap-3">
                <div class="mt-0.5 flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 ring-1 ring-indigo-100">
                  <.icon name="hero-key" class="h-5 w-5 text-indigo-700" />
                </div>

                <div>
                  <h2 class="text-base font-semibold text-zinc-900">Password</h2>
                  <p class="mt-1 text-sm text-zinc-600">
                    Change your password. You’ll be asked to log in again after updating.
                  </p>
                </div>
              </div>

              <div class="rounded-2xl border border-zinc-200/60 bg-zinc-50/50 p-5 sm:p-6">
                <.simple_form
                  for={@password_form}
                  id="password_form"
                  action={~p"/users/log_in?_action=password_updated"}
                  method="post"
                  phx-change="validate_password"
                  phx-submit="update_password"
                  phx-trigger-action={@trigger_submit}
                >
                  <input
                    name={@password_form[:email].name}
                    type="hidden"
                    id="hidden_user_email"
                    value={@current_email}
                  />

                  <.input
                    field={@password_form[:password]}
                    type="password"
                    label="New password"
                    required
                    class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                  />

                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    label="Confirm new password"
                    class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                  />

                  <.input
                    field={@password_form[:current_password]}
                    name="current_password"
                    type="password"
                    label="Current password"
                    id="current_password_for_password"
                    value={@current_password}
                    required
                    class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                  />

                  <:actions>
                    <.button
                      phx-disable-with="Changing..."
                      class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                    >
                      Change password
                    </.button>
                  </:actions>
                </.simple_form>
              </div>
            </section>
          </div>

          <div class="mt-8 flex items-center justify-between">
            <.link
              navigate={~p"/"}
              id="user-settings-back-home"
              class="inline-flex items-center gap-2 text-sm font-semibold text-zinc-700 hover:text-zinc-900"
            >
              <.icon name="hero-arrow-left" class="h-4 w-4" /> Back to home
            </.link>

            <p class="text-xs text-zinc-500">
              Need help? Email support.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
