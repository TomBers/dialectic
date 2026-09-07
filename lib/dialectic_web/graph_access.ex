defmodule DialecticWeb.GraphAccess do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3, redirect: 2]

  alias Dialectic.DbActions.{Graphs, Sharing}

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:graph_access, :handle_event, fn _event, _params, socket ->
       refresh(socket)
     end)
     |> attach_hook(:graph_access, :handle_params, fn _params, _uri, socket ->
       refresh(socket)
     end)
     |> attach_hook(:graph_access, :handle_info, fn
       {:graph_access_updated, title}, %{assigns: %{graph_id: title}} = socket ->
         {_status, socket} = refresh(socket)
         {:halt, socket}

       _message, socket ->
         {:cont, socket}
     end)}
  end

  defp refresh(%{assigns: %{graph_id: title}} = socket) when is_binary(title) do
    graph = Graphs.get_graph_by_title(title)
    token = socket.assigns[:token]

    accessible? =
      graph && !graph.is_deleted &&
        (Sharing.can_access?(socket.assigns[:current_user], graph) ||
           (is_binary(token) && is_binary(graph.share_token) &&
              Plug.Crypto.secure_compare(token, graph.share_token)))

    if accessible? do
      {:cont, assign(socket, graph_struct: graph, can_edit: !graph.is_locked)}
    else
      {:halt,
       socket
       |> put_flash(:error, "You no longer have access to this grid.")
       |> redirect(to: "/")}
    end
  end

  defp refresh(socket), do: {:cont, socket}
end
