defmodule DialecticWeb.UserRegistrationLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User

  def render(assigns) do
    ~H"""
    <main id="registration-page" class="bg-[#f4f1e9] px-5 py-10 sm:px-8 sm:py-16">
      <div class="mx-auto grid max-w-5xl overflow-hidden rounded-2xl border border-stone-300 bg-white shadow-xl lg:grid-cols-[0.9fr_1.1fr]">
        <aside class="hidden bg-slate-950 p-10 text-white lg:flex lg:flex-col lg:justify-between">
          <div>
            <.link navigate={~p"/"} class="inline-flex items-center gap-3">
              <img src={~p"/images/brandmark.svg"} alt="" class="h-10 w-10" />
              <span class="text-lg font-semibold">RationalGrid</span>
            </.link>
            <p class="mt-12 text-xs font-semibold uppercase tracking-[0.2em] text-teal-300">
              Keep the path visible
            </p>
            <h2 class="mt-3 font-serif text-4xl font-semibold leading-tight">
              Turn a question into reasoning you can return to.
            </h2>
            <ul class="mt-7 space-y-4 text-sm leading-6 text-slate-300">
              <li class="flex gap-3">
                <.icon name="hero-check" class="mt-1 h-4 w-4 shrink-0 text-teal-300" />
                Save and revisit your grids.
              </li>
              <li class="flex gap-3">
                <.icon name="hero-check" class="mt-1 h-4 w-4 shrink-0 text-teal-300" />
                Unlock expanded and in-depth answers.
              </li>
              <li class="flex gap-3">
                <.icon name="hero-check" class="mt-1 h-4 w-4 shrink-0 text-teal-300" />
                Control who can view or edit your work.
              </li>
            </ul>
          </div>
          <p class="mt-12 text-sm text-slate-400">Free, open source, and not-for-profit.</p>
        </aside>

        <section class="px-6 py-8 sm:px-10 sm:py-12">
          <.link
            id="registration-home-link"
            navigate={~p"/"}
            class="mb-8 inline-flex items-center gap-3 lg:hidden"
          >
            <img src={~p"/images/brandmark.svg"} alt="" class="h-9 w-9" />
            <span class="font-semibold text-slate-950">RationalGrid</span>
          </.link>
          <div class="border-b border-stone-200 pb-6">
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
              Start for free
            </p>
            <h1 class="mt-2 font-serif text-3xl font-semibold tracking-tight text-slate-950">
              Create your RationalGrid account
            </h1>

            <p class="mt-1 text-sm text-zinc-600">
              Already registered?
              <.link
                id="registration-login-link"
                navigate={~p"/users/log_in"}
                class="font-semibold text-teal-800 hover:text-teal-700"
              >
                Log in
              </.link>
            </p>
          </div>

          <div class="pt-7">
            <div
              id="registration-benefits"
              class="mb-6 rounded-xl border border-teal-200 bg-teal-50 px-4 py-3 text-sm text-teal-950 lg:hidden"
            >
              <p class="font-semibold">Free account. No payment details.</p>
              <p class="mt-1 leading-6">
                Save and return to your grids, unlock deeper answers, and control who can view or edit them.
              </p>
            </div>
            <.simple_form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              phx-trigger-action={@trigger_submit}
              action={~p"/users/log_in?_action=registered"}
              method="post"
              data-analytics-event="registration_form_submitted"
              data-analytics-location="registration_page"
            >
              <.error :if={@check_errors}>
                Oops, something went wrong! Please check the errors below.
              </.error>

              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                required
                class="mt-2 block w-full rounded-lg border border-stone-300 bg-white text-slate-950 shadow-sm focus:border-teal-700 focus:ring-2 focus:ring-teal-600/20 sm:text-sm sm:leading-6"
              />

              <div class="relative" data-password-wrapper>
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  required
                  class="mt-2 block w-full rounded-lg border border-stone-300 bg-white text-slate-950 shadow-sm focus:border-teal-700 focus:ring-2 focus:ring-teal-600/20 sm:text-sm sm:leading-6 pr-10"
                />
                <button
                  type="button"
                  id="register-password-toggle"
                  phx-hook="PasswordToggle"
                  phx-update="ignore"
                  class="absolute right-3 top-[2.35rem] text-zinc-400 hover:text-zinc-600 transition-colors focus:outline-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-white rounded-full"
                  aria-label="Show password"
                  aria-pressed="false"
                >
                  <span data-eye-open>
                    <.icon name="hero-eye" class="w-5 h-5" />
                  </span>
                  <span data-eye-slash class="hidden">
                    <.icon name="hero-eye-slash" class="w-5 h-5" />
                  </span>
                </button>
              </div>

              <:actions>
                <.button
                  phx-disable-with="Creating account..."
                  class="w-full inline-flex items-center justify-center rounded-xl bg-slate-950 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700"
                >
                  Create an account
                </.button>
              </:actions>
            </.simple_form>

            <div class="relative my-6">
              <div class="absolute inset-0 flex items-center" aria-hidden="true">
                <div class="w-full border-t border-zinc-200"></div>
              </div>
              <div class="relative flex justify-center text-sm font-medium leading-6">
                <span class="bg-white px-4 text-zinc-500">Or continue with</span>
              </div>
            </div>

            <div>
              <a
                id="registration-google-link"
                href={~p"/auth/google"}
                data-analytics-event="registration_google_clicked"
                data-analytics-location="registration_page"
                class="flex w-full items-center justify-center gap-3 rounded-xl bg-white px-4 py-3 text-sm font-semibold text-zinc-900 shadow-sm ring-1 ring-inset ring-zinc-300 hover:bg-zinc-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-600"
              >
                <svg class="h-5 w-5" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    d="M12.0003 4.75C13.7703 4.75 15.3553 5.36002 16.6053 6.54998L20.0303 3.125C17.9502 1.19 15.2353 0 12.0003 0C7.31028 0 3.25527 2.69 1.28027 6.60998L5.27028 9.70498C6.21525 6.86002 8.87028 4.75 12.0003 4.75Z"
                    fill="#EA4335"
                  />
                  <path
                    d="M23.49 12.275C23.49 11.49 23.415 10.73 23.3 10H12V14.51H18.47C18.18 15.99 17.34 17.25 16.08 18.1L19.945 21.1C22.2 19.01 23.49 15.92 23.49 12.275Z"
                    fill="#4285F4"
                  />
                  <path
                    d="M5.26498 14.2949C5.02498 13.5699 4.88501 12.7999 4.88501 11.9999C4.88501 11.1999 5.01998 10.4299 5.26498 9.7049L1.275 6.60986C0.46 8.22986 0 10.0599 0 11.9999C0 13.9399 0.46 15.7699 1.28 17.3899L5.26498 14.2949Z"
                    fill="#FBBC05"
                  />
                  <path
                    d="M12.0004 24.0001C15.2404 24.0001 17.9654 22.935 19.9454 21.095L16.0804 18.095C15.0054 18.82 13.6204 19.245 12.0004 19.245C8.8704 19.245 6.21537 17.135 5.2654 14.29L1.27539 17.385C3.25539 21.31 7.3104 24.0001 12.0004 24.0001Z"
                    fill="#34A853"
                  />
                </svg>
                Sign in with Google
              </a>
            </div>
          </div>
        </section>
      </div>
    </main>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
