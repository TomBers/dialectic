defmodule DialecticWeb.UserSettingsLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.GravatarCache

  @impl true
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
              Manage your profile, email address, and password settings.
            </p>
          </div>

          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/u/#{@effective_username}"}
              id="user-settings-view-profile"
              class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              <.icon name="hero-user" class="w-4 h-4 mr-1.5" /> View Profile
            </.link>
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
            <%!-- Profile Section --%>
            <section id="user-settings-profile-section" class="space-y-4">
              <div class="flex items-start gap-3">
                <div class="mt-0.5 flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 ring-1 ring-indigo-100">
                  <.icon name="hero-user-circle" class="h-5 w-5 text-indigo-700" />
                </div>

                <div>
                  <h2 class="text-base font-semibold text-zinc-900">Profile</h2>
                  <p class="mt-1 text-sm text-zinc-600">
                    Customize how others see you on RationalGrid. Your profile is publicly visible at
                    <.link
                      navigate={~p"/u/#{@effective_username}"}
                      class="font-medium text-indigo-600 hover:text-indigo-500"
                    >
                      /u/{@effective_username}
                    </.link>
                  </p>
                </div>
              </div>

              <div class="rounded-2xl border border-zinc-200/60 bg-zinc-50/50 overflow-hidden">
                <%!-- Header Image Preview --%>
                <%= if @header_preview_url do %>
                  <div class="h-24 sm:h-32 overflow-hidden">
                    <img
                      src={@header_preview_url}
                      alt="Header image preview"
                      class="h-full w-full object-cover"
                    />
                  </div>
                <% else %>
                  <div class="h-24 sm:h-32 bg-gradient-to-r from-indigo-500 to-blue-400"></div>
                <% end %>

                <div class="p-5 sm:p-6">
                  <%!-- Avatar Preview --%>
                  <div class="mb-6 flex items-center gap-4 -mt-10">
                    <div class="h-16 w-16 rounded-full border-2 border-white shadow-sm flex items-center justify-center overflow-hidden flex-shrink-0">
                      <%= if @avatar_preview_url do %>
                        <img
                          src={@avatar_preview_url}
                          alt="Avatar preview"
                          class="h-full w-full object-cover rounded-full"
                        />
                      <% else %>
                        <div class="h-full w-full flex items-center justify-center rounded-full bg-indigo-100 text-indigo-600 text-xl font-bold">
                          {String.first(@effective_username) |> String.upcase()}
                        </div>
                      <% end %>
                    </div>
                    <div class="pt-4">
                      <p class="text-sm font-medium text-zinc-900">{@effective_username}</p>
                      <%= if @avatar_preview_url do %>
                        <p class="text-xs text-emerald-600 mt-0.5">Gravatar connected</p>
                      <% end %>
                    </div>
                  </div>

                  <.simple_form
                    for={@profile_form}
                    id="profile_form"
                    phx-submit="update_profile"
                    phx-change="validate_profile"
                  >
                    <.input
                      field={@profile_form[:username]}
                      type="text"
                      label="Username"
                      required
                      class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                    />

                    <.input
                      field={@profile_form[:bio]}
                      type="textarea"
                      label="Bio"
                      placeholder="Tell people a bit about yourself and what you explore on MuDG..."
                      class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                    />

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4">
                      <div>
                        <.input
                          field={@profile_form[:gravatar_id]}
                          type="text"
                          label="Gravatar ID"
                          placeholder="e.g. phenomenal1a25bedd6b"
                          class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                        />
                        <p class="mt-1 text-xs text-zinc-500">
                          Your Gravatar profile slug — the last part of your
                          <a
                            href="https://gravatar.com"
                            target="_blank"
                            rel="noopener noreferrer"
                            class="text-indigo-600 hover:text-indigo-500 underline"
                          >
                            gravatar.com
                          </a>
                          profile URL. Leave blank for the default icon.
                        </p>
                      </div>

                      <.input
                        field={@profile_form[:theme]}
                        type="select"
                        label="Profile theme"
                        options={[
                          {"Light (default)", "default"},
                          {"Indigo", "indigo"},
                          {"Violet", "violet"},
                          {"Emerald", "emerald"},
                          {"Amber", "amber"},
                          {"Rose", "rose"}
                        ]}
                        class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                      />
                    </div>

                    <%!-- Theme Preview --%>
                    <div class="mt-2">
                      <p class="text-xs font-medium text-zinc-500 mb-2">Theme preview</p>
                      <div class={[
                        "h-10 w-full rounded-lg border transition-colors",
                        theme_preview_class(@theme_preview)
                      ]}>
                      </div>
                    </div>

                    <%!-- Connected Accounts from Gravatar --%>
                    <%= if @verified_accounts != [] do %>
                      <div class="h-px bg-zinc-100 my-2"></div>

                      <p class="text-xs font-medium text-zinc-500 uppercase tracking-wider mb-2">
                        Connected accounts
                      </p>

                      <div class="flex flex-wrap gap-2">
                        <%= for account <- @verified_accounts do %>
                          <a
                            href={account.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            class="inline-flex items-center gap-1.5 rounded-lg border border-zinc-200 bg-white px-3 py-1.5 text-sm text-zinc-700 shadow-sm hover:bg-zinc-50 transition"
                          >
                            <img
                              src={account.service_icon}
                              alt={account.service_label}
                              class="w-4 h-4"
                            />
                            {account.service_label}
                          </a>
                        <% end %>
                      </div>

                      <p class="mt-1.5 text-xs text-zinc-500">
                        Social links are pulled from your
                        <a
                          href="https://gravatar.com/profile"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="text-indigo-600 hover:text-indigo-500 underline"
                        >
                          Gravatar profile
                        </a>
                      </p>
                    <% else %>
                      <div class="h-px bg-zinc-100 my-2"></div>

                      <p class="text-xs text-zinc-500">
                        Social links are pulled from your
                        <a
                          href="https://gravatar.com/profile"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="text-indigo-600 hover:text-indigo-500 underline"
                        >
                          Gravatar profile
                        </a>
                        — add verified accounts there to display them here.
                      </p>
                    <% end %>

                    <:actions>
                      <.button
                        phx-disable-with="Saving..."
                        class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                      >
                        Save profile
                      </.button>
                    </:actions>
                  </.simple_form>
                </div>
              </div>
            </section>

            <div class="h-px bg-zinc-100"></div>

            <%!-- Email Section --%>
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

            <%!-- Password Section --%>
            <section id="user-settings-password-section" class="space-y-4">
              <div class="flex items-start gap-3">
                <div class="mt-0.5 flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 ring-1 ring-indigo-100">
                  <.icon name="hero-key" class="h-5 w-5 text-indigo-700" />
                </div>

                <div>
                  <h2 class="text-base font-semibold text-zinc-900">Password</h2>
                  <p class="mt-1 text-sm text-zinc-600">
                    Change your password. You'll be asked to log in again after updating.
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

  @impl true
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

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    effective_username = User.effective_username(user)

    profile_changeset = Accounts.change_user_profile(user)

    theme_preview = user.theme || "default"

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:profile_form, to_form(profile_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:effective_username, effective_username)
      |> assign(:avatar_preview_url, nil)
      |> assign(:header_preview_url, nil)
      |> assign(:verified_accounts, [])
      |> assign(:theme_preview, theme_preview)

    # Load Gravatar data — served from ETS cache when available,
    # fetched async on cache miss to avoid redundant external API calls.
    socket =
      case user.gravatar_id do
        id when is_binary(id) and id != "" ->
          case GravatarCache.get(id) do
            {:ok, data} ->
              # Cache hit — apply immediately, no async fetch needed
              socket
              |> assign(:avatar_preview_url, data.avatar_url)
              |> assign(:header_preview_url, data.header_image_url)
              |> assign(:verified_accounts, data.verified_accounts)

            :miss ->
              # Cache miss — fetch asynchronously so we don't block render
              start_async(socket, :fetch_gravatar, fn ->
                GravatarCache.fetch(id)
              end)
          end

        _ ->
          socket
      end

    {:ok, socket}
  end

  # --- Profile events ---

  @impl true
  def handle_event("validate_profile", %{"user" => profile_params}, socket) do
    user = socket.assigns.current_user

    profile_form =
      user
      |> Accounts.change_user_profile(profile_params)
      |> Map.put(:action, :validate)
      |> to_form()

    # Compute live previews
    effective_username =
      case Map.get(profile_params, "username", "") do
        u when is_binary(u) and u != "" -> u
        _ -> User.effective_username(user)
      end

    theme_preview = Map.get(profile_params, "theme", user.theme || "default")

    # Avatar preview stays as the currently saved URL — it only updates
    # after saving because we need to call the Gravatar API server-side
    {:noreply,
     socket
     |> assign(:profile_form, profile_form)
     |> assign(:theme_preview, theme_preview)
     |> assign(:effective_username, effective_username)}
  end

  def handle_event("update_profile", %{"user" => profile_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_profile(user, profile_params) do
      {:ok, updated_user} ->
        effective_username = User.effective_username(updated_user)

        profile_changeset = Accounts.change_user_profile(updated_user)

        socket =
          socket
          |> assign(:current_user, updated_user)
          |> assign(:profile_form, to_form(profile_changeset))
          |> assign(:effective_username, effective_username)
          |> assign(:theme_preview, updated_user.theme || "default")
          |> put_flash(:info, "Profile updated successfully.")

        # Invalidate cache and fetch updated Gravatar data asynchronously
        old_gravatar_id = user.gravatar_id
        if old_gravatar_id, do: GravatarCache.invalidate(old_gravatar_id)

        socket =
          case updated_user.gravatar_id do
            id when is_binary(id) and id != "" ->
              GravatarCache.invalidate(id)

              start_async(socket, :fetch_gravatar, fn ->
                GravatarCache.fetch(id)
              end)

            _ ->
              socket
              |> assign(:avatar_preview_url, nil)
              |> assign(:header_preview_url, nil)
              |> assign(:verified_accounts, [])
          end

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(Map.put(changeset, :action, :update)))}
    end
  end

  # --- Email events ---

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

  # --- Password events ---

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

  # --- Async callbacks ---

  @impl true
  def handle_async(:fetch_gravatar, {:ok, {:ok, result}}, socket) do
    %{
      avatar_url: avatar_url,
      header_image_url: header_image_url,
      verified_accounts: verified_accounts
    } = result

    {:noreply,
     socket
     |> assign(:avatar_preview_url, avatar_url)
     |> assign(:header_preview_url, header_image_url)
     |> assign(:verified_accounts, verified_accounts)}
  end

  @impl true
  def handle_async(:fetch_gravatar, {:ok, _error}, socket) do
    # Cache fetch returned an error; keep the default nil/empty assigns
    {:noreply, socket}
  end

  @impl true
  def handle_async(:fetch_gravatar, {:exit, _reason}, socket) do
    # Gravatar fetch failed; keep the default nil/empty assigns
    {:noreply, socket}
  end

  # --- Private helpers ---

  defp theme_preview_class("indigo"),
    do: "bg-gradient-to-r from-indigo-600 to-blue-500 border-indigo-300"

  defp theme_preview_class("violet"),
    do: "bg-gradient-to-r from-violet-600 to-purple-500 border-violet-300"

  defp theme_preview_class("emerald"),
    do: "bg-gradient-to-r from-emerald-600 to-teal-500 border-emerald-300"

  defp theme_preview_class("amber"),
    do: "bg-gradient-to-r from-amber-500 to-orange-500 border-amber-300"

  defp theme_preview_class("rose"),
    do: "bg-gradient-to-r from-rose-600 to-pink-500 border-rose-300"

  defp theme_preview_class(_),
    do: "bg-gradient-to-r from-indigo-500 to-blue-400 border-zinc-200"
end
