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
