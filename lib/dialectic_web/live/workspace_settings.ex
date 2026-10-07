defmodule DialecticWeb.WorkspaceSettings do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  alias Dialectic.Accounts.Graph
  alias Dialectic.DbActions.Graphs
  alias Dialectic.Responses.ModeServer

  def set_prompt_mode(socket, mode) do
    normalized =
      case mode do
        "simple" -> :high_school
        "high_school" -> :high_school
        "university" -> :university
        "expert" -> :expert
        _ -> nil
      end

    cond do
      is_nil(normalized) ->
        socket

      normalized in [:university, :expert] && is_nil(socket.assigns.current_user) ->
        assign(socket, show_login_modal: true)

      true ->
        mode_str = Atom.to_string(normalized)

        with %Graph{} = graph <- Graphs.get_graph_by_title(socket.assigns.graph_id),
             {:ok, updated} <-
               graph |> Graph.changeset(%{prompt_mode: mode_str}) |> Dialectic.Repo.update() do
          :ok = ModeServer.set_mode(socket.assigns.graph_id, normalized)
          assign(socket, prompt_mode: mode_str, graph_struct: updated)
        else
          nil ->
            put_flash(socket, :error, "This grid is no longer available.")

          {:error, _} ->
            put_flash(socket, :error, "Could not update the answer level. Please try again.")
        end
    end
  end

  def set_visibility(socket, visibility) when visibility in ["public", "private"] do
    case GraphManager.set_graph_public(
           socket.assigns.graph_id,
           socket.assigns.current_user,
           visibility == "public"
         ) do
      {:ok, graph} ->
        socket
        |> assign(graph_struct: graph)
        |> push_event("analytics", %{
          event: "access_settings_changed",
          params: %{setting: "visibility", visibility: visibility}
        })

      {:error, :forbidden} ->
        put_flash(socket, :error, "Only the grid owner can change access settings.")

      {:error, _} ->
        put_flash(socket, :error, "Could not update visibility. Please try again.")
    end
  end

  def set_visibility(socket, _), do: socket

  def toggle_access(socket, setting) when setting in [:editing, :visibility] do
    result =
      if setting == :editing do
        GraphManager.toggle_graph_locked(socket.assigns.graph_id, socket.assigns.current_user)
      else
        GraphManager.toggle_graph_public(socket.assigns.graph_id, socket.assigns.current_user)
      end

    case result do
      {:ok, graph} -> assign(socket, graph_struct: graph, can_edit: !graph.is_locked)
      {:error, _} -> put_flash(socket, :error, "Only the grid owner can change access settings.")
    end
  end
end
