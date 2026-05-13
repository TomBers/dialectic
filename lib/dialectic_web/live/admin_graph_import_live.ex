defmodule DialecticWeb.AdminGraphImportLive do
  use DialecticWeb, :live_view

  alias Dialectic.Graph.Importer

  @max_file_size 10_000_000

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    unless current_user && current_user.is_admin do
      {:ok,
       socket
       |> put_flash(:error, "Access denied.")
       |> redirect(to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(
         page_title: "Import Graph",
         form: to_form(default_form_params(), as: :graph_import),
         preview: nil,
         uploaded_graph_data: nil,
         imported_graph: nil
       )
       |> allow_upload(:graph_json,
         accept: ~w(.json application/json),
         max_entries: 1,
         max_file_size: @max_file_size,
         auto_upload: true
       )}
    end
  end

  @impl true
  def handle_event("validate", %{"graph_import" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :graph_import))}
  end

  @impl true
  def handle_event("preview", _params, socket) do
    params = socket.assigns.form.params || default_form_params()

    case uploaded_graph_data(socket) do
      {:ok, %{data: data} = cached_upload} ->
        {:noreply,
         assign(socket,
           preview: build_preview(data, params),
           uploaded_graph_data: cached_upload,
           imported_graph: nil
         )}

      {:error, message} ->
        {:noreply,
         socket
         |> assign(preview: nil, uploaded_graph_data: nil, imported_graph: nil)
         |> put_flash(:error, message)}
    end
  end

  @impl true
  def handle_event("import", %{"graph_import" => params}, socket) do
    with {:ok, %{data: data} = cached_upload} <- uploaded_graph_data(socket),
         {:ok, attrs} <- import_attrs(params, socket.assigns.current_user),
         {:ok, graph} <- Importer.import_data(data, attrs) do
      {:noreply,
       socket
       |> put_flash(:info, "Imported #{graph.title}.")
       |> assign(
         form: to_form(params, as: :graph_import),
         preview: build_preview(data, params),
         uploaded_graph_data: cached_upload,
         imported_graph: graph
       )}
    else
      {:error, message} when is_binary(message) ->
        {:noreply, put_flash(socket, :error, message)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, changeset_error_message(changeset))}
    end
  end

  defp default_form_params do
    %{
      "title" => "",
      "slug" => "",
      "tags" => "",
      "is_public" => "true",
      "is_published" => "true",
      "prompt_mode" => "university"
    }
  end

  defp uploaded_graph_data(socket) do
    entries = socket.assigns.uploads.graph_json.entries
    cached_upload = socket.assigns.uploaded_graph_data

    cond do
      entries == [] and is_cached_upload?(cached_upload) ->
        {:ok, cached_upload}

      entries == [] ->
        {:error, "Choose a graph JSON file first."}

      is_cached_upload?(cached_upload) and cached_upload.ref == hd(entries).ref ->
        {:ok, cached_upload}

      Enum.any?(entries, &(&1.done? == false)) ->
        {:error, "Wait for the upload to finish before previewing or importing."}

      true ->
        consume_uploaded_entries(socket, :graph_json, fn %{path: path}, entry ->
          result =
            with {:ok, content} <- File.read(path),
                 {:ok, data} <- Jason.decode(content),
                 {:ok, graph_data} <- extract_graph_data(data),
                 :ok <- Importer.validate_data(graph_data) do
              {:ok, %{ref: entry.ref, data: graph_data}}
            else
              {:error, %Jason.DecodeError{} = error} ->
                {:error, "Invalid JSON: #{Exception.message(error)}"}

              {:error, message} when is_binary(message) ->
                {:error, message}

              {:error, reason} ->
                {:error, "Could not read upload: #{inspect(reason)}"}
            end

          {:ok, result}
        end)
        |> case do
          [{:ok, cached_upload}] -> {:ok, cached_upload}
          [{:error, message}] -> {:error, message}
          [] -> {:error, "Upload is no longer available. Choose the file again."}
        end
    end
  end

  defp is_cached_upload?(%{ref: ref, data: data}) when is_binary(ref) and is_map(data), do: true
  defp is_cached_upload?(_cached_upload), do: false

  defp extract_graph_data(%{"metadata" => _metadata, "graph" => graph}) when is_map(graph) do
    {:ok, graph}
  end

  defp extract_graph_data(%{"nodes" => _nodes, "edges" => _edges} = graph), do: {:ok, graph}

  defp extract_graph_data(_data) do
    {:error, "JSON must be either a graph with nodes/edges or an artifact with metadata/graph."}
  end

  defp import_attrs(params, current_user) do
    title = params |> Map.get("title", "") |> String.trim()

    if title == "" do
      {:error, "Title is required."}
    else
      {:ok,
       %{
         title: title,
         slug: params |> Map.get("slug", "") |> String.trim() |> blank_to_nil(),
         tags: params |> Map.get("tags", "") |> split_tags(),
         is_public: truthy?(params["is_public"]),
         is_published: truthy?(params["is_published"]),
         is_deleted: false,
         is_locked: false,
         prompt_mode:
           params
           |> Map.get("prompt_mode", "university")
           |> String.trim()
           |> blank_to_default("university"),
         user_id: current_user.id
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp build_preview(data, params) do
    nodes = data["nodes"] || []
    edges = data["edges"] || []

    %{
      title: params |> Map.get("title", "") |> String.trim(),
      slug: params |> Map.get("slug", "") |> String.trim(),
      nodes: length(nodes),
      edges: length(edges),
      compound_nodes: Enum.count(nodes, &Map.get(&1, "compound", false)),
      idea_nodes: Enum.count(nodes, &(not Map.get(&1, "compound", false))),
      sample_nodes: Enum.take(nodes, 5)
    }
  end

  defp split_tags(tags) do
    tags
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp blank_to_default("", default), do: default
  defp blank_to_default(value, _default), do: value

  defp changeset_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _opts}} -> "#{field} #{message}" end)
    |> Enum.join(", ")
    |> case do
      "" -> "Could not import graph."
      message -> "Could not import graph: #{message}."
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-6 py-10">
      <div class="mb-8">
        <.link
          navigate={~p"/admin/curated"}
          class="text-sm font-semibold text-indigo-600 hover:text-indigo-500"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4 inline" /> Back to admin
        </.link>
        <h1 class="mt-4 text-2xl font-bold text-gray-900">Import Graph from JSON</h1>
        <p class="mt-2 text-sm text-gray-500">
          Upload a graph JSON file, preview its shape, then upsert it into the graphs table.
        </p>
      </div>

      <div class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <.form for={@form} id="graph-import-form" phx-change="validate" phx-submit="import">
          <div class="space-y-5">
            <div>
              <.label for="graph-json-upload">Graph JSON file</.label>
              <.live_file_input
                upload={@uploads.graph_json}
                id="graph-json-upload"
                class="mt-2 block w-full rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700"
              />
              <p class="mt-1 text-xs text-gray-500">
                Accepts raw graph JSON or artifact JSON with metadata and graph keys. Max 10MB.
              </p>

              <%= for entry <- @uploads.graph_json.entries do %>
                <div class="mt-2 text-sm text-gray-600">
                  <span>{entry.client_name}</span>
                  <span class="ml-2">{entry.progress}%</span>
                </div>
              <% end %>

              <%= for {_ref, message} <- @uploads.graph_json.errors do %>
                <p class="mt-1 text-sm text-red-600">{inspect(message)}</p>
              <% end %>
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@form[:title]} id="graph-import-title" label="Title" required />
              <.input field={@form[:slug]} id="graph-import-slug" label="Slug (optional)" />
            </div>

            <.input
              field={@form[:tags]}
              id="graph-import-tags"
              label="Tags"
              placeholder="philosophy, leisure, work"
            />

            <div class="grid gap-4 md:grid-cols-3">
              <.input
                field={@form[:prompt_mode]}
                id="graph-import-prompt-mode"
                type="select"
                label="Prompt mode"
                options={[
                  {"Expert", "expert"},
                  {"University", "university"},
                  {"High school", "high_school"},
                  {"Simple", "simple"}
                ]}
              />
              <.input
                field={@form[:is_public]}
                id="graph-import-public"
                type="checkbox"
                label="Public"
              />
              <.input
                field={@form[:is_published]}
                id="graph-import-published"
                type="checkbox"
                label="Published"
              />
            </div>

            <div class="flex gap-3">
              <button
                type="button"
                phx-click="preview"
                class="inline-flex items-center gap-2 rounded-lg border border-gray-300 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50"
              >
                <.icon name="hero-eye" class="h-4 w-4" /> Preview
              </button>
              <button
                type="submit"
                class="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
              >
                <.icon name="hero-arrow-up-tray" class="h-4 w-4" /> Import / Update Graph
              </button>
            </div>
          </div>
        </.form>
      </div>

      <%= if @preview do %>
        <div class="mt-8 rounded-xl border border-green-200 bg-green-50 p-6">
          <h2 class="text-lg font-semibold text-green-950">Preview</h2>
          <dl class="mt-4 grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-xs text-green-700">Nodes</dt>
              <dd class="font-semibold">{@preview.nodes}</dd>
            </div>
            <div>
              <dt class="text-xs text-green-700">Edges</dt>
              <dd class="font-semibold">{@preview.edges}</dd>
            </div>
            <div>
              <dt class="text-xs text-green-700">Idea nodes</dt>
              <dd class="font-semibold">{@preview.idea_nodes}</dd>
            </div>
            <div>
              <dt class="text-xs text-green-700">Group nodes</dt>
              <dd class="font-semibold">{@preview.compound_nodes}</dd>
            </div>
            <div>
              <dt class="text-xs text-green-700">Title</dt>
              <dd class="font-semibold">{@preview.title}</dd>
            </div>
            <div>
              <dt class="text-xs text-green-700">Slug</dt>
              <dd class="font-semibold">{@preview.slug}</dd>
            </div>
          </dl>

          <h3 class="mt-5 text-sm font-semibold text-green-950">Sample nodes</h3>
          <div class="mt-2 space-y-2">
            <%= for node <- @preview.sample_nodes do %>
              <div class="rounded-lg bg-white p-3 text-sm shadow-sm">
                <p class="font-semibold text-gray-900">{node["id"]} · {node["class"]}</p>
                <p class="mt-1 line-clamp-2 text-gray-600">{node["content"]}</p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @imported_graph do %>
        <div class="mt-8 rounded-xl border border-indigo-200 bg-indigo-50 p-6">
          <h2 class="text-lg font-semibold text-indigo-950">Imported</h2>
          <p class="mt-2 text-sm text-indigo-900">
            {@imported_graph.title} is now saved with {@preview.nodes} nodes and {@preview.edges} edges.
          </p>
          <.link
            navigate={graph_path(@imported_graph)}
            class="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-indigo-700 hover:text-indigo-600"
          >
            Open graph <.icon name="hero-arrow-right" class="h-4 w-4" />
          </.link>
        </div>
      <% end %>
    </div>
    """
  end
end
