defmodule DialecticWeb.ReadingStyles do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 1]
  import Phoenix.LiveView, only: [push_event: 3]

  alias Dialectic.Accounts
  alias Dialectic.Accounts.User

  def reading_style(user) do
    preferences = Dialectic.Accounts.User.appearance_preferences(user)

    case {preferences.reading_font, preferences.reading_density} do
      {"serif", "comfortable"} -> "book"
      {"sans", "comfortable"} -> "screen"
      {"sans", "large"} -> "large_print"
      {"sans", "compact"} -> "compact"
      _ -> "custom"
    end
  end

  def apply_reading_style(params) do
    case params["reading_style"] do
      "book" ->
        {"book",
         Map.merge(params, %{"reading_font" => "serif", "reading_density" => "comfortable"})}

      "screen" ->
        {"screen",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "comfortable"})}

      "compact" ->
        {"compact",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "compact"})}

      "large_print" ->
        {"large_print",
         Map.merge(params, %{"reading_font" => "sans", "reading_density" => "large"})}

      _ ->
        {"custom", params}
    end
  end

  def save_appearance(socket, params) do
    {style, params} = apply_reading_style(params)
    params = Map.take(params, ["reading_font", "reading_density"])
    user = socket.assigns.current_user || struct(User, socket.assigns.appearance_preferences)

    result =
      if socket.assigns.current_user do
        Accounts.update_user_appearance(user, params)
      else
        user |> Accounts.change_user_appearance(params) |> Ecto.Changeset.apply_action(:update)
      end

    case result do
      {:ok, updated} ->
        socket =
          if socket.assigns.current_user, do: assign(socket, :current_user, updated), else: socket

        socket =
          assign(socket,
            reader_style: style,
            reader_appearance_form: to_form(Accounts.change_user_appearance(updated)),
            appearance_preferences: User.appearance_preferences(updated),
            reader_appearance_status:
              if(socket.assigns.current_user,
                do: "Reading style saved for all grids.",
                else: "Reading style applied for this visit."
              )
          )

        push_event(socket, "reading_style_applied", %{style: style})

      {:error, changeset} ->
        assign(socket,
          reader_style: style,
          reader_appearance_form: to_form(changeset),
          reader_appearance_status: "Could not save reading style. Please try again."
        )
    end
  end
end
