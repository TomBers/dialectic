defmodule DialecticWeb.UserLoginLive do
  use DialecticWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="border-b border-zinc-100 px-6 py-5">
          <h1 class="text-xl font-semibold tracking-tight text-zinc-900">
            Log in
          </h1>

          <p class="mt-1 text-sm text-zinc-600">
            Don’t have an account?
            <.link
              navigate={~p"/users/register"}
              class="font-semibold text-indigo-600 hover:text-indigo-500"
            >
              Sign up
            </.link>
          </p>
        </div>

        <div class="px-6 py-6">
          <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              required
              class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              required
              class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
            />

            <:actions>
              <div class="flex items-center justify-between gap-4 w-full">
                <label class="flex items-center gap-2 text-sm text-zinc-700 select-none">
                  <input type="hidden" name={@form[:remember_me].name} value="false" />
                  <input
                    type="checkbox"
                    id={@form[:remember_me].id}
                    name={@form[:remember_me].name}
                    value="true"
                    checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:remember_me].value)}
                    class="h-4 w-4 rounded border-zinc-300 text-indigo-600 focus:ring-indigo-500"
                  /> Keep me logged in
                </label>

                <.link
                  href={~p"/users/reset_password"}
                  class="text-sm font-semibold text-indigo-600 hover:text-indigo-500"
                >
                  Forgot password?
                </.link>
              </div>
            </:actions>

            <:actions>
              <.button
                phx-disable-with="Logging in..."
                class="w-full inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                Log in
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
              href={~p"/auth/google"}
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
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
