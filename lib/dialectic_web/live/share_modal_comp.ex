defmodule DialecticWeb.ShareModalComp do
  use DialecticWeb, :live_component
  alias Dialectic.DbActions.Sharing
  alias DialecticWeb.HighlightShare

  @impl true
  def update(assigns, socket) do
    share_node = Map.get(assigns, :share_node, true)

    socket =
      socket
      |> assign(Map.delete(assigns, :share_node))
      |> assign_new(:share_node, fn -> share_node end)
      |> assign_new(:share_target, fn -> :editor end)
      |> assign_new(:reader_path_endpoint, fn -> nil end)
      |> assign_new(:presentation_mode, fn -> nil end)
      |> assign_new(:show_preview, fn -> true end)
      |> assign_new(:selected_highlight, fn -> nil end)
      |> assign_new(:share_view, fn -> "reader" end)

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
        if Sharing.can_manage?(socket.assigns[:current_user], graph_struct) do
          Sharing.list_shares(graph_struct)
        else
          []
        end

      {:ok,
       socket
       |> assign(:shares, shares)
       |> assign(:email, "")}
    else
      {:ok,
       socket
       |> assign_new(:shares, fn -> [] end)
       |> assign_new(:email, fn -> "" end)}
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
    case Sharing.remove_invite(socket.assigns.graph_struct, email, socket.assigns[:current_user]) do
      :ok ->
        shares = Sharing.list_shares(socket.assigns.graph_struct)
        {:noreply, assign(socket, shares: shares)}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Only the grid owner can remove collaborators.")}
    end
  end

  @impl true
  def handle_event("toggle_share_node", _, socket) do
    {:noreply, assign(socket, share_node: !socket.assigns.share_node)}
  end

  @impl true
  def handle_event("select_share_view", %{"view" => view}, socket)
      when view in ["reader", "grid"] do
    {:noreply, assign(socket, share_view: view)}
  end

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_share_modal)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="share-modal-hook" phx-hook="Share">
      <div
        :if={@show}
        id={"share-modal-layer-#{@id}"}
        phx-hook="GlobalModalLayer"
        data-return-focus-id={
          if(@share_target == :reader,
            do: "reader-workspace-bar-share",
            else: "graph-workspace-bar-share"
          )
        }
        class="fixed inset-0 z-[10020] overflow-y-auto overscroll-contain"
        aria-labelledby="modal-title"
        role="dialog"
        aria-modal="true"
      >
        <div
          class="fixed inset-0 bg-slate-950/60"
          aria-hidden="true"
          phx-click="close"
          phx-target={@myself}
        >
        </div>
        <div class="relative flex min-h-full items-start justify-center p-3 sm:items-center sm:p-6 pointer-events-none">
          <div class="pointer-events-auto relative w-full max-w-lg rounded-2xl bg-white p-5 text-slate-950 shadow-xl sm:p-6">
            <button
              id="share-close"
              type="button"
              data-modal-close
              phx-click="close"
              phx-target={@myself}
              aria-label="Close sharing"
              class="absolute right-3 top-3 inline-flex h-11 w-11 items-center justify-center rounded-lg text-slate-600 hover:bg-stone-100 focus-visible:outline-2 focus-visible:outline-teal-800"
            ><.icon name="hero-x-mark" class="h-5 w-5" /></button>
            <div class="pr-10">
              <h2 id="modal-title" class="text-xl font-semibold">
                {if(quote_share?(@selected_highlight), do: "Share Quote", else: "Share Grid")}
              </h2>
              <p class="mt-1 break-words text-sm leading-5 text-slate-600">{@graph_struct.title}</p>
            </div>
            <p
              id="share-access-summary"
              class="mt-4 flex items-start gap-2 text-sm leading-5 text-slate-700"
            >
              <.icon
                name={if(@graph_struct.is_public, do: "hero-globe-alt", else: "hero-lock-closed")}
                class="mt-0.5 h-4 w-4 shrink-0 text-teal-800"
              />
              <span>
                <%= if @graph_struct.is_public do %>
                  Anyone can open this link. No account needed.
                <% else %>
                  <strong class="font-semibold">Anyone with this private link can open the grid.</strong>
                  Share it with people you trust. It stays out of the public community.
                <% end %>
              </span>
            </p>
            <button
              :if={
                !@graph_struct.is_public && Sharing.can_manage?(@current_user, @graph_struct) &&
                  !quote_share?(@selected_highlight)
              }
              id="share-public-settings"
              type="button"
              phx-click={
                JS.set_attribute({"open", ""}, to: "#share-access-settings")
                |> JS.focus(to: "#share-visibility-public")
              }
              class="mt-1 min-h-11 text-sm font-semibold text-teal-800 underline underline-offset-2"
            >Make it public for wider discovery</button>

            <div id="share-link-section" class="mt-4">
              <label for="share-url-input" class="text-xs font-semibold text-slate-600">
                {if(quote_share?(@selected_highlight), do: "Quote Share Link", else: "Link to share")}
              </label>
              <div class="mt-1.5 flex min-w-0 flex-wrap items-end gap-2">
                <div class="min-w-0 flex-1 basis-40">
                  <.input
                    id="share-url-input"
                    name="share_url"
                    type="text"
                    readonly
                    value={share_url(assigns)}
                    data-share-link-input
                    aria-label="Link to share"
                    class="block min-h-11 w-full rounded-lg border border-stone-400 bg-stone-50 px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-teal-700"
                  />
                </div>
                <button
                  id="share-copy-btn"
                  type="button"
                  data-share-copy={share_url(assigns)}
                  data-share-toast={copy_toast(assigns)}
                  data-analytics-event="grid_shared"
                  data-analytics-location="share_modal_copy"
                  data-analytics-share-method="copy_link"
                  class="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-teal-800 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-800"
                >
                  <span data-copy-icon><.icon name="hero-link" class="h-4 w-4" /></span>
                  <span data-copy-check class="hidden"><.icon name="hero-check" class="h-4 w-4" /></span>
                  <span data-copy-label>Copy link</span>
                </button>
              </div>
              <p :if={quote_share?(@selected_highlight)} class="mt-2 text-xs text-slate-600">
                Opens this exact highlight in the reader.
              </p>
            </div>

            <div id="share-native-container" data-native-share-container hidden class="mt-3">
              <button
                id="share-native-btn"
                type="button"
                data-native-share
                data-share-title={share_title(assigns)}
                data-share-text={share_text(assigns)}
                data-share-url={share_url(assigns)}
                data-analytics-event="grid_shared"
                data-analytics-location="share_modal_native"
                data-analytics-share-method="native_share"
                class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-lg border border-stone-400 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-stone-100 disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-teal-800"
              ><.icon name="hero-share" class="h-4 w-4" /> Share via your apps</button>
            </div>
            <p
              id="share-feedback"
              role="status"
              aria-live="polite"
              aria-atomic="true"
              class="mt-2 text-sm leading-5 text-teal-900 empty:hidden data-[state=error]:text-red-800"
            >
            </p>

            <div id="share-social-links" class="mt-4">
              <p class="mb-2 text-xs font-semibold text-slate-600">
                Send to someone or start a conversation
              </p>
              <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
                <a
                  :for={link <- social_links(assigns)}
                  id={"share-social-#{link.id}"}
                  href={link.url}
                  target={if(link.id != "email", do: "_blank")}
                  rel={if(link.id != "email", do: "noopener noreferrer")}
                  data-analytics-event="grid_shared"
                  data-analytics-location="share_modal_social"
                  data-analytics-share-method={link.id}
                  class="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-stone-300 px-3 py-2 text-sm font-medium text-slate-800 hover:border-teal-800 hover:bg-stone-50 focus-visible:outline-2 focus-visible:outline-teal-800"
                ><.icon name={link.icon} class="h-4 w-4 shrink-0" />{link.label}</a>
              </div>
            </div>

            <details
              :if={!quote_share?(@selected_highlight)}
              id="share-link-options"
              class="mt-5 border-t border-stone-300 pt-1"
            >
              <summary class="min-h-11 cursor-pointer py-3 text-sm font-semibold text-slate-800">
                Choose where the link starts
              </summary>
              <div class="space-y-3 pb-3">
                <button
                  :if={@selected_node}
                  id="share-node-toggle"
                  type="button"
                  role="switch"
                  aria-checked={to_string(@share_node)}
                  phx-click="toggle_share_node"
                  phx-target={@myself}
                  class="inline-flex min-h-11 w-full items-center gap-2 rounded-lg border border-stone-300 px-3 py-2 text-left text-sm text-slate-800"
                >
                  <.icon
                    name={if(@share_node, do: "hero-check-circle-solid", else: "hero-minus-circle")}
                    class="h-5 w-5 shrink-0 text-teal-800"
                  /> Start at the current answer
                </button>
                <div :if={@presentation_mode != :presenting}>
                  <p class="mb-2 text-xs font-semibold text-slate-600">Open in</p>
                  <div role="group" aria-label="Shared link view" class="grid grid-cols-2 gap-2">
                    <button
                      :for={
                        {value, label, icon} <- [
                          {"reader", "Read", "hero-document-text"},
                          {"grid", "Grid", "hero-squares-2x2"}
                        ]
                      }
                      id={"share-view-#{value}"}
                      type="button"
                      phx-click="select_share_view"
                      phx-value-view={value}
                      phx-target={@myself}
                      aria-pressed={to_string(@share_view == value)}
                      class="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-stone-400 px-3 py-2 text-sm text-slate-800 aria-pressed:border-teal-800 aria-pressed:bg-teal-800 aria-pressed:text-white focus-visible:outline-2 focus-visible:outline-teal-800"
                    ><.icon name={icon} class="h-4 w-4" />{label}</button>
                  </div>
                  <p class="mt-2 text-xs leading-5 text-slate-600">
                    Read is a simple starting point. Visitors can switch to Grid at any time.
                  </p>
                </div>
              </div>
            </details>

            <details
              :if={
                !quote_share?(@selected_highlight) &&
                  Sharing.can_manage?(@current_user, @graph_struct)
              }
              id="share-access-settings"
              class="border-t border-stone-300"
            >
              <summary class="min-h-11 cursor-pointer py-3 text-sm font-semibold text-slate-800">
                Who can view and contribute
              </summary>
              <div class="pb-3">
                <DialecticWeb.WorkspaceBarComp.visibility_dropdown
                  id="share-visibility"
                  inline
                  graph_struct={@graph_struct}
                  current_user={@current_user}
                />
                <DialecticWeb.LockComp.render id="share-lock-graph" graph_struct={@graph_struct} />
              </div>
            </details>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp share_url(assigns) do
    graph = assigns.graph_struct
    node = assigns[:share_node] && assigns[:selected_node]

    case assigns[:selected_highlight] do
      %{id: _id} = highlight ->
        HighlightShare.share_url(graph, highlight)

      _ ->
        base = DialecticWeb.Endpoint.url()

        params =
          []
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
          |> then(fn params ->
            if assigns.share_view == "reader" && node &&
                 is_binary(assigns[:reader_path_endpoint]) &&
                 assigns[:reader_path_endpoint] != "" do
              Keyword.put(params, :path, assigns.reader_path_endpoint)
            else
              params
            end
          end)

        path =
          if assigns.share_view == "grid" || assigns[:presentation_mode] == :presenting do
            graph_editor_path(graph, if(node, do: Map.get(node, :id, "")), params)
          else
            graph_path(graph, if(node, do: Map.get(node, :id, "")), params)
          end

        "#{base}#{path}"
    end
  end

  defp quote_share?(%{id: _id}), do: true
  defp quote_share?(_highlight), do: false

  defp share_title(%{selected_highlight: %{id: _id} = highlight, graph_struct: graph}) do
    HighlightShare.page_title(graph, highlight)
  end

  defp share_title(%{graph_struct: graph_struct}), do: graph_struct.title

  defp share_text(%{selected_highlight: %{id: _id} = highlight, graph_struct: graph}) do
    HighlightShare.share_text(graph, highlight)
  end

  defp share_text(%{graph_struct: graph_struct}) do
    "Check out \"#{graph_struct.title}\" on RationalGrid"
  end

  defp copy_toast(%{selected_highlight: %{id: _id}}), do: "Quote link copied to clipboard!"
  defp copy_toast(_assigns), do: "Link copied to clipboard!"

  defp social_links(assigns) do
    url = share_url(assigns)
    encoded_url = URI.encode_www_form(url)
    text = share_text(assigns)
    title = share_title(assigns)

    direct = [
      %{
        id: "whatsapp",
        label: "WhatsApp",
        icon: "brand-whatsapp",
        url: "https://wa.me/?#{URI.encode_query(%{text: text <> " " <> url})}"
      },
      %{
        id: "email",
        label: "Email",
        icon: "hero-envelope",
        url:
          "mailto:?#{URI.encode_query(%{subject: title, body: text <> "\n\n" <> url}, :rfc3986)}"
      }
    ]

    if assigns.graph_struct.is_public do
      direct ++
        [
          %{
            id: "x",
            label: "X",
            icon: "brand-twitter-x",
            url: "https://twitter.com/intent/tweet?#{URI.encode_query(%{text: text, url: url})}"
          },
          %{
            id: "linkedin",
            label: "LinkedIn",
            icon: "brand-linkedin",
            url: "https://www.linkedin.com/sharing/share-offsite/?url=#{encoded_url}"
          },
          %{
            id: "reddit",
            label: "Reddit",
            icon: "brand-reddit",
            url: "https://www.reddit.com/submit?#{URI.encode_query(%{url: url, title: title})}"
          }
        ]
    else
      direct
    end
  end
end
