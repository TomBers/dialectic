defmodule DialecticWeb.UserSettingsLive do
  use DialecticWeb, :live_view

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User
  alias Dialectic.Accounts.ProfileBanner
  alias Dialectic.Accounts.ProfileLinks

  @theme_options [
    {"Light", "default"},
    {"Indigo", "indigo"},
    {"Violet", "violet"},
    {"Emerald", "emerald"},
    {"Amber", "amber"},
    {"Rose", "rose"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <.modal id="profile-banner-picker-modal" class="border-zinc-200">
      <div class="space-y-5">
        <div>
          <h2 id="profile-banner-picker-title" class="text-lg font-semibold text-zinc-900">
            Choose or upload a profile banner
          </h2>
          <p id="profile-banner-picker-description" class="mt-1 text-sm text-zinc-600">
            This banner sits at the top of your public profile home.
          </p>
        </div>

        <div
          id="banner-cropper"
          phx-hook="BannerCropper"
          phx-update="ignore"
          class="rounded-xl border border-zinc-200 bg-zinc-50 p-4"
        >
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="text-sm font-semibold text-zinc-900">Upload your own banner</h3>
              <p class="mt-1 text-xs text-zinc-500">
                Crop a wide image to match the profile header. Uploaded banners override SVG choices.
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <label
                for="banner-file-input"
                class="inline-flex cursor-pointer items-center justify-center rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800"
              >
                Choose image
              </label>
              <input
                id="banner-file-input"
                data-banner-input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                class="sr-only"
              />
            </div>
          </div>

          <div data-banner-editor class="mt-4 hidden rounded-xl border border-zinc-200 bg-white p-4">
            <canvas
              data-banner-canvas
              width="640"
              height="168"
              class="h-auto w-full cursor-move rounded-lg border border-zinc-200 bg-white shadow-sm"
            >
            </canvas>

            <div class="mt-4 grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end">
              <div>
                <label for="banner-zoom" class="text-xs font-medium text-zinc-600">Zoom</label>
                <input
                  id="banner-zoom"
                  data-banner-zoom
                  type="range"
                  min="1"
                  max="3"
                  step="0.01"
                  value="1"
                  class="mt-2 w-full accent-indigo-600"
                />
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  data-banner-save
                  class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                >
                  Save banner
                </button>
                <button
                  type="button"
                  data-banner-cancel
                  class="rounded-lg border border-zinc-200 bg-white px-4 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                >
                  Cancel
                </button>
              </div>
            </div>

            <p data-banner-error class="mt-3 hidden text-sm text-red-600"></p>
          </div>
        </div>

        <%= if @uploaded_banner_url do %>
          <div class="flex flex-col gap-2 rounded-xl border border-emerald-200 bg-emerald-50 p-3 sm:flex-row sm:items-center sm:justify-between">
            <p class="text-sm font-medium text-emerald-800">
              Uploaded banner is active.
            </p>
            <button
              type="button"
              id="remove-uploaded-banner-button"
              phx-click="remove_banner"
              class="inline-flex items-center justify-center rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
            >
              Remove uploaded banner
            </button>
          </div>
        <% end %>

        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <button
            type="button"
            id="profile-banner-option-theme-gradient"
            phx-click={
              hide_modal("profile-banner-picker-modal")
              |> JS.push("select_profile_banner", value: %{id: "theme-gradient"})
            }
            class={[
              "overflow-hidden rounded-xl border-2 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600",
              is_nil(@uploaded_banner_url) && is_nil(@current_banner_id) &&
                "border-indigo-500 ring-2 ring-indigo-200",
              (@uploaded_banner_url || @current_banner_id) && "border-zinc-200"
            ]}
          >
            <div class="h-32 overflow-hidden sm:h-40">
              <div class="h-full w-full bg-gradient-to-r from-indigo-500 to-blue-400"></div>
            </div>
            <div class="flex items-center justify-between px-3 py-2">
              <span class="text-sm font-semibold text-zinc-900">Theme gradient</span>
              <%= if is_nil(@uploaded_banner_url) && is_nil(@current_banner_id) do %>
                <span class="text-xs font-semibold text-indigo-600">Selected</span>
              <% end %>
            </div>
          </button>

          <%= for banner <- @profile_banners do %>
            <button
              type="button"
              id={"profile-banner-option-" <> banner.id}
              phx-click={
                hide_modal("profile-banner-picker-modal")
                |> JS.push("select_profile_banner", value: %{id: banner.id})
              }
              class={[
                "overflow-hidden rounded-xl border-2 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600",
                is_nil(@uploaded_banner_url) && @current_banner_id == banner.id &&
                  "border-indigo-500 ring-2 ring-indigo-200",
                (@uploaded_banner_url || @current_banner_id != banner.id) && "border-zinc-200"
              ]}
            >
              <div class="h-32 overflow-hidden sm:h-40">
                <img
                  src={banner.path}
                  alt={banner.name <> " banner preview"}
                  class="h-full w-full object-cover"
                />
              </div>
              <div class="flex items-center justify-between px-3 py-2">
                <span class="text-sm font-semibold text-zinc-900">{banner.name}</span>
                <%= if is_nil(@uploaded_banner_url) && @current_banner_id == banner.id do %>
                  <span class="text-xs font-semibold text-indigo-600">Selected</span>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>

        <p class="text-xs text-zinc-500">
          Banner patterns are local SVGs selected from the free SVGBackgrounds.com set.
          <a
            href="https://www.svgbackgrounds.com/set/free-svg-backgrounds-and-patterns/"
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium text-indigo-600 hover:text-indigo-500 underline"
          >
            Attribution
          </a>
        </p>
      </div>
    </.modal>

    <div class="mx-auto max-w-3xl px-6 py-14">
      <div class="rounded-2xl border border-zinc-200/70 bg-white shadow-sm">
        <div class="border-b border-zinc-100 px-6 py-5">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-wide text-zinc-500">
                Profile settings
              </p>
              <h1 class="mt-1 text-xl font-semibold tracking-tight text-zinc-900">
                Profile home
              </h1>
              <p class="mt-1 max-w-2xl text-sm text-zinc-600">
                Shape the public page where your grids, ideas, and ways to connect are gathered.
              </p>
            </div>

            <.link
              href={~p"/users/log_out"}
              method="delete"
              id="user-settings-logout"
              class="inline-flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg border border-zinc-200 bg-white text-zinc-500 shadow-sm hover:bg-zinc-50 hover:text-zinc-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-900"
              aria-label="Log out"
              title="Log out"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
            </.link>
          </div>

          <div class="mt-4 flex flex-wrap items-center gap-2 text-sm">
            <span class="text-zinc-500">Public URL</span>
            <.link
              navigate={~p"/u/#{@effective_username}"}
              id="user-settings-view-profile"
              class="inline-flex items-center gap-1.5 rounded-lg border border-zinc-200 bg-zinc-50 px-2.5 py-1.5 font-medium text-zinc-800 hover:border-indigo-200 hover:bg-indigo-50 hover:text-indigo-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              /u/{@effective_username}
              <.icon name="hero-arrow-top-right-on-square" class="h-3.5 w-3.5" />
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
                  <h2 class="text-base font-semibold text-zinc-900">Public profile</h2>
                  <p class="mt-1 text-sm text-zinc-600">
                    Customize the page people see when they visit
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
                <button
                  type="button"
                  id="profile-banner-picker-button"
                  phx-click={show_modal("profile-banner-picker-modal")}
                  class="group relative block h-32 w-full overflow-hidden text-left sm:h-40"
                  aria-label="Choose profile banner"
                  title="Choose profile banner"
                >
                  <%= cond do %>
                    <% @banner_preview_url -> %>
                      <img
                        src={@banner_preview_url}
                        alt="Profile banner preview"
                        class="h-full w-full object-cover"
                      />
                    <% true -> %>
                      <span class="block h-full w-full bg-gradient-to-r from-indigo-500 to-blue-400">
                      </span>
                  <% end %>

                  <span class="absolute bottom-2 right-2 rounded-full bg-black/45 px-3 py-1 text-xs font-semibold text-white opacity-0 shadow-sm transition group-hover:opacity-100 group-focus-visible:opacity-100">
                    Choose banner
                  </span>
                </button>

                <div class="relative px-6 pb-6">
                  <%!-- Avatar Preview --%>
                  <div class="mb-6 flex flex-col gap-4 -mt-12 sm:-mt-14 sm:flex-row sm:items-end">
                    <div class="h-24 w-24 sm:h-28 sm:w-28 rounded-full border-4 border-white shadow-sm flex items-center justify-center overflow-hidden flex-shrink-0">
                      <%= if @avatar_preview_url do %>
                        <img
                          src={@avatar_preview_url}
                          alt="Avatar preview"
                          class="h-full w-full object-cover rounded-full"
                        />
                      <% else %>
                        <div class="h-full w-full flex items-center justify-center rounded-full bg-indigo-100 text-indigo-600 text-3xl font-bold">
                          {String.first(@effective_username) |> String.upcase()}
                        </div>
                      <% end %>
                    </div>
                    <div class="min-w-0 pb-1 sm:pt-12">
                      <p class="text-sm font-medium text-zinc-900">{@effective_username}</p>
                      <%= if @avatar_preview_url do %>
                        <p class="text-xs text-emerald-600 mt-0.5">Uploaded photo</p>
                      <% end %>
                    </div>
                  </div>

                  <div
                    id="avatar-upload-section"
                    class="mb-6 rounded-xl border border-zinc-200 bg-white p-4"
                  >
                    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <h3 class="text-sm font-semibold text-zinc-900">Profile photo</h3>
                        <p class="mt-1 text-xs text-zinc-500">
                          Upload and crop the avatar shown beside your username.
                        </p>
                      </div>

                      <%= if @avatar_preview_url do %>
                        <button
                          type="button"
                          id="avatar-remove-button"
                          phx-click="remove_avatar"
                          class="inline-flex items-center justify-center rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                        >
                          Remove photo
                        </button>
                      <% end %>
                    </div>

                    <div
                      id="avatar-cropper"
                      phx-hook="AvatarCropper"
                      phx-update="ignore"
                      class="mt-4 space-y-4"
                    >
                      <div>
                        <label
                          for="avatar-file-input"
                          class="inline-flex cursor-pointer items-center justify-center rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800"
                        >
                          Choose photo
                        </label>
                        <input
                          id="avatar-file-input"
                          data-avatar-input
                          type="file"
                          accept="image/png,image/jpeg,image/webp"
                          class="sr-only"
                        />
                      </div>

                      <div
                        data-avatar-editor
                        class="hidden rounded-xl border border-zinc-200 bg-zinc-50 p-4"
                      >
                        <div class="flex flex-col gap-4 md:flex-row">
                          <div class="flex justify-center">
                            <canvas
                              data-avatar-canvas
                              width="320"
                              height="320"
                              class="h-80 w-80 max-w-full cursor-move rounded-full border border-zinc-200 bg-white shadow-sm"
                            >
                            </canvas>
                          </div>

                          <div class="flex-1 space-y-4">
                            <div>
                              <label for="avatar-zoom" class="text-xs font-medium text-zinc-600">
                                Zoom
                              </label>
                              <input
                                id="avatar-zoom"
                                data-avatar-zoom
                                type="range"
                                min="1"
                                max="3"
                                step="0.01"
                                value="1"
                                class="mt-2 w-full accent-indigo-600"
                              />
                            </div>

                            <div class="flex flex-wrap gap-2">
                              <button
                                type="button"
                                data-avatar-rotate-left
                                class="rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                              >
                                Rotate left
                              </button>
                              <button
                                type="button"
                                data-avatar-rotate-right
                                class="rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                              >
                                Rotate right
                              </button>
                            </div>

                            <p data-avatar-error class="hidden text-sm text-red-600"></p>

                            <div class="flex flex-wrap gap-2 pt-2">
                              <button
                                type="button"
                                data-avatar-save
                                class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
                              >
                                Save photo
                              </button>
                              <button
                                type="button"
                                data-avatar-cancel
                                class="rounded-lg border border-zinc-200 bg-white px-4 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                              >
                                Cancel
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <.simple_form
                    for={@profile_form}
                    id="profile_form"
                    phx-submit="update_profile"
                    phx-change="validate_profile"
                  >
                    <div>
                      <h3 class="text-sm font-semibold text-zinc-900">Profile basics</h3>
                      <p class="mt-1 text-xs text-zinc-500">
                        Set the username, short intro, and color theme for your public profile home.
                      </p>
                    </div>

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
                      placeholder="Tell people a bit about yourself and what you explore on RationalGrid..."
                      class="mt-2 block min-h-[6rem] w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                    />

                    <input
                      type="hidden"
                      id="profile-theme-value"
                      name={@profile_form[:theme].name}
                      value={@theme_preview}
                    />

                    <div>
                      <div class="mb-2 flex items-center justify-between gap-3">
                        <p class="text-sm font-semibold text-zinc-900">Profile colour</p>
                        <p class="text-xs font-medium text-zinc-500">{theme_label(@theme_preview)}</p>
                      </div>
                      <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
                        <%= for {label, value} <- theme_options() do %>
                          <button
                            type="button"
                            id={"profile-theme-option-#{value}"}
                            phx-click="select_profile_theme"
                            phx-value-theme={value}
                            class={[
                              "group rounded-xl border bg-white p-2 text-left transition hover:border-indigo-300 hover:shadow-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600",
                              @theme_preview == value && "border-indigo-500 ring-2 ring-indigo-100",
                              @theme_preview != value && "border-zinc-200"
                            ]}
                            aria-pressed={to_string(@theme_preview == value)}
                          >
                            <span class={[
                              "block h-10 rounded-lg border transition-colors",
                              theme_preview_class(value)
                            ]}>
                            </span>
                            <span class={[
                              "mt-2 block text-xs font-semibold",
                              @theme_preview == value && "text-indigo-700",
                              @theme_preview != value && "text-zinc-700"
                            ]}>
                              {label}
                            </span>
                          </button>
                        <% end %>
                      </div>
                    </div>

                    <:actions>
                      <.button
                        phx-disable-with="Saving..."
                        class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                      >
                        Save profile
                      </.button>
                    </:actions>
                  </.simple_form>

                  <div
                    id="profile-links-section"
                    class="mt-10 rounded-xl border border-zinc-200 bg-white p-4"
                  >
                    <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <h3 class="text-sm font-semibold text-zinc-900">Profile links</h3>
                        <p class="mt-1 text-xs text-zinc-500">
                          Add the places people should use to follow your work or get in touch.
                        </p>
                      </div>
                      <button
                        type="button"
                        id="add-profile-link-button"
                        phx-click="add_profile_link"
                        class="inline-flex items-center justify-center rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm font-semibold text-zinc-700 shadow-sm hover:bg-zinc-50"
                      >
                        <.icon name="hero-plus" class="mr-1.5 h-4 w-4" /> Add link
                      </button>
                    </div>

                    <.form
                      for={@profile_links_form}
                      id="profile_links_form"
                      phx-change="validate_profile_links"
                      phx-submit="update_profile_links"
                    >
                      <div class="space-y-4">
                        <%= for {link, index} <- Enum.with_index(@profile_links_rows) do %>
                          <div class="rounded-lg border border-zinc-100 bg-zinc-50/60 p-3">
                            <div class="grid gap-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)_auto] sm:items-start">
                              <.input
                                id={"profile_links_#{index}_label"}
                                name={"profile_links[links][#{index}][label]"}
                                type="text"
                                label={if index == 0, do: "Label", else: nil}
                                value={link["label"]}
                                placeholder="GitHub, Email, Discord"
                                class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                              />

                              <.input
                                id={"profile_links_#{index}_value"}
                                name={"profile_links[links][#{index}][value]"}
                                type="text"
                                label={if index == 0, do: "URL or email", else: nil}
                                value={link["value"]}
                                placeholder="https://example.com or you@example.com"
                                class="mt-2 block w-full rounded-lg border border-zinc-200 bg-white text-zinc-900 shadow-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 sm:text-sm sm:leading-6"
                              />

                              <button
                                type="button"
                                id={"remove-profile-link-#{index}"}
                                phx-click="remove_profile_link"
                                phx-value-index={index}
                                class="mt-2 inline-flex h-10 w-10 items-center justify-center rounded-lg border border-zinc-200 bg-white text-zinc-600 shadow-sm hover:bg-zinc-50 sm:mt-8"
                                aria-label={"Remove profile link #{index + 1}"}
                                title="Remove link"
                              >
                                <.icon name="hero-trash" class="h-4 w-4" />
                              </button>
                            </div>
                          </div>
                        <% end %>
                      </div>

                      <%= if @profile_links_error do %>
                        <p class="mt-3 text-sm text-red-600">{@profile_links_error}</p>
                      <% end %>

                      <div class="mt-4 flex items-center justify-end">
                        <.button
                          phx-disable-with="Saving links..."
                          class="inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                        >
                          Save profile links
                        </.button>
                      </div>
                    </.form>
                  </div>
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
                  <h2 class="text-base font-semibold text-zinc-900">Account email</h2>
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
                  <h2 class="text-base font-semibold text-zinc-900">Account password</h2>
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
      |> assign(:avatar_preview_url, user.avatar_path)
      |> assign(:uploaded_banner_url, user.banner_path)
      |> assign(:current_banner_id, user.profile_banner)
      |> assign(:banner_preview_url, effective_banner_url(user))
      |> assign(:profile_banners, ProfileBanner.all())
      |> assign(:profile_links_rows, ProfileLinks.form_rows(user.profile_links))
      |> assign(:profile_links_form, profile_links_form())
      |> assign(:profile_links_error, nil)
      |> assign(:theme_preview, theme_preview)

    {:ok, socket}
  end

  # --- Profile events ---

  @impl true
  def handle_event("select_profile_banner", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    banner_id = banner_id_from_param(id)

    case select_profile_banner(user, banner_id) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:profile_form, to_form(Accounts.change_user_profile(updated_user)))
         |> assign(:uploaded_banner_url, nil)
         |> assign(:current_banner_id, updated_user.profile_banner)
         |> assign(:banner_preview_url, effective_banner_url(updated_user))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to update profile banner.")}
    end
  end

  def handle_event("save_banner", %{"image_data" => image_data}, socket) do
    case Accounts.update_user_banner(socket.assigns.current_user, image_data) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:uploaded_banner_url, updated_user.banner_path)
         |> assign(:banner_preview_url, effective_banner_url(updated_user))
         |> put_flash(:info, "Profile banner updated successfully.")}

      {:error, :too_large} ->
        {:noreply, put_flash(socket, :error, "Profile banner image is too large.")}

      {:error, :invalid_image} ->
        {:noreply,
         put_flash(socket, :error, "Please choose a valid PNG, JPG, or WebP banner image.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to save profile banner.")}
    end
  end

  def handle_event("remove_banner", _params, socket) do
    case Accounts.remove_user_banner(socket.assigns.current_user) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:uploaded_banner_url, nil)
         |> assign(:banner_preview_url, effective_banner_url(updated_user))
         |> put_flash(:info, "Uploaded banner removed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to remove uploaded banner.")}
    end
  end

  def handle_event("save_avatar", %{"image_data" => image_data}, socket) do
    case Accounts.update_user_avatar(socket.assigns.current_user, image_data) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:avatar_preview_url, updated_user.avatar_path)
         |> put_flash(:info, "Profile photo updated successfully.")}

      {:error, :too_large} ->
        {:noreply, put_flash(socket, :error, "Profile photo is too large.")}

      {:error, :invalid_image} ->
        {:noreply, put_flash(socket, :error, "Please choose a valid PNG, JPG, or WebP image.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to save profile photo.")}
    end
  end

  def handle_event("validate_profile_links", %{"profile_links" => params}, socket) do
    rows = params |> ProfileLinks.rows_from_params() |> ensure_profile_link_rows()

    {:noreply,
     socket
     |> assign(:profile_links_rows, rows)
     |> assign(:profile_links_error, profile_links_error(rows))}
  end

  def handle_event("add_profile_link", _params, socket) do
    rows = socket.assigns.profile_links_rows ++ [ProfileLinks.empty_row()]

    {:noreply,
     socket
     |> assign(:profile_links_rows, rows)
     |> assign(:profile_links_error, profile_links_error(rows))}
  end

  def handle_event("remove_profile_link", %{"index" => index}, socket) do
    rows =
      socket.assigns.profile_links_rows
      |> List.delete_at(parse_index(index))
      |> ensure_profile_link_rows()

    {:noreply,
     socket
     |> assign(:profile_links_rows, rows)
     |> assign(:profile_links_error, profile_links_error(rows))}
  end

  def handle_event("update_profile_links", %{"profile_links" => params}, socket) do
    rows = params |> ProfileLinks.rows_from_params() |> ensure_profile_link_rows()

    case Accounts.update_user_profile_links(socket.assigns.current_user, rows) do
      {:ok, updated_user} ->
        rows = ProfileLinks.form_rows(updated_user.profile_links)

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:profile_links_rows, rows)
         |> assign(:profile_links_error, nil)
         |> put_flash(:info, "Profile links updated successfully.")}

      {:error, message} when is_binary(message) ->
        {:noreply,
         socket
         |> assign(:profile_links_rows, rows)
         |> assign(:profile_links_error, message)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:profile_links_rows, rows)
         |> assign(:profile_links_error, "Unable to save profile links.")}
    end
  end

  def handle_event("remove_avatar", _params, socket) do
    case Accounts.remove_user_avatar(socket.assigns.current_user) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:avatar_preview_url, nil)
         |> put_flash(:info, "Profile photo removed.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to remove profile photo.")}
    end
  end

  def handle_event("select_profile_theme", %{"theme" => theme}, socket) do
    theme =
      if theme in theme_values() do
        theme
      else
        socket.assigns.theme_preview
      end

    {:noreply, assign(socket, :theme_preview, theme)}
  end

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

    banner_preview_url =
      case socket.assigns.uploaded_banner_url do
        path when is_binary(path) and path != "" ->
          path

        _ ->
          profile_params
          |> Map.get("profile_banner", user.profile_banner)
          |> ProfileBanner.url()
      end

    {:noreply,
     socket
     |> assign(:profile_form, profile_form)
     |> assign(:banner_preview_url, banner_preview_url)
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
          |> assign(:avatar_preview_url, updated_user.avatar_path)
          |> assign(:current_banner_id, updated_user.profile_banner)
          |> assign(:banner_preview_url, effective_banner_url(updated_user))
          |> assign(:theme_preview, updated_user.theme || "default")
          |> put_flash(:info, "Profile updated successfully.")

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

  # --- Private helpers ---

  defp effective_banner_url(%User{banner_path: path}) when is_binary(path) and path != "",
    do: path

  defp effective_banner_url(%User{profile_banner: banner}), do: ProfileBanner.url(banner)

  defp select_profile_banner(user, banner_id) do
    with {:ok, user} <- Accounts.remove_user_banner(user) do
      Accounts.update_user_profile(user, %{profile_banner: banner_id})
    end
  end

  defp banner_id_from_param("theme-gradient"), do: nil
  defp banner_id_from_param(id), do: id

  defp profile_links_form, do: to_form(%{}, as: :profile_links)

  defp ensure_profile_link_rows([]), do: [ProfileLinks.empty_row()]
  defp ensure_profile_link_rows(rows), do: rows

  defp profile_links_error(rows) do
    case ProfileLinks.prepare_for_storage(rows) do
      {:ok, _profile_links} -> nil
      {:error, message} -> message
    end
  end

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end

  defp parse_index(index) when is_integer(index), do: index
  defp parse_index(_), do: 0

  defp theme_options, do: @theme_options
  defp theme_values, do: Enum.map(@theme_options, &elem(&1, 1))

  defp theme_label(theme) do
    @theme_options
    |> Enum.find_value("Light", fn {label, value} ->
      if value == theme, do: label
    end)
  end

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
