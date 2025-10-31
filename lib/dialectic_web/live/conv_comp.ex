defmodule DialecticWeb.ConvComp do
  use DialecticWeb, :live_component
  alias DialecticWeb.Live.TextUtils

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      # Default cutoff length
      |> assign_new(:cut_off, fn -> 500 end)
      # Embedding flags for header and input visibility
      |> assign_new(:show_header?, fn -> true end)
      |> assign_new(:show_input?, fn -> true end)

    {:ok, socket}
  end

  defp get_message_type(node, _index) do
    case node.class do
      c when c in ["user", "question", "origin"] ->
        "user"

      c when c in ["answer", "thesis", "antithesis", "synthesis", "ideas", "deepdive"] ->
        "assistant"

      _ ->
        "assistant"
    end
  end
end
