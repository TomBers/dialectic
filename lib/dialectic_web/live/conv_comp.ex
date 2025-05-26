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
      |> assign_new(:message_text, fn -> "" end)

    {:ok, socket}
  end

  defp get_message_type(node, index) do
    case node.class do
      "user" -> "user"
      "answer" -> "assistant"
      _ -> if rem(index, 2) == 0, do: "user", else: "assistant"
    end
  end
end
