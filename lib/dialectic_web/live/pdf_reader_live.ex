defmodule DialecticWeb.PdfReaderLive do
  use DialecticWeb, :live_view

  # 50MB
  @max_pdf_size 50 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:pdf,
        accept: ~w(.pdf application/pdf),
        max_entries: 1,
        max_file_size: @max_pdf_size,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> assign(pdf_url: nil, selections: [])

    {:ok, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    uploaded_urls =
      consume_uploaded_entries(socket, :pdf, fn %{path: path}, entry ->
        dest_url = persist_upload!(path, entry)
        {:ok, dest_url}
      end)

    pdf_url = List.first(uploaded_urls) || nil
    {:noreply, assign(socket, pdf_url: pdf_url)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, pdf_url: nil)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    entries = socket.assigns.uploads.pdf.entries || []

    IO.puts(
      "PdfReaderLive.validate entries=#{length(entries)} progresses=#{inspect(Enum.map(entries, & &1.progress))}"
    )

    {:noreply, socket}
  end

  def handle_event("reply-and-answer", %{"vertex" => %{"content" => content}}, socket) do
    text =
      content
      |> String.replace_prefix("Please explain: ", "")
      |> String.trim()

    selection = %{id: System.unique_integer([:positive]), text: text}

    {:noreply, assign(socket, selections: [selection | socket.assigns.selections || []])}
  end

  def handle_event("clear_selections", _params, socket) do
    {:noreply, assign(socket, selections: [])}
  end

  def handle_progress(:pdf, entry, socket) do
    IO.puts(
      "PdfReaderLive.progress name=#{entry.client_name} progress=#{entry.progress} done?=#{entry.done?}"
    )

    if entry.done? do
      url =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          dest_url = persist_upload!(path, entry)
          {:ok, dest_url}
        end)

      {:noreply, assign(socket, pdf_url: url)}
    else
      {:noreply, socket}
    end
  end

  defp persist_upload!(tmp_path, entry) do
    uploads_dir =
      :code.priv_dir(:dialectic)
      |> Path.join("static")
      |> Path.join("uploads")

    File.mkdir_p!(uploads_dir)

    ext =
      entry.client_type
      |> guess_ext(entry.client_name)

    filename = unique_filename(ext)
    dest_path = Path.join(uploads_dir, filename)

    File.cp!(tmp_path, dest_path)
    "/uploads/#{filename}"
  end

  defp guess_ext("application/pdf", _client_name), do: ".pdf"

  defp guess_ext(_mime, client_name) do
    ext = Path.extname(client_name || "")
    if String.downcase(ext) in [".pdf"], do: ext, else: ".pdf"
  end

  defp unique_filename(ext) do
    ts = System.system_time(:second)
    rand = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    "#{ts}-#{rand}#{ext}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto px-4 py-6">
      <div class="mb-6">
        <h1 class="text-xl font-semibold text-zinc-900">PDF Reader (Minimal)</h1>
        <p class="text-sm text-zinc-600">Upload a PDF, then view it inline.</p>
        <p class="text-xs text-zinc-500">Entries: {length(@uploads.pdf.entries)}</p>
      </div>

      <%= if is_nil(@pdf_url) do %>
        <.form
          for={%{}}
          id="pdf-upload-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-4"
        >
          <div
            class="border-2 border-dashed rounded-lg p-6 text-center text-zinc-600 hover:bg-zinc-50 transition"
            phx-drop-target={@uploads.pdf.ref}
          >
            <p class="mb-3">Drag and drop a PDF here or click to select one</p>
            <div class="flex items-center justify-center">
              <.live_file_input upload={@uploads.pdf} class="block text-sm" />
            </div>
            <%= for err <- upload_errors(@uploads.pdf) do %>
              <p class="mt-3 text-sm text-rose-600">Upload error: {err}</p>
            <% end %>
          </div>

          <div :for={entry <- @uploads.pdf.entries} class="mt-3 text-sm">
            <div class="flex items-center justify-between">
              <span>{entry.client_name}</span>
              <span>{entry.progress}%</span>
            </div>
            <div class="h-2 bg-zinc-200 rounded">
              <div class="h-2 bg-blue-500 rounded" style={"width: #{entry.progress}%;"}></div>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <.button type="submit" class="px-4 py-2" disabled={Enum.empty?(@uploads.pdf.entries)}>
              Upload
            </.button>
            <p class="text-xs text-zinc-500">Max size: 50MB • Accepts: .pdf</p>
          </div>
        </.form>
      <% else %>
        <div class="mb-4 flex items-center justify-between">
          <div class="text-sm text-zinc-700">
            Uploaded file:
            <a
              href={@pdf_url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-blue-600 hover:underline"
            >
              {@pdf_url}
            </a>
          </div>
          <.button phx-click="reset" class="px-3 py-1.5 text-sm">Upload another</.button>
        </div>

        <div
          id="pdf-preview"
          phx-hook="TextSelectionHook"
          class="w-full overflow-auto border rounded-lg bg-zinc-100 relative"
        >
          <div class="selection-actions hidden absolute z-10">
            <button type="button" class="px-2 py-1 text-sm rounded-md bg-blue-600 text-white shadow">
              Save selection
            </button>
          </div>
          <div
            id="pdf-view"
            phx-hook="PdfViewer"
            data-url={@pdf_url}
            data-scale="1.2"
            data-pages="3"
            class="relative"
          >
          </div>
        </div>

        <div class="mt-4 space-y-3">
          <p class="text-xs text-zinc-500">
            If the PDF does not render inline in your browser, use the link above to open it in a new tab.
          </p>

          <%= if length(@selections) > 0 do %>
            <div class="border rounded-lg p-3 bg-white">
              <div class="flex items-center justify-between mb-2">
                <h2 class="text-sm font-semibold text-zinc-800">Saved selections</h2>
                <.button phx-click="clear_selections" class="px-2 py-1 text-xs">Clear</.button>
              </div>
              <ul class="list-disc pl-5 space-y-1">
                <%= for sel <- @selections do %>
                  <li class="text-sm text-zinc-700">{sel.text}</li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Using Phoenix.Component.upload_errors/1 directly
end
