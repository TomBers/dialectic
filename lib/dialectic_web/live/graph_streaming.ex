defmodule DialecticWeb.GraphStreaming do
  @moduledoc """
  Shared streaming and PubSub message handlers for graph LiveViews.

  ## Usage

      use DialecticWeb.GraphStreaming, preload_highlight_links: true

  The using module must implement:
  - `update_streaming_node(socket, updated_vertex, node_id)` (private)
  - `serialize_highlights(highlights)` (private) — returns a list of maps for client push
  - Have `streaming_nodes`, `graph_topic`, `node`, `highlights` in socket assigns

  ## Options
  - `:preload_highlight_links` - whether to preload highlight `:links` association
    (default: false). GraphLive uses true; LinearGraphLive uses false.
  """

  defmacro __using__(opts) do
    preload_links = Keyword.get(opts, :preload_highlight_links, false)

    quote do
      # ── Streaming PubSub (injected by GraphStreaming) ──────────────

      def handle_info({:stream_chunk, updated_vertex, :node_id, node_id}, socket) do
        Phoenix.PubSub.broadcast(
          Dialectic.PubSub,
          socket.assigns.graph_topic,
          {:stream_chunk_broadcast, updated_vertex, :node_id, node_id, self()}
        )

        {:noreply, update_streaming_node(socket, updated_vertex, node_id)}
      end

      def handle_info(
            {:stream_chunk_broadcast, updated_vertex, :node_id, node_id, sender_pid},
            socket
          ) do
        if self() == sender_pid do
          {:noreply, socket}
        else
          {:noreply, update_streaming_node(socket, updated_vertex, node_id)}
        end
      end

      # ── Highlight PubSub (injected by GraphStreaming) ──────────────

      def handle_info({:created, highlight}, socket) do
        highlight =
          unquote(
            if preload_links do
              quote do: Dialectic.Repo.preload(highlight, :links)
            else
              quote do: highlight
            end
          )

        highlights = [highlight | socket.assigns.highlights]

        {:noreply,
         Phoenix.Component.assign(socket, highlights: highlights)
         |> Phoenix.LiveView.push_event("highlights_loaded", %{
           highlights: serialize_highlights(highlights)
         })}
      end

      def handle_info({:updated, highlight}, socket) do
        highlight =
          unquote(
            if preload_links do
              quote do: Dialectic.Repo.preload(highlight, :links)
            else
              quote do: highlight
            end
          )

        highlights =
          Enum.map(socket.assigns.highlights, fn h ->
            if h.id == highlight.id, do: highlight, else: h
          end)

        {:noreply,
         Phoenix.Component.assign(socket, highlights: highlights)
         |> Phoenix.LiveView.push_event("highlights_loaded", %{
           highlights: serialize_highlights(highlights)
         })}
      end

      def handle_info({:deleted, highlight}, socket) do
        highlights =
          Enum.reject(socket.assigns.highlights, fn h -> h.id == highlight.id end)

        {:noreply,
         Phoenix.Component.assign(socket, highlights: highlights)
         |> Phoenix.LiveView.push_event("highlights_loaded", %{
           highlights: serialize_highlights(highlights)
         })}
      end
    end
  end
end
