defmodule DialecticWeb.ShareModalComp do
  use DialecticWeb, :live_component
  alias Dialectic.DbActions.Sharing

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Only run expensive DB queries (ensure_share_token, list_shares) when
    # the modal is actually visible. Every parent re-render (e.g. node click)
    # triggers update/2, so skipping the queries when the modal is hidden
    # avoids unnecessary DB traffic.
    if socket.assigns[:show] do
      graph_struct = socket.assigns[:graph_struct]

      {socket, graph_struct} =
        if graph_struct do
          case Sharing.ensure_share_token(graph_struct) do
            {:ok, graph} -> {assign(socket, :graph_struct, graph), graph}
            _ -> {socket, graph_struct}
          end
        else
          {socket, graph_struct}
        end

      shares =
        if graph_struct do
          Sharing.list_shares(graph_struct)
        else
          []
        end

      {:ok,
       socket
       |> assign(:shares, shares)
       |> assign(:email, "")
       |> assign_new(:share_node, fn -> false end)}
    else
      {:ok,
       socket
       |> assign_new(:shares, fn -> [] end)
       |> assign_new(:email, fn -> "" end)
       |> assign_new(:share_node, fn -> false end)}
    end
  end

  @impl true
  def handle_event("validate", %{"email" => email}, socket) do
    {:noreply, assign(socket, email: email)}
  end

  @impl true
  def handle_event("invite", %{"email" => _email}, socket) do
    # case Sharing.invite_user(socket.assigns.graph_struct, email) do
    #   {:ok, _share} ->
    #     %{
    #       "email_type" => "invite",
    #       "to" => email,
    #       "inviter" => socket.assigns.current_user.email,
    #       "graph_title" => socket.assigns.graph_struct.title,
    #       "link" => share_url(socket.assigns.graph_struct)
    #     }
    #     |> Dialectic.Workers.EmailWorker.new()
    #     |> Oban.insert()

    #     shares = Sharing.list_shares(socket.assigns.graph_struct)

    #     {:noreply,
    #      socket |> assign(shares: shares, email: "") |> put_flash(:info, "Invitation sent")}

    #   {:error, _changeset} ->
    #     {:noreply, put_flash(socket, :error, "Could not invite user")}
    # end
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_share", %{"email" => email}, socket) do
    Sharing.remove_invite(socket.assigns.graph_struct, email)
    shares = Sharing.list_shares(socket.assigns.graph_struct)
    {:noreply, assign(socket, shares: shares)}
  end

  @impl true
  def handle_event("toggle_share_node", _, socket) do
    {:noreply, assign(socket, share_node: !socket.assigns.share_node)}
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_share_modal)
    {:noreply, assign(socket, share_node: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="share-modal-hook" phx-hook="Share">
      <%= if @show do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="flex items-end justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
            <div
              class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75"
              aria-hidden="true"
              phx-click="close"
              phx-target={@myself}
            >
            </div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
              &#8203;
            </span>

            <div class="inline-block px-4 pt-5 pb-4 text-left align-bottom transition-all transform bg-white rounded-lg shadow-xl sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
              <div class="absolute top-0 right-0 pt-4 pr-4">
                <button
                  type="button"
                  phx-click="close"
                  phx-target={@myself}
                  class="text-gray-400 bg-white rounded-md hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  <span class="sr-only">Close</span>
                  <.icon name="hero-x-mark" class="w-6 h-6" />
                </button>
              </div>

              <div class="sm:flex sm:items-start">
                <div class="flex items-center justify-center flex-shrink-0 w-12 h-12 mx-auto bg-indigo-100 rounded-full sm:mx-0 sm:h-10 sm:w-10">
                  <.icon name="hero-share" class="w-6 h-6 text-indigo-600" />
                </div>
                <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                  <h3 class="text-lg font-medium leading-6 text-gray-900" id="modal-title">
                    <%= if @graph_struct.is_public do %>
                      Share Grid
                    <% else %>
                      Manage Collaborators
                    <% end %>
                  </h3>
                  <div class="mt-2">
                    <%= if @graph_struct.is_public do %>
                      <div class="p-2 bg-green-50 border border-green-200 rounded-md">
                        <div class="flex items-center">
                          <.icon name="hero-globe-alt" class="w-4 h-4 text-green-600 mr-2" />
                          <p class="text-sm text-green-800 font-medium">
                            Public Grid
                          </p>
                        </div>
                        <p class="text-xs text-green-700 mt-1">
                          Anyone with the link can view this grid. Share it freely on social media or embed it on your website.
                        </p>
                      </div>
                    <% else %>
                      <div class="p-2 bg-amber-50 border border-amber-200 rounded-md">
                        <div class="flex items-center">
                          <.icon name="hero-lock-closed" class="w-4 h-4 text-amber-600 mr-2" />
                          <p class="text-sm text-amber-800 font-medium">
                            Private Grid
                          </p>
                        </div>
                        <p class="text-xs text-amber-700 mt-1">
                          Only people with the access token can view this grid. Make it public to share more widely.
                        </p>
                      </div>
                    <% end %>
                  </div>

                  <%= if Map.get(@graph_struct.data || %{}, "preview_image") do %>
                    <div class="mt-4 border rounded-lg overflow-hidden shadow-sm bg-gray-50">
                      <img
                        src={@graph_struct.data["preview_image"]}
                        alt="Graph Preview"
                        class="w-full max-h-48 object-contain"
                      />
                    </div>
                  <% else %>
                    <div class="mt-4 flex items-center justify-center h-32 bg-gray-50 border border-dashed border-gray-300 rounded-lg text-gray-400 text-sm">
                      <span class="animate-pulse">Generating preview...</span>
                    </div>
                  <% end %>
                  
    <!-- Public Link Section -->
                  <div class="mt-4 p-3 bg-gray-50 rounded-md">
                    <label class="block text-sm font-medium text-gray-700">
                      <%= if @graph_struct.is_public do %>
                        Public Share Link
                      <% else %>
                        Private Access Link
                      <% end %>
                    </label>
                    <%= if @selected_node do %>
                      <div class="mt-2 mb-2">
                        <label class="inline-flex items-center gap-2 cursor-pointer select-none text-sm text-gray-600">
                          <button
                            type="button"
                            phx-click="toggle_share_node"
                            phx-target={@myself}
                            class={[
                              "relative inline-flex h-5 w-9 shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2",
                              if(@share_node, do: "bg-indigo-600", else: "bg-gray-200")
                            ]}
                            role="switch"
                            aria-checked={to_string(@share_node)}
                            id="share-node-toggle"
                          >
                            <span class={[
                              "pointer-events-none inline-block h-4 w-4 rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                              if(@share_node, do: "translate-x-4", else: "translate-x-0")
                            ]}>
                            </span>
                          </button>
                          <span>
                            Link to current node
                            <span class="text-xs text-gray-400">
                              ({Map.get(@selected_node, :id, "")})
                            </span>
                          </span>
                        </label>
                      </div>
                    <% end %>
                    <div class="mt-1 flex rounded-md shadow-sm">
                      <input
                        type="text"
                        readonly
                        value={share_url(assigns)}
                        class="flex-1 min-w-0 block w-full px-3 py-2 rounded-l-md border-gray-300 sm:text-sm bg-white text-gray-500"
                        id="share-url-input"
                      />
                      <button
                        type="button"
                        class="inline-flex items-center px-3 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-500 text-sm hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        data-share-copy={share_url(assigns)}
                        data-share-toast="Link copied to clipboard!"
                        aria-label="Copy to clipboard"
                        id="share-copy-btn"
                      >
                        <span data-copy-icon>
                          <.icon name="hero-clipboard-document" class="w-4 h-4" />
                        </span>
                        <span data-copy-check class="hidden">
                          <.icon name="hero-check" class="w-4 h-4 text-green-600" />
                        </span>
                      </button>
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      <%= if @graph_struct.is_public do %>
                        Anyone can access this link without authentication.
                      <% else %>
                        Includes secure access token. Only share with trusted collaborators.
                      <% end %>
                    </p>
                  </div>
                  
    <!-- Native Web Share API (mobile) -->
                  <div class="mt-3">
                    <button
                      type="button"
                      data-native-share
                      data-share-title={@graph_struct.title}
                      data-share-text={"Check out \"#{@graph_struct.title}\" on RationalGrid"}
                      data-share-url={share_url(assigns)}
                      class="hidden w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 border border-indigo-300 shadow-sm text-sm font-medium rounded-lg text-indigo-700 bg-indigo-50 hover:bg-indigo-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                    >
                      <.icon name="hero-share" class="w-5 h-5" /> Share via your device...
                    </button>
                  </div>
                  
    <!-- Social Share Section -->
                  <%= if @graph_struct.is_public do %>
                    <div class="mt-4">
                      <label class="block text-sm font-medium text-gray-700 mb-2">
                        Share on Social
                      </label>
                      <div class="grid grid-cols-3 gap-2">
                        <%!-- X / Twitter --%>
                        <a
                          href={"https://twitter.com/intent/tweet?text=#{URI.encode_www_form("Check out this grid on RationalGrid: " <> @graph_struct.title)}&url=#{URI.encode_www_form(share_url(assigns))}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-50 hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                          </svg>
                          <span>X</span>
                        </a>
                        <%!-- LinkedIn --%>
                        <a
                          href={"https://www.linkedin.com/sharing/share-offsite/?url=#{URI.encode_www_form(share_url(assigns))}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-blue-50 hover:border-blue-300 hover:text-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                          </svg>
                          <span>LinkedIn</span>
                        </a>
                        <%!-- Reddit --%>
                        <a
                          href={"https://www.reddit.com/submit?url=#{URI.encode_www_form(share_url(assigns))}&title=#{URI.encode_www_form(@graph_struct.title)}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-orange-50 hover:border-orange-300 hover:text-orange-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0zm5.01 4.744c.688 0 1.25.561 1.25 1.249a1.25 1.25 0 0 1-2.498.056l-2.597-.547-.8 3.747c1.824.07 3.48.632 4.674 1.488.308-.309.73-.491 1.207-.491.968 0 1.754.786 1.754 1.754 0 .716-.435 1.333-1.01 1.614a3.111 3.111 0 0 1 .042.52c0 2.694-3.13 4.87-7.004 4.87-3.874 0-7.004-2.176-7.004-4.87 0-.183.015-.366.043-.534A1.748 1.748 0 0 1 4.028 12c0-.968.786-1.754 1.754-1.754.463 0 .898.196 1.207.49 1.207-.883 2.878-1.43 4.744-1.487l.885-4.182a.342.342 0 0 1 .14-.197.35.35 0 0 1 .238-.042l2.906.617a1.214 1.214 0 0 1 1.108-.701zM9.25 12C8.561 12 8 12.562 8 13.25c0 .687.561 1.248 1.25 1.248.687 0 1.248-.561 1.248-1.249 0-.688-.561-1.249-1.249-1.249zm5.5 0c-.687 0-1.248.561-1.248 1.25 0 .687.561 1.248 1.249 1.248.688 0 1.249-.561 1.249-1.249 0-.687-.562-1.249-1.25-1.249zm-5.466 3.99a.327.327 0 0 0-.231.094.33.33 0 0 0 0 .463c.842.842 2.484.913 2.961.913.477 0 2.105-.056 2.961-.913a.361.361 0 0 0 .029-.463.33.33 0 0 0-.464 0c-.547.533-1.684.73-2.512.73-.828 0-1.979-.196-2.512-.73a.326.326 0 0 0-.232-.095z" />
                          </svg>
                          <span>Reddit</span>
                        </a>
                        <%!-- WhatsApp --%>
                        <a
                          href={"https://wa.me/?text=#{URI.encode_www_form("Check out \"" <> @graph_struct.title <> "\" on RationalGrid: " <> share_url(assigns))}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-green-50 hover:border-green-300 hover:text-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z" />
                          </svg>
                          <span>WhatsApp</span>
                        </a>
                        <%!-- Instagram (copies link) --%>
                        <button
                          type="button"
                          data-share-copy={share_url(assigns)}
                          data-share-toast="Link copied! Paste it in your Instagram story or post."
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-pink-50 hover:border-pink-300 hover:text-pink-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <span data-copy-icon>
                            <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                              <path d="M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126.667.666 1.336 1.079 2.126 1.384.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384.666-.667 1.079-1.335 1.384-2.126.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126C21.319 1.347 20.651.935 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227-.224.562-.479.96-.899 1.382-.419.419-.824.679-1.38.896-.42.164-1.065.36-2.235.413-1.274.057-1.649.07-4.859.07-3.211 0-3.586-.015-4.859-.074-1.171-.061-1.816-.256-2.236-.421-.569-.224-.96-.479-1.379-.899-.421-.419-.69-.824-.9-1.38-.165-.42-.359-1.065-.42-2.235-.045-1.26-.061-1.649-.061-4.844 0-3.196.016-3.586.061-4.861.061-1.17.255-1.814.42-2.234.21-.57.479-.96.9-1.381.419-.419.81-.689 1.379-.898.42-.166 1.051-.361 2.221-.421 1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678a6.162 6.162 0 100 12.324 6.162 6.162 0 100-12.324zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4zm7.846-10.405a1.441 1.441 0 11-2.882 0 1.441 1.441 0 012.882 0z" />
                            </svg>
                          </span>
                          <span data-copy-check class="hidden">
                            <.icon name="hero-check" class="w-5 h-5 text-green-600" />
                          </span>
                          <span>Instagram</span>
                        </button>
                        <%!-- Copy Link --%>
                        <button
                          type="button"
                          data-share-copy={share_url(assigns)}
                          data-share-toast="Link copied to clipboard!"
                          class="inline-flex flex-col items-center justify-center gap-1 px-3 py-2.5 border border-gray-200 shadow-sm text-xs font-medium rounded-lg text-gray-700 bg-white hover:bg-gray-100 hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors"
                        >
                          <span data-copy-icon>
                            <.icon name="hero-link" class="w-5 h-5" />
                          </span>
                          <span data-copy-check class="hidden">
                            <.icon name="hero-check" class="w-5 h-5 text-green-600" />
                          </span>
                          <span>Copy Link</span>
                        </button>
                      </div>
                    </div>
                  <% end %>
                  
    <!-- Embed Code Section -->
                  <%= if @graph_struct.is_public do %>
                    <div class="mt-4 p-3 bg-gray-50 rounded-md">
                      <label class="block text-sm font-medium text-gray-700">Embed Code</label>
                      <div class="mt-1 flex rounded-md shadow-sm">
                        <textarea
                          readonly
                          rows="3"
                          class="flex-1 min-w-0 block w-full px-3 py-2 rounded-l-md border-gray-300 sm:text-sm bg-white text-gray-500 font-mono text-xs"
                          onclick="this.select()"
                        ><iframe src={share_url(assigns)} width="100%" height="600px" frameborder="0" allowfullscreen></iframe></textarea>
                        <button
                          type="button"
                          class="inline-flex items-center px-3 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-500 text-sm hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          data-share-copy={"<iframe src=\"#{share_url(assigns)}\" width=\"100%\" height=\"600px\" frameborder=\"0\" allowfullscreen></iframe>"}
                          data-share-toast="Embed code copied!"
                          aria-label="Copy embed code"
                        >
                          <span data-copy-icon>
                            <.icon name="hero-clipboard-document" class="w-4 h-4" />
                          </span>
                          <span data-copy-check class="hidden">
                            <.icon name="hero-check" class="w-4 h-4 text-green-600" />
                          </span>
                        </button>
                      </div>
                      <p class="mt-1 text-xs text-gray-500">
                        Embed this public grid on your website or blog.
                      </p>
                    </div>
                  <% end %>
                  
    <!-- Invite Section (Hidden) -->
                  <%!-- <div class="mt-6">
                    <form phx-submit="invite" phx-change="validate" phx-target={@myself}>
                      <label for="email" class="block text-sm font-medium text-gray-700">
                        Invite people
                      </label>
                      <div class="mt-1 flex rounded-md shadow-sm">
                        <input
                          type="email"
                          name="email"
                          id="email"
                          value={@email}
                          class="flex-1 min-w-0 block w-full px-3 py-2 rounded-l-md border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                          placeholder="email@example.com"
                        />
                        <button
                          type="submit"
                          class="inline-flex items-center px-3 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-500 text-sm hover:bg-gray-100"
                        >
                          Invite
                        </button>
                      </div>
                    </form>
                  </div> --%>
                  
    <!-- Shares List (Hidden) -->
                  <%!-- <div class="mt-6">
                    <h4 class="text-sm font-medium text-gray-700">People with access</h4>
                    <ul class="mt-3 border-t border-gray-200 divide-y divide-gray-200">
                      <%= for share <- @shares do %>
                        <li class="py-3 flex justify-between items-center">
                          <div class="flex items-center">
                            <span class="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center text-xs font-medium text-gray-500">
                              {String.slice(share.email, 0, 1) |> String.upcase()}
                            </span>
                            <span class="ml-3 text-sm font-medium text-gray-900">
                              {share.email}
                            </span>
                          </div>
                          <div class="flex items-center">
                            <span class="mr-2 text-xs text-gray-500">{share.permission}</span>
                            <button
                              phx-click="remove_share"
                              phx-value-email={share.email}
                              phx-target={@myself}
                              class="text-red-600 hover:text-red-900"
                            >
                              <.icon name="hero-x-mark" class="w-4 h-4" />
                            </button>
                          </div>
                        </li>
                      <% end %>

                      <%= if Enum.empty?(@shares) do %>
                        <li class="py-3 text-sm text-gray-500 italic">
                          No additional people invited.
                        </li>
                      <% end %>
                    </ul>
                  </div> --%>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp share_url(assigns) do
    graph = assigns.graph_struct
    node = assigns[:share_node] && assigns[:selected_node]
    base = DialecticWeb.Endpoint.url()
    path = "/g/#{graph.slug}"

    params =
      []
      |> then(fn p -> if !graph.is_public, do: [{"token", graph.share_token} | p], else: p end)
      |> then(fn p -> if node, do: [{"node", Map.get(node, :id, "")} | p], else: p end)
      |> then(fn p ->
        if assigns[:presentation_mode] == :presenting and
             is_list(assigns[:presentation_slide_ids]) and
             length(assigns[:presentation_slide_ids]) > 0 do
          slides = Enum.join(assigns.presentation_slide_ids, ",")

          p =
            [{"present", "true"}, {"slides", slides} | p]

          if assigns[:presentation_title] && assigns[:presentation_title] != "" do
            [{"title", assigns.presentation_title} | p]
          else
            p
          end
        else
          p
        end
      end)

    case params do
      [] -> "#{base}#{path}"
      _ -> "#{base}#{path}?#{URI.encode_query(params)}"
    end
  end
end
