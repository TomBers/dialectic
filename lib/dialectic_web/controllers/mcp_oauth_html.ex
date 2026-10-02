defmodule DialecticWeb.McpOAuthHTML do
  use DialecticWeb, :html

  def authorize(assigns) do
    ~H"""
    <section id="mcp-authorization" class="mx-auto max-w-lg p-8 space-y-6">
      <h1 class="text-2xl font-semibold">Connect {@client_name} to RationalGrid</h1>
      <p>Signed in as {@current_user.email}.</p>
      <ul class="list-disc pl-5 space-y-2">
        <li :if={"grids:create" in @scopes}>Create private grids when you ask to save your ideas.</li>
        <li :if={"grids:read" in @scopes}>
          Read grids you can access, including public and shared grids.
        </li>
        <li :if={"grids:append" in @scopes} id="mcp-append-permission">
          Add your own ideas or use AI thinking tools to read ideas and add connected nodes to grids you can access when you ask, provided editing is enabled.
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
      <section
        :if={@mcp_testing?}
        id="mcp-testing"
        class="space-y-4 rounded-xl border border-slate-200 p-4"
      >
        <h2 class="text-lg font-semibold">MCP testing and authorization</h2>
        <p>
          Start authorization in MCP Inspector so it creates its own secure sign-in session.
          This page does not grant access, and an old consent URL cannot start a new connection.
        </p>
        <.link
          id="mcp-testing-open-inspector"
          href="http://localhost:6274/"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-primary"
        >
          Open MCP Inspector <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
          <span class="sr-only">(opens in a new tab)</span>
        </.link>
        <dl id="mcp-testing-settings" class="space-y-2 text-sm">
          <div>
            <dt class="font-semibold">Transport</dt><dd>Streamable HTTP</dd>
          </div>
          <div>
            <dt class="font-semibold">Server URL</dt><dd><code>{@mcp_resource}</code></dd>
          </div>
          <div>
            <dt class="font-semibold">OAuth Client ID</dt><dd><code>rationalgrid-chatgpt</code></dd>
          </div>
          <div>
            <dt class="font-semibold">Client Secret</dt><dd>Leave blank</dd>
          </div>
          <div>
            <dt class="font-semibold">Scopes</dt><dd><code>{@mcp_scopes}</code></dd>
          </div>
          <div>
            <dt class="font-semibold">Request refresh token</dt><dd>Turn off</dd>
          </div>
        </dl>
        <p class="text-sm">
          In Inspector, enter the OAuth details under Server Settings → OAuth Settings.
          Connect, run <code>read_grid</code>, and follow Inspector's authorization prompt.
          Approve only the fresh RationalGrid consent page it opens.
        </p>
      </section>
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
