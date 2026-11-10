defmodule DialecticWeb.McpOAuthHTML do
  use DialecticWeb, :html

  def authorize(assigns) do
    ~H"""
    <section id="mcp-authorization" class="mx-auto max-w-lg p-8 space-y-6">
      <h1 class="text-2xl font-semibold">Connect {@client_name} to RationalGrid</h1>
      <p>Signed in as {@current_user.email}.</p>
      <ul class="list-disc pl-5 space-y-2">
        <li :if={"grids:create" in @scopes}>
          Create private grids when you ask, including an automatic exploration with an opening answer, two branches and a synthesis.
        </li>
        <li :if={"grids:read" in @scopes}>
          Read grids you can access, including public and shared grids.
        </li>
        <li :if={"grids:append" in @scopes} id="mcp-append-permission">
          Add your own ideas or use AI thinking tools to read ideas and add connected nodes to grids you can access when you ask, provided editing is enabled.
          New nodes keep the grid's visibility: additions to public grids are public.
        </li>
      </ul>
      <p>
        This connection cannot overwrite existing nodes, delete grids, or change their visibility. The app can renew access for up to 30 days. You can disconnect it at any time.
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
      <h1 class="text-2xl font-semibold">Your connected apps</h1>
      <p id="mcp-account-notice">
        Connections for <strong>{@current_user.email}</strong> only. Disconnecting an app here
        removes its access to your account. It does not affect anyone else's connections or delete your grids.
      </p>
      <section id="mcp-connect" class="space-y-4 rounded-xl border border-slate-200 p-4">
        <h2 class="text-lg font-semibold">Explore a question from your AI assistant</h2>
        <p>
          Add this URL as a remote MCP server in an assistant that supports OAuth connections.
          Sign in with your RationalGrid account and approve the connection.
        </p>
        <.input
          id="mcp-server-url"
          type="text"
          name="mcp_server_url"
          label="MCP server URL"
          value={@mcp_resource}
          readonly
        />
        <p>
          Then ask it to explore a question with RationalGrid. You will get a private grid with
          an opening answer, two useful branches and a synthesis. You can return to the grid and
          continue from any idea.
        </p>
        <.link id="mcp-usage-guide" href={~p"/features/ai-assistants"} class="link">
          Setup guide and example prompts <.icon name="hero-arrow-right" class="h-4 w-4" />
        </.link>
      </section>
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
            <dt class="font-semibold">OAuth Client ID</dt><dd><code>rationalgrid-mcp</code></dd>
          </div>
          <div>
            <dt class="font-semibold">Client Secret</dt><dd>Leave blank</dd>
          </div>
          <div>
            <dt class="font-semibold">Scopes</dt><dd><code>{@mcp_scopes}</code></dd>
          </div>
          <div>
            <dt class="font-semibold">Request refresh token</dt><dd>Supported</dd>
          </div>
        </dl>
        <p class="text-sm">
          In Inspector, enter the OAuth details under Server Settings → OAuth Settings.
          Connect, run <code>read_grid</code>, and follow Inspector's authorization prompt.
          Approve only the fresh RationalGrid consent page it opens.
        </p>
      </section>
      <h2 id="mcp-active-connections" class="text-lg font-semibold">
        Apps with access to your account
      </h2>
      <p :if={@connections == []} id="mcp-no-connections">You have no active connections.</p>
      <div
        :for={connection <- @connections}
        id={"connection-#{connection.id}"}
        class="flex justify-between items-center gap-4 border-b border-slate-200 pb-4"
      >
        <div class="space-y-1">
          <p class="font-semibold">{connection.name}</p>
          <p class="text-sm">Connected {connection.connected_at} · Connection #{connection.id}</p>
          <p class="text-sm">Permissions: {Enum.join(connection.scopes, ", ")}</p>
        </div>
        <.link
          id={"disconnect-connection-#{connection.id}"}
          href={~p"/users/connections/#{connection.id}"}
          method="delete"
          aria-label={"Disconnect #{connection.name}, connection #{connection.id}, from your account"}
          class="btn"
        >Disconnect</.link>
      </div>
      <.link href={~p"/users/settings"} class="link">Back to settings</.link>
    </section>
    """
  end

  def feature(assigns) do
    ~H"""
    <article id="ai-assistants-feature" class="mx-auto max-w-4xl space-y-12 px-6 py-12 sm:py-16">
      <header class="max-w-2xl space-y-6">
        <p class="text-sm font-semibold uppercase tracking-widest text-teal-700">
          RationalGrid for AI assistants
        </p>
        <h1 class="text-4xl font-semibold tracking-tight sm:text-5xl">
          One question. More directions to think.
        </h1>
        <p class="text-lg leading-relaxed">
          Start in your AI assistant and build an exploration you can return to. RationalGrid
          connects an opening answer, a challenge, a deeper investigation and a synthesis in a private grid.
        </p>
        <.link
          id="ai-assistants-connect"
          href={
            if @current_user,
              do: ~p"/users/connections",
              else: ~p"/users/register?#{%{return_to: ~p"/users/connections"}}"
          }
          class="btn btn-primary"
        >{if @current_user, do: "Connect your assistant", else: "Create a free account to connect"}</.link>
      </header>

      <section id="ai-assistants-how-it-works" class="space-y-4">
        <h2 class="text-2xl font-semibold">Keep the thinking connected</h2>
        <ol class="grid gap-4 sm:grid-cols-2">
          <li class="rounded-xl border border-slate-200 p-5">
            <h3 class="font-semibold">1. Get an opening answer</h3><p>
              Give your assistant a question worth exploring.
            </p>
          </li>
          <li class="rounded-xl border border-slate-200 p-5">
            <h3 class="font-semibold">2. Test the idea</h3><p>
              Examine an assumption or consider a counterargument.
            </p>
          </li>
          <li class="rounded-xl border border-slate-200 p-5">
            <h3 class="font-semibold">3. Go deeper</h3><p>
              Follow a useful branch beyond the first response.
            </p>
          </li>
          <li class="rounded-xl border border-slate-200 p-5">
            <h3 class="font-semibold">4. Bring it together</h3><p>
              Read a synthesis, then open the grid to check claims, add your ideas and keep exploring.
            </p>
          </li>
        </ol>
      </section>

      <section id="ai-assistants-setup" class="space-y-5">
        <h2 class="text-2xl font-semibold">Connect in three steps</h2>
        <p>
          You need a free RationalGrid account and an assistant that supports remote MCP servers with OAuth sign-in. Availability depends on your assistant and its plan.
        </p>
        <ol class="list-decimal space-y-4 pl-6">
          <li>
            In your assistant's connections or integrations settings, add a custom remote MCP server.
          </li>
          <li>
            <.input
              id="feature-mcp-server-url"
              type="text"
              name="mcp_server_url"
              label="Server URL"
              value={@mcp_resource}
              readonly
            />
            <p class="mt-2 text-sm">
              If asked for a transport, choose Streamable HTTP. Use OAuth sign-in; you do not need a RationalGrid API key.
            </p>
          </li>
          <li>
            Follow the sign-in prompt to RationalGrid. Check the app name and permissions, then choose Connect. Return to your assistant to start.
          </li>
        </ol>
      </section>

      <section id="ai-assistants-prompts" class="space-y-4">
        <h2 class="text-2xl font-semibold">Try a question that opens up</h2>
        <blockquote class="rounded-xl bg-slate-100 p-5">
          Use RationalGrid to explore: should cities prioritise cycling over car parking? Test an assumption, go deeper and give me the grid link when it is ready.
        </blockquote>
        <blockquote class="rounded-xl bg-slate-100 p-5">
          Use RationalGrid to explore how AI could change education. Start a private grid and bring together the strongest arguments and open questions.
        </blockquote>
        <p>
          Generation can take a few minutes. Your assistant can check progress and return the grid link. You can also ask it to find your existing grids, read an idea or add a connected follow-up.
        </p>
      </section>

      <section
        id="ai-assistants-permissions"
        class="space-y-4 rounded-xl border border-teal-200 bg-teal-50 p-6"
      >
        <h2 class="text-2xl font-semibold">You choose the access</h2>
        <p>
          New grids start private. You approve which permissions an app receives: creating grids, reading grids you can access, or adding connected ideas where editing is enabled. Additions to a public grid are public.
        </p>
        <p>
          A connection cannot overwrite existing ideas, delete grids or publish them. AI answers still need your judgement and source checking.
        </p>
        <p>
          You can disconnect an app at any time from <.link
            id="feature-manage-connections"
            href={~p"/users/connections"}
            class="link"
          >your connected apps</.link>. That page shows only your account's connections.
        </p>
      </section>
    </article>
    """
  end
end
