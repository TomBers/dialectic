defmodule DialecticWeb.McpOAuthHTML do
  use DialecticWeb, :html

  def authorize(assigns) do
    ~H"""
    <div class="mcp-page">
      <section id="mcp-authorization" class="mx-auto max-w-2xl px-5 py-12 sm:px-8 sm:py-16">
        <header class="mb-8 space-y-4">
          <p class="mcp-eyebrow">Account access</p>
          <h1 class="mcp-title">Connect {@client_name} to RationalGrid</h1>
          <p class="text-base leading-7 text-slate-600">Choose the access you give this app.</p>
        </header>
        <div class="mcp-panel">
          <p class="flex items-start gap-3 border-b border-stone-200 pb-5 text-sm leading-6 text-slate-600">
            <.icon name="hero-user-circle" class="mt-0.5 h-5 w-5 shrink-0 text-teal-800" />
            <span class="min-w-0">Signed in as <strong class="break-all font-semibold text-slate-950">{@current_user.email}</strong>.</span>
          </p>
          <ul class="divide-y divide-stone-200">
            <li :if={"grids:create" in @scopes} class="flex gap-4 py-5">
              <span class="mcp-icon-tile"><.icon name="hero-plus" class="h-5 w-5" /></span>
              <div class="min-w-0">
                <h2 class="font-semibold">Create private grids</h2>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Create private grids when you ask, including an automatic exploration with an opening answer, two branches and a synthesis.
                </p>
              </div>
            </li>
            <li :if={"grids:read" in @scopes} class="flex gap-4 py-5">
              <span class="mcp-icon-tile"><.icon name="hero-book-open" class="h-5 w-5" /></span>
              <div class="min-w-0">
                <h2 class="font-semibold">Read accessible grids</h2>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Read grids you can access, including public and shared grids.
                </p>
              </div>
            </li>
            <li :if={"grids:append" in @scopes} id="mcp-append-permission" class="flex gap-4 py-5">
              <span class="mcp-icon-tile"><.icon name="hero-sparkles" class="h-5 w-5" /></span>
              <div class="min-w-0">
                <h2 class="font-semibold">Develop connected ideas</h2>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Add your own ideas, ask about selected passages, generate learning plans or use AI thinking tools to develop grids you can access when you ask, provided editing is enabled. New nodes keep the grid's visibility: additions to public grids are public.
                </p>
              </div>
            </li>
          </ul>
          <div class="mt-1 flex gap-3 border border-teal-100 bg-teal-50/70 p-4 text-sm leading-6 text-teal-950">
            <.icon name="hero-shield-check" class="mt-0.5 h-5 w-5 shrink-0 text-teal-800" />
            <p>
              This connection cannot overwrite existing nodes, delete grids, or change their visibility. The app can renew access for up to 30 days. You can disconnect it at any time.
            </p>
          </div>
          <.form for={@form} id="mcp-consent-form" action={~p"/oauth/authorize"}>
            <input type="hidden" name={@form[:consent].name} value={@form[:consent].value} />
            <div class="mt-6 grid gap-3 sm:grid-cols-2">
              <button
                id="mcp-allow"
                type="submit"
                name="decision"
                value="allow"
                class="mcp-primary-button"
              >Connect <.icon name="hero-arrow-right" class="h-4 w-4" /></button>
              <button
                id="mcp-deny"
                type="submit"
                name="decision"
                value="deny"
                class="mcp-secondary-button"
              >Cancel</button>
            </div>
          </.form>
        </div>
        <.link href={~p"/users/connections"} class="mcp-text-link mt-4"><.icon
          name="hero-arrow-left"
          class="h-4 w-4"
        /> Manage connections</.link>
      </section>
    </div>
    """
  end

  def connections(assigns) do
    ~H"""
    <div class="mcp-page">
      <section id="mcp-connections" class="mcp-shell py-10 sm:py-14">
        <header class="mb-8 border-b border-stone-300 pb-7">
          <.link href={~p"/users/settings"} class="mcp-text-link mb-5"><.icon
            name="hero-arrow-left"
            class="h-4 w-4"
          /> Back to settings</.link>
          <p class="mcp-eyebrow">Your account</p>
          <h1 class="mcp-title mt-4">Your connected apps</h1>
          <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600">
            Bring your AI assistant into your workshop. Manage the apps you have connected to RationalGrid.
          </p>
        </header>

        <div
          id="mcp-account-notice"
          class="mb-8 flex items-start gap-3 border-l-2 border-teal-700 bg-white px-5 py-4 text-sm leading-6 text-slate-600"
        >
          <.icon name="hero-lock-closed" class="mt-0.5 h-5 w-5 shrink-0 text-teal-800" />
          <p class="min-w-0">
            Connections for
            <strong class="break-all font-semibold text-slate-950">{@current_user.email}</strong>
            only. Disconnecting an app here removes its access to your account. It does not affect anyone else's connections or delete your grids.
          </p>
        </div>

        <section
          id="mcp-connect"
          class="mcp-panel grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,0.85fr)] lg:gap-12"
        >
          <div>
            <span class="mcp-icon-tile mb-4"><.icon name="hero-sparkles" class="h-5 w-5" /></span>
            <h2 class="mcp-section-title">Explore a question from your AI assistant</h2>
            <p class="mt-3 text-sm leading-7 text-slate-600">
              Then ask it to explore a question with RationalGrid. It can read the answers, focus on a passage, suggest a learning plan and develop useful branches. New grids start private, and you can return to any idea to continue.
            </p>
            <.link id="mcp-usage-guide" href={~p"/features/ai-assistants"} class="mcp-text-link mt-3">Setup guide and example prompts
            <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
          </div>
          <div class="min-w-0 border-t border-stone-200 pt-5 lg:border-l lg:border-t-0 lg:pl-7 lg:pt-0">
            <p class="mb-4 text-sm leading-7 text-slate-600">
              Add this URL as a remote MCP server in an assistant that supports OAuth connections. Sign in with your RationalGrid account and approve the connection.
            </p>
            <.input
              id="mcp-server-url"
              type="text"
              name="mcp_server_url"
              label="MCP server URL"
              value={@mcp_resource}
              class="mcp-server-input"
              readonly
            />
          </div>
        </section>

        <section class="mt-10" aria-labelledby="mcp-active-connections">
          <h2 id="mcp-active-connections" class="mcp-section-title border-b border-stone-300 pb-5">
            Apps with access to your account
          </h2>
          <div
            :if={@connections == []}
            id="mcp-no-connections"
            class="mt-5 flex items-start gap-4 border border-dashed border-stone-400 px-5 py-7 sm:px-7"
          >
            <span class="mcp-icon-tile bg-white"><.icon name="hero-link" class="h-5 w-5" /></span>
            <p class="py-2 text-sm leading-6 text-slate-600">You have no active connections.</p>
          </div>
          <div class="mt-5 space-y-3">
            <div
              :for={connection <- @connections}
              id={"connection-#{connection.id}"}
              class="mcp-panel flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between"
            >
              <div class="flex min-w-0 gap-4">
                <span class="mcp-icon-tile"><.icon name="hero-link" class="h-5 w-5" /></span>
                <div class="min-w-0">
                  <p class="break-words text-base font-semibold">{connection.name}</p>
                  <p class="mt-1 text-xs leading-6 text-slate-500">
                    Connected {connection.connected_at} · Connection #{connection.id}
                  </p>
                  <p class="mt-3 text-xs font-semibold text-slate-600">Permissions</p>
                  <ul class="mt-2 flex flex-wrap gap-2" aria-label="Connection permissions">
                    <li
                      :for={scope <- connection.scopes}
                      class="rounded border border-stone-200 bg-stone-50 px-2 py-1 font-mono text-xs text-slate-600"
                    >
                      {scope}
                    </li>
                  </ul>
                </div>
              </div>
              <.link
                id={"disconnect-connection-#{connection.id}"}
                href={~p"/users/connections/#{connection.id}"}
                method="delete"
                aria-label={"Disconnect #{connection.name}, connection #{connection.id}, from your account"}
                class="mcp-disconnect-button"
              ><.icon name="hero-x-mark" class="h-4 w-4" /> Disconnect</.link>
            </div>
          </div>
        </section>

        <section :if={@mcp_testing?} id="mcp-testing" class="mcp-panel mt-10">
          <div class="flex flex-col gap-5 border-b border-stone-200 pb-5 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                Development tools
              </p>
              <h2 class="mcp-section-title mt-2">MCP testing and authorization</h2>
            </div>
            <.link
              id="mcp-testing-open-inspector"
              href="http://localhost:6274/"
              target="_blank"
              rel="noopener noreferrer"
              class="mcp-secondary-button"
            >Open MCP Inspector
            <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4" /><span class="sr-only">(opens in a new tab)</span></.link>
          </div>
          <p class="mt-5 max-w-3xl text-sm leading-7 text-slate-600">
            Start authorization in MCP Inspector so it creates its own secure sign-in session. This page does not grant access, and an old consent URL cannot start a new connection.
          </p>
          <dl
            id="mcp-testing-settings"
            class="mt-5 divide-y divide-stone-200 border-y border-stone-200 text-sm"
          >
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">Transport</dt><dd class="text-slate-600">Streamable HTTP</dd>
            </div>
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">Server URL</dt><dd class="break-all text-slate-600">
                <code>{@mcp_resource}</code>
              </dd>
            </div>
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">OAuth Client ID</dt><dd class="text-slate-600">
                <code>rationalgrid-mcp</code>
              </dd>
            </div>
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">Client Secret</dt><dd class="text-slate-600">Leave blank</dd>
            </div>
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">Scopes</dt><dd class="break-words text-slate-600">
                <code>{@mcp_scopes}</code>
              </dd>
            </div>
            <div class="grid gap-1 py-3 sm:grid-cols-[11rem_minmax(0,1fr)]">
              <dt class="font-semibold">Request refresh token</dt><dd class="text-slate-600">
                Supported
              </dd>
            </div>
          </dl>
          <p class="mt-4 text-sm leading-7 text-slate-600">
            In Inspector, enter the OAuth details under Server Settings → OAuth Settings. Connect, run <code class="rounded bg-stone-100 px-1.5 py-0.5 text-xs text-slate-800">read_grid</code>, and follow Inspector's authorization prompt. Approve only the fresh RationalGrid consent page it opens.
          </p>
        </section>
      </section>
    </div>
    """
  end

  def feature(assigns) do
    ~H"""
    <article id="ai-assistants-feature" class="mcp-page">
      <header class="border-b border-stone-300 bg-white">
        <div class="mcp-shell grid gap-10 py-12 sm:py-16 lg:grid-cols-[minmax(0,1fr)_18rem] lg:items-end">
          <div class="max-w-3xl">
            <p class="mcp-eyebrow">RationalGrid for AI assistants</p>
            <h1 class="mt-5 font-serif text-5xl font-semibold leading-[1.04] tracking-tight sm:text-6xl">
              One question. More directions to think.
            </h1>
            <p class="mt-5 max-w-2xl text-lg leading-8 text-slate-600">
              Start in your AI assistant and build an exploration you can return to. RationalGrid lets your assistant read ideas, examine a passage and grow useful branches in a private grid.
            </p>
            <.link
              id="ai-assistants-connect"
              href={
                if @current_user,
                  do: ~p"/users/connections",
                  else: ~p"/users/register?#{%{return_to: ~p"/users/connections"}}"
              }
              class="mcp-primary-button mt-7"
            >{if @current_user, do: "Connect your assistant", else: "Create a free account to connect"}
            <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
          </div>
          <aside class="border-t border-stone-400 pt-5">
            <.icon name="hero-sparkles" class="h-6 w-6 text-teal-800" />
            <p class="mt-3 font-serif text-2xl font-semibold leading-snug">
              Start in a conversation. Keep the thinking.
            </p>
            <p class="mt-3 text-sm leading-7 text-slate-600">
              Private by default. Connected ideas you can revisit, question and develop.
            </p>
          </aside>
        </div>
      </header>

      <div class="mcp-shell space-y-12 py-12 sm:space-y-16 sm:py-16">
        <section id="ai-assistants-how-it-works" aria-labelledby="ai-assistants-thinking-title">
          <div class="border-b border-stone-400 pb-5">
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
              Room to explore
            </p>
            <h2 id="ai-assistants-thinking-title" class="mcp-section-title mt-2">
              Keep the thinking connected
            </h2>
          </div>
          <ul class="mt-7 grid gap-x-8 gap-y-7 sm:grid-cols-2">
            <li class="border-t-2 border-teal-700 pt-4">
              <div class="flex items-center gap-3">
                <.icon name="hero-chat-bubble-left-right" class="h-5 w-5 shrink-0 text-teal-800" /><h3 class="font-semibold">
                  Follow the interesting idea
                </h3>
              </div>
              <p class="mt-3 text-sm leading-7 text-slate-600">
                Start with a question or return to an existing grid. Read the connected ideas and choose where to go next.
              </p>
            </li>
            <li class="border-t-2 border-sky-600 pt-4">
              <div class="flex items-center gap-3">
                <.icon name="hero-magnifying-glass" class="h-5 w-5 shrink-0 text-sky-700" /><h3 class="font-semibold">
                  Look closely at a passage
                </h3>
              </div>
              <p class="mt-3 text-sm leading-7 text-slate-600">
                Ask for an explanation, uncover an assumption or check the evidence behind a specific claim.
              </p>
            </li>
            <li class="border-t-2 border-violet-500 pt-4">
              <div class="flex items-center gap-3">
                <.icon name="hero-map" class="h-5 w-5 shrink-0 text-violet-700" /><h3 class="font-semibold">
                  Choose a learning path
                </h3>
              </div>
              <p class="mt-3 text-sm leading-7 text-slate-600">
                Generate a plan with suggested thinking tools and follow-up questions, then explore the directions that matter to you.
              </p>
            </li>
            <li class="border-t-2 border-amber-500 pt-4">
              <div class="flex items-center gap-3">
                <.icon name="hero-arrows-pointing-in" class="h-5 w-5 shrink-0 text-amber-700" /><h3 class="font-semibold">
                  Connect what you find
                </h3>
              </div>
              <p class="mt-3 text-sm leading-7 text-slate-600">
                Bring useful branches together when it helps. Keep open questions and sources alongside the conclusions.
              </p>
            </li>
          </ul>
        </section>

        <section
          id="ai-assistants-setup"
          class="grid gap-6 border-t border-stone-300 pt-10 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-12"
          aria-labelledby="ai-assistants-setup-title"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
              Getting started
            </p>
            <h2 id="ai-assistants-setup-title" class="mcp-section-title mt-2">
              Connect in three steps
            </h2>
            <p class="mt-4 text-sm leading-7 text-slate-600">
              You need a free RationalGrid account and an assistant that supports remote MCP servers with OAuth sign-in. Availability depends on your assistant and its plan.
            </p>
          </div>
          <ol class="mcp-panel divide-y divide-stone-200">
            <li class="flex gap-4 pb-5">
              <span class="mcp-step-number" aria-hidden="true">1</span>
              <p class="pt-1 text-sm leading-7 text-slate-600">
                In your assistant's connections or integrations settings, add a custom remote MCP server.
              </p>
            </li>
            <li class="flex gap-4 py-5">
              <span class="mcp-step-number" aria-hidden="true">2</span>
              <div class="min-w-0 flex-1">
                <.input
                  id="feature-mcp-server-url"
                  type="text"
                  name="mcp_server_url"
                  label="Server URL"
                  value={@mcp_resource}
                  class="mcp-server-input"
                  readonly
                />
                <p class="mt-3 text-sm leading-7 text-slate-600">
                  If asked for a transport, choose Streamable HTTP. Use OAuth sign-in; you do not need a RationalGrid API key.
                </p>
              </div>
            </li>
            <li class="flex gap-4 pt-5">
              <span class="mcp-step-number" aria-hidden="true">3</span>
              <p class="pt-1 text-sm leading-7 text-slate-600">
                Follow the sign-in prompt to RationalGrid. Check the app name and permissions, then choose Connect. Return to your assistant to start.
              </p>
            </li>
          </ol>
        </section>

        <section
          id="ai-assistants-prompts"
          class="grid gap-6 border-t border-stone-300 pt-10 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-12"
          aria-labelledby="ai-assistants-prompts-title"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
              A place to begin
            </p>
            <h2 id="ai-assistants-prompts-title" class="mcp-section-title mt-2">
              Try a question that opens up
            </h2>
          </div>
          <div class="space-y-5">
            <blockquote class="border border-stone-300 border-l-2 border-l-teal-700 bg-white p-5 text-base leading-8 text-slate-800 sm:p-7">
              Use RationalGrid to explore how cities can adapt to extreme heat. Read the opening answer, make a learning plan and follow the most useful questions. Adapt as you learn and give me the grid link.
            </blockquote>
            <blockquote class="border border-stone-300 border-l-2 border-l-sky-600 bg-white p-5 text-base leading-8 text-slate-800 sm:p-7">
              Open my grid about AI in education. Find a claim that needs more evidence, examine that passage with a thinking tool and develop a connected follow-up.
            </blockquote>
            <p class="text-sm leading-7 text-slate-600">
              Each answer or plan can take a few minutes. Your assistant checks progress and chooses the next step from the results. You can stop, change direction or return to the grid later.
            </p>
            <p class="text-sm leading-7 text-slate-600">
              For a short automatic overview, ask for the four-step guided option. For deeper exploration, ask your assistant to keep choosing useful directions from the content.
            </p>
          </div>
        </section>

        <section
          id="ai-assistants-permissions"
          class="mcp-panel border-l-4 border-l-teal-700"
          aria-labelledby="ai-assistants-permissions-title"
        >
          <div class="grid gap-5 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-12">
            <div>
              <span class="mcp-icon-tile mb-4"><.icon name="hero-shield-check" class="h-5 w-5" /></span>
              <h2 id="ai-assistants-permissions-title" class="mcp-section-title">
                You choose the access
              </h2>
            </div>
            <div class="space-y-3 text-sm leading-7 text-slate-600">
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
                  class="mcp-text-link"
                >your connected apps</.link>. That page shows only your account's connections.
              </p>
            </div>
          </div>
        </section>
      </div>
    </article>
    """
  end
end
