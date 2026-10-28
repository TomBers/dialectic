defmodule DialecticWeb.ActivityComponents do
  use DialecticWeb, :html

  alias Dialectic.Accounts.User

  attr :id, :string, required: true
  attr :actor, :any, default: nil
  attr :name, :string, default: nil

  def activity_actor(assigns) do
    actor = if match?(%User{}, assigns.actor), do: assigns.actor
    username = actor && actor.username

    assigns =
      assign(assigns,
        username: username,
        display_name:
          if(username && username != "",
            do: username,
            else: Dialectic.GridActivity.actor_name(assigns.name)
          ),
        avatar_url: actor && actor.avatar_path
      )

    ~H"""
    <%= if @username && @username != "" do %>
      <.link
        id={@id}
        navigate={~p"/u/#{@username}"}
        class="inline-flex max-w-full items-center gap-1.5 align-middle font-semibold text-teal-800 hover:underline"
      >
        <.actor_identity id={@id} avatar_url={@avatar_url} display_name={@display_name} />
      </.link>
    <% else %>
      <span
        id={@id}
        class="inline-flex max-w-full items-center gap-1.5 align-middle font-semibold text-slate-950"
      >
        <.actor_identity id={@id} avatar_url={@avatar_url} display_name={@display_name} />
      </span>
    <% end %>
    """
  end

  attr :id, :string, required: true
  attr :avatar_url, :string, default: nil
  attr :display_name, :string, required: true

  defp actor_identity(assigns) do
    ~H"""
    <img
      :if={@avatar_url && @avatar_url != ""}
      id={@id <> "-avatar"}
      src={@avatar_url}
      alt=""
      loading="lazy"
      class="h-6 w-6 shrink-0 rounded-full object-cover"
    />
    <.icon
      :if={!@avatar_url || @avatar_url == ""}
      name="hero-user-circle"
      class="h-6 w-6 shrink-0 text-slate-400"
    />
    <span class="truncate">{@display_name}</span>
    """
  end
end
