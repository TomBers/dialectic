defmodule DialecticWeb.McpOAuthHTML do
  use DialecticWeb, :html

  def authorize(assigns) do
    ~H"""
    <section id="mcp-authorization" class="mx-auto max-w-lg p-8 space-y-6">
      <h1 class="text-2xl font-semibold">Connect {@client_name} to RationalGrid</h1>
      <p>Signed in as {@current_user.email}.</p>
      <ul class="list-disc pl-5 space-y-2">
        <li :if={"grids:create" in @scopes}>Create private grids when you ask to save your ideas.</li>
        <li :if={"grids:read" in @scopes}>Read grids that you own.</li>
        <li :if={"grids:append" in @scopes} id="mcp-append-permission">
          Add your own ideas or use AI thinking tools to read ideas and add connected nodes to grids you own when you ask.
          New nodes keep the grid's visibility: additions to public grids are public.
        </li>
      </ul>
      <p>
        This connection cannot overwrite existing nodes, delete grids, or change their visibility. Access lasts one hour. You can disconnect it at any time.
      </p>
      <.form for={@form} id="mcp-consent-form" action={~p"/oauth/authorize"}>
        <input type="hidden" name={@form[:consent].name} value={@form[:consent].value} />
        <div class="flex gap-4 mt-6">
          <button id="mcp-allow" type="submit" name="decision" value="allow" class="btn btn-primary">Connect</button>
          <button id="mcp-deny" type="submit" name="decision" value="deny" class="btn">Cancel</button>
        </div>
      </.form>
      <.link href={~p"/users/connections"} class="link">Manage connections</.link>
    </section>
    """
  end

  def connections(assigns) do
    ~H"""
    <section id="mcp-connections" class="mx-auto max-w-lg p-8 space-y-6">
      <h1 class="text-2xl font-semibold">Connected apps</h1>
      <p :if={@connections == []}>No active connections.</p>
      <div
        :for={connection <- @connections}
        id={"connection-#{connection.id}"}
        class="flex justify-between items-center"
      >
        <span>{connection.name}</span>
        <.link href={~p"/users/connections/#{connection.id}"} method="delete" class="btn">Disconnect</.link>
      </div>
      <.link href={~p"/users/settings"} class="link">Back to settings</.link>
    </section>
    """
  end
end
