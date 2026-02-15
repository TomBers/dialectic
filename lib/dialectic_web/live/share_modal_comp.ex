defmodule DialecticWeb.ShareModalComp do
  use DialecticWeb, :live_component
  alias Dialectic.DbActions.Sharing

  @impl true
  def update(assigns, socket) do
    assigns =
      if assigns[:graph_struct] do
        case Sharing.ensure_share_token(assigns.graph_struct) do
          {:ok, graph} -> Map.put(assigns, :graph_struct, graph)
          _ -> assigns
        end
      else
        assigns
      end

    socket = assign(socket, assigns)

    shares =
      if socket.assigns[:graph_struct] do
        Sharing.list_shares(socket.assigns.graph_struct)
      else
        []
      end

    {:ok,
     socket
     |> assign(:shares, shares)
     |> assign(:email, "")
     |> assign_new(:share_node, fn -> false end)}
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
    <div>
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
                      Share Map
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
                            Public Map
                          </p>
                        </div>
                        <p class="text-xs text-green-700 mt-1">
                          Anyone with the link can view this map. Share it freely on social media or embed it on your website.
                        </p>
                      </div>
                    <% else %>
                      <div class="p-2 bg-amber-50 border border-amber-200 rounded-md">
                        <div class="flex items-center">
                          <.icon name="hero-lock-closed" class="w-4 h-4 text-amber-600 mr-2" />
                          <p class="text-sm text-amber-800 font-medium">
                            Private Map
                          </p>
                        </div>
                        <p class="text-xs text-amber-700 mt-1">
                          Only people with the access token can view this map. Make it public to share more widely.
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
                        value={share_url(@graph_struct, @share_node && @selected_node)}
                        class="flex-1 min-w-0 block w-full px-3 py-2 rounded-l-md border-gray-300 sm:text-sm bg-white text-gray-500"
                        id="share-url-input"
                      />
                      <button
                        type="button"
                        class="inline-flex items-center px-3 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-500 text-sm hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        data-copy-url={share_url(@graph_struct, @share_node && @selected_node)}
                        onclick="navigator.clipboard.writeText(this.dataset.copyUrl).then(() => alert('Link copied to clipboard!'))"
                        aria-label="Copy to clipboard"
                        id="share-copy-btn"
                      >
                        <.icon name="hero-clipboard-document" class="w-4 h-4" />
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
                  
    <!-- Social Share Section -->
                  <%= if @graph_struct.is_public do %>
                    <div class="mt-4">
                      <label class="block text-sm font-medium text-gray-700 mb-2">
                        Share on Social
                      </label>
                      <div class="flex space-x-2">
                        <a
                          href={"https://twitter.com/intent/tweet?text=#{URI.encode_www_form("Check out this map on MuDG: " <> @graph_struct.title)}&url=#{URI.encode_www_form(share_url(@graph_struct, @share_node && @selected_node))}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          X (Twitter)
                        </a>
                        <a
                          href={"https://www.linkedin.com/sharing/share-offsite/?url=#{URI.encode_www_form(share_url(@graph_struct, @share_node && @selected_node))}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          LinkedIn
                        </a>
                        <a
                          href={"https://www.reddit.com/submit?url=#{URI.encode_www_form(share_url(@graph_struct, @share_node && @selected_node))}&title=#{URI.encode_www_form(@graph_struct.title)}"}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Reddit
                        </a>
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
                        ><iframe src={share_url(@graph_struct, @share_node && @selected_node)} width="100%" height="600px" frameborder="0" allowfullscreen></iframe></textarea>
                        <button
                          type="button"
                          class="inline-flex items-center px-3 py-2 border border-l-0 border-gray-300 rounded-r-md bg-gray-50 text-gray-500 text-sm hover:bg-gray-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          data-copy-text={"<iframe src=\"#{share_url(@graph_struct, @share_node && @selected_node)}\" width=\"100%\" height=\"600px\" frameborder=\"0\" allowfullscreen></iframe>"}
                          onclick="navigator.clipboard.writeText(this.dataset.copyText).then(() => alert('Embed code copied!'))"
                          aria-label="Copy embed code"
                        >
                          <.icon name="hero-clipboard-document" class="w-4 h-4" />
                        </button>
                      </div>
                      <p class="mt-1 text-xs text-gray-500">
                        Embed this public map on your website or blog.
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

  defp share_url(graph, node) do
    base = DialecticWeb.Endpoint.url()
    path = "/g/#{graph.slug}"

    params =
      []
      |> then(fn p -> if !graph.is_public, do: [{"token", graph.share_token} | p], else: p end)
      |> then(fn p -> if node, do: [{"node", Map.get(node, :id, "")} | p], else: p end)

    case params do
      [] -> "#{base}#{path}"
      _ -> "#{base}#{path}?#{URI.encode_query(params)}"
    end
  end
end
