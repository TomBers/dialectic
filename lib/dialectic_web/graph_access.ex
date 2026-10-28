defmodule DialecticWeb.GraphAccess do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, put_flash: 3, redirect: 2, push_event: 3]

  alias Dialectic.DbActions.{Graphs, Sharing}

  @editing_events ~w(
    answer reply-and-answer branch_list submit_guided_paths apply_guided_next_action
    submit_explore_modal node_branch node_combine node_related_ideas node_regenerate
    node_clarify node_assumptions node_counterexample node_implications node_blind_spots
    node_says_who node_who_disagrees node_steel_man node_what_if
    delete_node node_move node:join_group node:leave_group start_stream delete_stream
    execute_combine set_prompt_mode
  )
  @sign_in_message "Sign in or create an account to contribute to this grid."

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:graph_access, :handle_event, fn event, _params, socket ->
       with {:cont, socket} <- refresh(socket) do
         if event in @editing_events, do: authorize_edit(socket, event), else: {:cont, socket}
       end
     end)
     |> attach_hook(:graph_access, :handle_params, fn _params, _uri, socket ->
       refresh(socket)
     end)
     |> attach_hook(:graph_access, :handle_info, fn
       {:graph_access_updated, title}, %{assigns: %{graph_id: title}} = socket ->
         {_status, socket} = refresh(socket)
         {:halt, socket}

       {action, params}, socket when action in [:selection_action, :answer_action] ->
         with {:cont, socket} <- refresh(socket) do
           if socket.assigns[:current_user] do
             {:cont, socket}
           else
             request_id = params[:request_id] || params["request_id"]

             {:halt,
              socket
              |> assign(show_login_modal: true)
              |> push_event("selection:result", %{
                request_id: request_id,
                status: "error",
                message: @sign_in_message
              })}
           end
         end

       _message, socket ->
         {:cont, socket}
     end)}
  end

  defp refresh(%{assigns: %{graph_id: title}} = socket) when is_binary(title) do
    graph = Graphs.get_graph_by_title(title)
    token = socket.assigns[:token]

    user = socket.assigns[:current_user]

    if Sharing.can_access?(user, graph, token) do
      {:cont,
       assign(socket, graph_struct: graph, can_edit: Sharing.can_edit?(user, graph, token))}
    else
      {:halt,
       socket
       |> put_flash(:error, "You no longer have access to this grid.")
       |> redirect(to: "/")}
    end
  end

  defp refresh(socket), do: {:cont, socket}

  defp authorize_edit(socket, event) do
    cond do
      is_nil(socket.assigns[:current_user]) ->
        {:halt,
         socket
         |> assign(show_login_modal: true)
         |> put_flash(:error, @sign_in_message)
         |> sync_denied_action(event)}

      !socket.assigns.can_edit ->
        {:halt, socket |> put_flash(:error, "This graph is locked") |> sync_denied_action(event)}

      true ->
        {:cont, socket}
    end
  end

  defp sync_denied_action(socket, "set_prompt_mode") do
    mode = socket.assigns.graph_struct.prompt_mode || "university"

    push_event(socket, "answer_level_changed", %{
      mode: if(mode == "simple", do: "high_school", else: mode)
    })
  end

  defp sync_denied_action(socket, _event), do: socket
end
