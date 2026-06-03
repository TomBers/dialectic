defmodule DialecticWeb.EmailSignupLive do
  use DialecticWeb, :live_view

  alias Dialectic.Notifications

  on_mount {DialecticWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Get RationalGrid updates")
     |> assign(:submitted?, false)
     |> assign_form(Notifications.change_email_signup())}
  end

  @impl true
  def handle_event("subscribe", %{"subscriber" => params}, socket) do
    case Notifications.subscribe_to_updates(params,
           source: "updates_page",
           user: socket.assigns[:current_user],
           confirmation_url_fun: fn token -> url(~p"/updates/confirm/#{token}") end
         ) do
      {:ok, _subscriber} ->
        {:noreply,
         socket
         |> assign(:submitted?, true)
         |> assign_form(Notifications.change_email_signup())
         |> put_flash(:info, "Please check your email to confirm your subscription.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "We could not send the confirmation email. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="min-h-[70vh] bg-gradient-to-br from-slate-950 via-indigo-950 to-slate-900 px-6 py-20 text-white">
      <div class="mx-auto max-w-3xl">
        <p class="inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-white/75 ring-1 ring-white/15">
          <.icon name="hero-envelope" class="h-4 w-4" /> Email updates
        </p>

        <h1 class="mt-6 text-4xl font-extrabold tracking-tight sm:text-5xl">
          Follow RationalGrid as it grows.
        </h1>

        <p class="mt-5 max-w-2xl text-lg leading-8 text-white/75">
          Sign up for occasional updates about new features, notable public grids, and future topic-based notifications. We will ask you to confirm your email before sending updates.
        </p>

        <div class="mt-10 rounded-3xl bg-white p-6 text-slate-950 shadow-2xl ring-1 ring-white/10 sm:p-8">
          <div
            :if={@submitted?}
            id="email-signup-submitted"
            class="mb-6 rounded-2xl bg-emerald-50 p-4 text-sm text-emerald-900 ring-1 ring-emerald-200"
          >
            Almost done — open the confirmation link we sent to your email address.
          </div>

          <.form for={@form} id="email-signup-form" phx-submit="subscribe" class="space-y-5">
            <.input
              field={@form[:email]}
              type="email"
              label="Email address"
              placeholder="you@example.com"
              required
            />

            <button
              id="email-signup-submit"
              type="submit"
              class="inline-flex w-full items-center justify-center rounded-xl bg-indigo-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 sm:w-auto"
            >
              Send confirmation email
            </button>
          </.form>

          <p class="mt-5 text-sm leading-6 text-slate-500">
            You can unsubscribe at any time. Future topic and graph notifications will use your email preferences rather than sending every small update.
          </p>
        </div>
      </div>
    </section>
    """
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :subscriber))
  end
end
