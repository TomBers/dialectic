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
                  Add your own ideas, ask about selected passages, generate
                  <.tool_link tool="learning_plan" new_tab>learning plans</.tool_link>
                  or use AI <.tool_link new_tab>thinking tools</.tool_link>
                  to develop grids you can access when you ask, provided editing is enabled. New nodes keep the grid's visibility: additions to public grids are public.
                </p>
              </div>
            </li>
            <li
              :if={"grids:visibility" in @scopes}
              id="mcp-visibility-permission"
              class="flex gap-4 py-5"
            >
              <span class="mcp-icon-tile"><.icon name="hero-globe-alt" class="h-5 w-5" /></span>
              <div class="min-w-0">
                <h2 class="font-semibold">Change visibility of your grids</h2>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Make grids you own public or private when you request publication automation.
                  Public content can be read and copied by anyone. Making it private cannot recall copies.
                </p>
              </div>
            </li>
          </ul>
          <div class="mt-1 flex gap-3 border border-teal-100 bg-teal-50/70 p-4 text-sm leading-6 text-teal-950">
            <.icon name="hero-shield-check" class="mt-0.5 h-5 w-5 shrink-0 text-teal-800" />
            <p>
              This connection cannot overwrite existing nodes or delete grids. Visibility changes require the separate permission listed above. The app can renew access for up to 30 days. You can disconnect it at any time.
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
              Then ask it to explore a question with RationalGrid. It can read the answers, focus on a passage, suggest a
              <.tool_link tool="learning_plan">learning plan</.tool_link>
              and develop useful branches. New grids start private, and you can return to any idea to continue.
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
    assigns =
      assigns
      |> Map.put(:mcp_setup_resource, feature_setup_resource(assigns.mcp_resource))
      |> Map.put(:mcp_tools, feature_mcp_tools())

    ~H"""
    <article id="ai-assistants-feature" class="mcp-page">
      <header class="border-b border-stone-300 bg-white">
        <div class="mcp-shell grid gap-10 py-12 sm:py-16 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)] lg:items-center lg:gap-14">
          <div>
            <p class="mcp-eyebrow">RationalGrid MCP · For AI assistants</p>
            <h1 class="mt-5 max-w-3xl font-serif text-5xl font-semibold leading-[1.04] tracking-tight sm:text-6xl">
              Turn a conversation into a map of ideas.
            </h1>
            <p class="mt-6 max-w-2xl text-lg leading-8 text-slate-600">
              Ask a question in your AI assistant. RationalGrid turns the exploration into connected
              ideas you can revisit, question and develop.
            </p>

            <div class="mt-7 flex flex-wrap items-center gap-x-6 gap-y-3">
              <.link id="feature-setup-link" href="#ai-assistants-setup" class="mcp-primary-button">
                Connect your assistant <.icon name="hero-arrow-right" class="h-4 w-4" />
              </.link>
              <.link
                id="feature-explore-link"
                href="#ai-assistants-prompts"
                class="mcp-text-link"
              >
                See an example
              </.link>
            </div>
            <p class="mt-5 text-xs leading-6 text-slate-600">
              New grids start private. You choose what your assistant can access.
            </p>
          </div>

          <figure id="feature-connection-diagram" class="mcp-connection-diagram">
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
              From conversation to something you keep
            </p>
            <ol class="mt-6 space-y-3" role="list">
              <li class="mcp-connection-step">
                <span class="mcp-icon-tile" aria-hidden="true"><.icon
                  name="hero-chat-bubble-left-right"
                  class="h-5 w-5"
                /></span>
                <div>
                  <p class="font-semibold">Your AI assistant</p><p class="mt-1 text-sm leading-6 text-slate-600">
                    You ask, discuss and choose a direction.
                  </p>
                </div>
              </li>
              <li class="mcp-connection-step">
                <span class="mcp-icon-tile" aria-hidden="true"><.icon
                  name="hero-arrows-right-left"
                  class="h-5 w-5"
                /></span>
                <div>
                  <p class="font-semibold">The MCP connection</p><p class="mt-1 text-sm leading-6 text-slate-600">
                    Your assistant requests a RationalGrid tool.
                  </p>
                </div>
              </li>
              <li class="mcp-connection-step">
                <span class="mcp-icon-tile" aria-hidden="true"><.icon
                  name="hero-square-3-stack-3d"
                  class="h-5 w-5"
                /></span>
                <div>
                  <p class="font-semibold">Your RationalGrid</p><p class="mt-1 text-sm leading-6 text-slate-600">
                    RationalGrid generates and saves connected ideas, then returns the result.
                  </p>
                </div>
              </li>
            </ol>
            <figcaption class="mt-5 border-t border-teal-900/20 pt-4 text-sm leading-6 text-slate-700">
              The conversation happens in your assistant. The growing map lives in RationalGrid.
            </figcaption>
          </figure>
        </div>
      </header>

      <nav class="border-b border-stone-300" aria-label="On this page">
        <ul class="mcp-shell flex flex-wrap gap-x-7 gap-y-1 py-2" role="list">
          <li>
            <.link href="#ai-assistants-capabilities" class="mcp-text-link">What you can do</.link>
          </li>
          <li><.link href="#ai-assistants-prompts" class="mcp-text-link">See an example</.link></li>
          <li><.link href="#ai-assistants-setup" class="mcp-text-link">Get connected</.link></li>
          <li>
            <.link href="#ai-assistants-details" class="mcp-text-link">Details and questions</.link>
          </li>
        </ul>
      </nav>

      <div class="mcp-shell space-y-10 py-10 sm:space-y-14 sm:py-12">
        <section id="ai-assistants-capabilities" aria-labelledby="feature-capabilities-title">
          <p class="mcp-eyebrow">Available today</p>
          <h2 id="feature-capabilities-title" class="mcp-section-title mt-3">
            Go beyond a single answer.
          </h2>
          <p class="mt-3 max-w-2xl text-base leading-7 text-slate-600">
            A grid is a map of connected ideas. Each question, answer and comment stays linked to the idea it responds to.
          </p>
          <ul id="feature-highlights" role="list" class="mt-6 grid gap-4 md:grid-cols-3">
            <li class="mcp-panel">
              <span class="mcp-icon-tile" aria-hidden="true"><.icon
                name="hero-chat-bubble-left-right"
                class="h-5 w-5"
              /></span>
              <h3 class="mt-4 text-lg font-semibold">Start with a question</h3>
              <p class="mt-2 text-sm leading-7 text-slate-600">
                Explore something new or return to a grid you already have. RationalGrid generates and saves the answers.
              </p>
            </li>
            <li class="mcp-panel">
              <span class="mcp-icon-tile" aria-hidden="true"><.icon
                name="hero-magnifying-glass"
                class="h-5 w-5"
              /></span>
              <h3 class="mt-4 text-lg font-semibold">Follow what matters</h3>
              <p class="mt-2 text-sm leading-7 text-slate-600">
                Focus on a passage. <.tool_link tool="clarify">Clarify a term</.tool_link>,
                <.tool_link tool="says_who">examine evidence</.tool_link>
                or follow a new question.
              </p>
            </li>
            <li class="mcp-panel">
              <span class="mcp-icon-tile" aria-hidden="true"><.icon
                name="hero-square-3-stack-3d"
                class="h-5 w-5"
              /></span>
              <h3 class="mt-4 text-lg font-semibold">Keep the whole picture</h3>
              <p class="mt-2 text-sm leading-7 text-slate-600">
                Add your own ideas, connect useful branches, and export or share the finished grid when you choose.
              </p>
            </li>
          </ul>
          <details id="feature-all-capabilities" class="mcp-disclosure mt-4">
            <summary class="min-h-11 cursor-pointer py-3 text-sm font-semibold text-teal-800">
              See everything your assistant can do
            </summary>
            <ol class="mt-8 grid gap-x-10 sm:grid-cols-2" role="list">
              <li id="feature-discover" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">01</span>
                <h3 class="text-lg font-semibold">Find somewhere to begin</h3>
                <p>
                  Search public grids by topic, find grids you own, or open a grid you can access. Read the full ideas and their connections, including available source links, before deciding what to explore.
                </p>
              </li>
              <li id="feature-start" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">02</span>
                <h3 class="text-lg font-semibold">Start with your own question</h3>
                <p>
                  Create a private grid with an opening answer generated by RationalGrid. Ask for an accessible, expanded or advanced explanation. Keep the grid link and come back to develop it later.
                </p>
              </li>
              <li id="feature-passages" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">03</span>
                <h3 class="text-lg font-semibold">Go straight to the interesting part</h3>
                <p>
                  Read one idea alongside the ideas it came from and led to. Select an exact passage to clarify, question or develop. The tools check that the passage still matches the source before adding a branch.
                </p>
              </li>
              <li id="feature-contribute" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">04</span>
                <h3 class="text-lg font-semibold">Add your voice to the map</h3>
                <p>
                  Save a comment in your own words, or add a follow-up question and ask RationalGrid to answer it. New ideas are linked to the point they respond to, so the context stays visible.
                </p>
              </li>
              <li id="feature-plan" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">05</span>
                <h3 class="text-lg font-semibold">Choose a useful next move</h3>
                <p>
                  Ask for a <.tool_link tool="learning_plan">learning plan</.tool_link>
                  with suggested directions and reasons, or use a
                  <.tool_link>thinking tool</.tool_link>
                  directly. Explore an assumption, a possible exception, an alternative reading or a consequence. Follow what helps your question.
                </p>
              </li>
              <li id="feature-connect-ideas" class="mcp-feature-item">
                <span class="mcp-feature-number" aria-hidden="true">06</span>
                <h3 class="text-lg font-semibold">Bring discoveries together</h3>
                <p>
                  Connect two to five ideas from the same grid in a <.tool_link tool="synthesis">synthesis</.tool_link>: a new explanation that draws on those branches. It can preserve differences and open questions. You can also finish with useful branches and no synthesis.
                </p>
              </li>
            </ol>
          </details>
        </section>

        <section
          id="ai-assistants-prompts"
          class="border-t border-stone-300 pt-8"
          aria-labelledby="ai-assistants-prompts-title"
        >
          <p class="mcp-eyebrow">See it in practice</p>
          <h2 id="ai-assistants-prompts-title" class="mcp-section-title mt-3">
            One question. Several useful directions.
          </h2>
          <div class="mt-6 grid items-start gap-6 lg:grid-cols-2 lg:gap-10">
            <div>
              <div id="feature-first-prompt" class="mcp-panel">
                <h3 class="text-xs font-semibold uppercase tracking-wider text-teal-800">
                  Try asking your connected assistant
                </h3>
                <p class="mt-4 select-all font-serif text-xl leading-8">
                  “Use RationalGrid to explore how a city can adapt to extreme heat. Read the opening answer, investigate a claim that needs evidence and follow the most useful questions. Show me what we learned and what is still uncertain.”
                </p>
              </div>
              <p class="mt-4 text-sm leading-7 text-slate-600">
                Your assistant reads each result before choosing the next step. You can follow one branch closely or explore another direction.
              </p>
              <details id="feature-more-prompts" class="mcp-disclosure mt-4">
                <summary class="min-h-11 cursor-pointer py-3 text-sm font-semibold text-teal-800">
                  More prompts: learn, revisit or prepare to share
                </summary>
                <div class="mt-2 space-y-4">
                  <figure class="mcp-panel">
                    <figcaption class="mb-4 text-xs font-semibold uppercase tracking-wider text-teal-800">
                      Learn something new
                    </figcaption>
                    <blockquote class="font-serif text-lg leading-8">
                      “Use RationalGrid to explore why a good teacher might want their students to disagree with them. Read each answer and follow the most useful direction. Show me what we learned and what is still open.”
                    </blockquote>
                  </figure>
                  <figure class="mcp-panel">
                    <figcaption class="mb-4 text-xs font-semibold uppercase tracking-wider text-teal-800">
                      Revisit an idea
                    </figcaption>
                    <blockquote class="font-serif text-lg leading-8">
                      “Find my grid about AI in education. Read it, choose a claim that needs closer examination and explore that passage. Add my follow-up question as a connected branch.”
                    </blockquote>
                  </figure>
                  <figure class="mcp-panel">
                    <figcaption class="mb-4 text-xs font-semibold uppercase tracking-wider text-teal-800">
                      Prepare to share
                    </figcaption>
                    <blockquote class="font-serif text-lg leading-8">
                      “Read the finished grid and export its saved version for my article. Keep the source links and qualifications. Once I have reviewed it, I may ask you to make the grid public.”
                    </blockquote>
                  </figure>
                </div>
              </details>
              <.link href="#ai-assistants-setup" class="mcp-text-link mt-4">Connect your assistant to try it
              <.icon name="hero-arrow-right" class="h-4 w-4" /></.link>
            </div>
            <figure id="feature-branch-diagram" class="mcp-panel self-start">
              <p class="text-xs font-semibold uppercase tracking-[0.18em] text-teal-800">
                An example question
              </p>
              <div class="mcp-branch-root mt-4">
                <p class="text-xs font-semibold uppercase tracking-wider text-teal-800">
                  Your starting point
                </p>
                <p class="mt-2 font-serif text-2xl font-semibold leading-snug">
                  How can a city adapt to extreme heat?
                </p>
              </div>
              <div class="mcp-branch-answer">
                <p class="font-semibold">RationalGrid's opening answer</p>
                <p class="mt-1 text-sm leading-6 text-slate-600">
                  Read the actual ideas and available sources.
                </p>
              </div>
              <p class="mb-3 mt-5 text-sm font-semibold">Possible directions from that answer</p>
              <ul class="mcp-branch-options" role="list">
                <li>
                  <.tool_link tool="clarify" class="mcp-branch-label">Clarify</.tool_link><p>
                    What does “adapting” mean for different neighbourhoods?
                  </p>
                </li>
                <li>
                  <.tool_link tool="says_who" class="mcp-branch-label">Examine evidence</.tool_link><p>
                    What supports a claim about cooling streets?
                  </p>
                </li>
                <li>
                  <.tool_link tool="implications" class="mcp-branch-label">Follow a consequence</.tool_link><p>
                    Who might be left out by a proposed solution?
                  </p>
                </li>
              </ul>
              <figcaption class="mt-5 border-t border-stone-200 pt-4 text-sm leading-7 text-slate-600">
                An illustration, not a generated result or a required sequence. Follow a useful
                branch, read what comes back, then choose again. Connecting branches is optional.
              </figcaption>
            </figure>
          </div>
        </section>

        <section id="ai-assistants-setup" class="border-t border-stone-300 pt-10">
          <div class="grid gap-7 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-12">
            <div>
              <p class="mcp-eyebrow">Getting started</p>
              <h2 id="ai-assistants-setup-title" class="mcp-section-title mt-3">
                Connect the assistant you already use
              </h2>
              <p class="mt-4 text-sm leading-7 text-slate-600">
                Create a free RationalGrid account, then choose your app below. You only need to follow its guide.
              </p>
              <.link
                id="ai-assistants-connect"
                href={
                  if @current_user,
                    do: ~p"/users/connections",
                    else: ~p"/users/register?#{%{return_to: ~p"/users/connections"}}"
                }
                class="mcp-secondary-button mt-4"
              >
                {if @current_user,
                  do: "Manage your connections",
                  else: "Create a free account"}
                <span aria-hidden="true"><.icon name="hero-arrow-right" class="h-4 w-4" /></span>
              </.link>
              <p class="mt-4 text-xs leading-6 text-slate-600">
                Provider menus and eligibility checked <time datetime="2026-11-16">16 November 2026</time>. Access can depend on your plan, region or workspace administrator.
              </p>
            </div>
            <div id="feature-mcp-connection-settings" class="mcp-panel">
              <h3 class="font-semibold">Use these connection details</h3>
              <.input
                id="feature-mcp-server-url"
                type="text"
                name="mcp_server_url"
                label="Server URL"
                value={@mcp_setup_resource}
                class="mcp-server-input"
                readonly
                aria-describedby="feature-connection-permissions"
              />
              <p id="feature-connection-permissions" class="mt-4 text-sm leading-7 text-slate-600">
                Sign in on RationalGrid and choose the permissions you grant. Publishing needs a separate permission. <.link
                  href="#ai-assistants-permissions"
                  class="underline underline-offset-4"
                >Read about access and privacy</.link>.
              </p>
              <details
                id="feature-connection-technical"
                class="mcp-disclosure mt-3 border-t border-stone-200"
              >
                <summary class="min-h-11 cursor-pointer py-3 text-sm font-semibold text-teal-800">
                  Connection settings and sign-in details
                </summary>
                <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-3">
                  <div>
                    <dt class="font-semibold">Name</dt><dd class="mt-1 text-slate-600">
                      RationalGrid
                    </dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Transport</dt><dd class="mt-1 text-slate-600">
                      Streamable HTTP
                    </dd>
                  </div>
                  <div>
                    <dt class="font-semibold">Authentication</dt><dd class="mt-1 text-slate-600">
                      OAuth sign-in
                    </dd>
                  </div>
                </dl>
                <p id="feature-mcp-transport" class="mt-4 text-sm leading-7 text-slate-600">
                  RationalGrid supports automatic OAuth client registration (DCR). You do not need an API key or a client secret. Sign in on RationalGrid's own consent page and approve the permissions you want to grant.
                </p>
                <p
                  :if={@mcp_setup_resource != @mcp_resource}
                  id="feature-mcp-local-notice"
                  class="mt-3 text-sm leading-7 text-slate-600"
                >
                  These guides use the hosted service. A localhost address on a development machine cannot be reached by cloud assistants.
                </p>
              </details>
            </div>
          </div>

          <div id="feature-assistant-guides" class="mt-8 grid gap-8 lg:grid-cols-2">
            <section id="feature-chat-assistants" aria-labelledby="feature-chat-assistants-title">
              <h3 id="feature-chat-assistants-title" class="font-serif text-xl font-semibold">
                Chat assistants
              </h3>
              <div class="mt-4 divide-y divide-stone-300 border-y border-stone-300">
                <details
                  id="feature-setup-chatgpt"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>ChatGPT · web</summary>
                  <div class="mcp-guide-body">
                    <p>
                      Use ChatGPT in your browser. Custom-server access is subject to your workspace's permissions and security settings.
                    </p>
                    <ol>
                      <li>
                        Open <.link href="https://chatgpt.com/plugins" class="mcp-text-link">ChatGPT Plugins</.link>. Use the plus control and choose <strong>Add custom MCP server</strong>.
                      </li>
                      <li>
                        Name it <strong>RationalGrid</strong>. In the connection settings, paste
                        <code>{@mcp_setup_resource}</code>
                        as the server URL.
                      </li>
                      <li>
                        Choose <strong>OAuth</strong>. If registration options appear, use dynamic client registration (DCR); leave manually supplied client credentials empty.
                      </li>
                      <li>
                        Read the warning, then choose <strong>Create as a plugin</strong>. Install the resulting plugin in your personal account or permitted workspace.
                      </li>
                      <li>
                        Complete the RationalGrid sign-in when prompted. In a new conversation, type <code>@</code>, select RationalGrid, and try the connection check below.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-chatgpt-source"
                        href="https://developers.openai.com/api/docs/guides/custom-mcp-server"
                        class="mcp-text-link"
                      >Official OpenAI setup guide</.link>
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-claude"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>Claude · web and Desktop</summary>
                  <div class="mcp-guide-body">
                    <p>
                      Claude's remote connectors are available across its plans; Free accounts are limited to one custom connector. A Team or Enterprise administrator may need to add it for the organization first.
                    </p>
                    <ol>
                      <li>
                        Open <strong>Customize → Connectors</strong>. Use <strong>+ Add → Add custom connector</strong>. Organization administrators use their organization's connector settings.
                      </li>
                      <li>
                        Enter <strong>RationalGrid</strong>
                        and the remote server URL <code>{@mcp_setup_resource}</code>, then continue.
                      </li>
                      <li>
                        Keep OAuth authentication, select <strong>Sign in now</strong>, and choose
                        <strong>Register automatically</strong>
                        for the OAuth client. RationalGrid uses this option rather than Claude's published client identity.
                      </li>
                      <li>
                        Finish adding the connector and sign in on RationalGrid. There are no API-key headers or client secrets to enter.
                      </li>
                      <li>
                        In a conversation, open the <strong>+</strong>
                        menu, choose <strong>Connectors</strong>, and enable RationalGrid. Try the connection check below.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-claude-source"
                        href="https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp"
                        class="mcp-text-link"
                      >Official Claude connector guide</.link>
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-gemini"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>Gemini · eligible personal accounts</summary>
                  <div class="mcp-guide-body">
                    <p id="feature-gemini-eligibility">
                      Google currently limits custom apps to people aged 18 or over in the US using a personal Google Account, in English, with Keep Activity on. Work and school accounts are excluded. If you are outside this rollout, choose another assistant listed here.
                    </p>
                    <ol>
                      <li>
                        On your computer, open <.link
                          href="https://gemini.google.com/"
                          class="mcp-text-link"
                        >Gemini</.link>. Go to <strong>Settings → Connected Apps</strong>. Some accounts put this inside <strong>Personal Intelligence</strong>.
                      </li>
                      <li>
                        Find <strong>Custom apps</strong>, then use the field for a new app link or the add control if you already have a custom app.
                      </li>
                      <li>
                        Paste <code>{@mcp_setup_resource}</code>
                        and choose <strong>Next</strong>. RationalGrid supports automatic registration, so you do not need to supply OAuth client credentials in advanced settings.
                      </li>
                      <li>
                        Follow the sign-in flow to RationalGrid and approve your chosen permissions.
                      </li>
                      <li>
                        In a chat, type <code>@</code>
                        and select the connected RationalGrid app. Try the check below. Once added on the web, the app can also be used in Gemini's mobile app.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-gemini-source"
                        href="https://support.google.com/gemini/answer/17209137?hl=en"
                        class="mcp-text-link"
                      >Official Gemini custom-app guide</.link>
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-perplexity"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>Perplexity · custom remote connector</summary>
                  <div class="mcp-guide-body">
                    <p>
                      Custom remote connectors are offered on Pro, Max and Enterprise plans. Organization policies can restrict who adds them.
                    </p>
                    <ol>
                      <li>
                        Open <strong>Plugins</strong>
                        in the sidebar. If that menu has not reached your account yet, use <strong>Customize → Connectors</strong>.
                      </li>
                      <li>
                        Use <strong>Add custom → Add MCP connector</strong>
                        and select <strong>Remote</strong>.
                      </li>
                      <li>
                        Enter the name <strong>RationalGrid</strong>
                        and server URL <code>{@mcp_setup_resource}</code>.
                      </li>
                      <li>
                        In advanced options, choose <strong>OAuth</strong>
                        authentication, <strong>Streamable HTTP</strong>
                        transport and <strong>Public</strong>
                        network access. Automatic client registration supplies the client identity.
                      </li>
                      <li>
                        Read and accept the acknowledgement, then add the connector. Open its new card to start the RationalGrid sign-in and enable it.
                      </li>
                      <li>
                        Ask Perplexity to use RationalGrid explicitly, starting with the connection check below.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-perplexity-source"
                        href="https://www.perplexity.ai/help-center/en/articles/13915507-adding-custom-remote-connectors"
                        class="mcp-text-link"
                      >Official Perplexity connector guide</.link>
                      ·
                      <.link
                        href="https://www.perplexity.ai/changelog/what-we-shipped---march-13-2026"
                        class="mcp-text-link"
                      >Plan availability</.link>
                    </p>
                  </div>
                </details>
              </div>
            </section>

            <section id="feature-coding-assistants" aria-labelledby="feature-coding-assistants-title">
              <h3 id="feature-coding-assistants-title" class="font-serif text-xl font-semibold">
                Coding assistants and editors
              </h3>

              <div class="mt-4 divide-y divide-stone-300 border-y border-stone-300">
                <details
                  id="feature-setup-copilot"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>GitHub Copilot · VS Code</summary>
                  <div class="mcp-guide-body">
                    <p>
                      Use a current VS Code installation with GitHub Copilot enabled. This is the editor integration; Microsoft Copilot chat and Copilot Studio are separate products.
                    </p>
                    <ol>
                      <li>
                        Open the Command Palette with <strong>Ctrl+Shift+P</strong>
                        on Windows/Linux or <strong>Cmd+Shift+P</strong>
                        on Mac. Run <strong>MCP: Add Server</strong>.
                      </li>
                      <li>
                        Choose <strong>HTTP</strong> and paste <code>{@mcp_setup_resource}</code>.
                      </li>
                      <li>
                        Set the server ID to <strong>rationalgrid</strong>. For a personal connection, choose
                        <strong>Global → Copilot Global</strong>
                        where offered.
                      </li>
                      <li>
                        Review the server trust request and complete the offered OAuth browser sign-in to RationalGrid.
                      </li>
                      <li>
                        Open Copilot chat, make the server's tools available, and run the connection check below. Expand the tool result to confirm RationalGrid was called.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-copilot-source"
                        href="https://code.visualstudio.com/docs/agent-customization/mcp-servers"
                        class="mcp-text-link"
                      >Official VS Code MCP guide</.link>
                    </p>
                    <p>
                      For a workplace agent in Microsoft Copilot, an administrator can consult the separate <.link
                        href="https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/tools-add-mcp-server"
                        class="mcp-text-link"
                      >Copilot Studio MCP setup</.link>. Its agent and authentication configuration differs from this editor guide.
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-cursor"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>Cursor · personal MCP configuration</summary>
                  <div class="mcp-guide-body">
                    <ol>
                      <li>
                        Open or create <code>~/.cursor/mcp.json</code>
                        in your home folder. This makes the connection available across your projects.
                      </li>
                      <li>
                        Add the following entry. If the file already contains servers, merge the
                        <code>rationalgrid</code>
                        entry into its existing <code>mcpServers</code>
                        object.
                      </li>
                    </ol>
                    <pre
                      class="mcp-setup-code"
                      role="region"
                      aria-label="Cursor MCP configuration"
                      tabindex="0"
                    ><code>{Jason.encode!(%{"mcpServers" => %{"rationalgrid" => %{"url" => @mcp_setup_resource}}}, pretty: true)}</code></pre>
                    <ol start="3">
                      <li>
                        Open Cursor's <strong>Customize</strong>
                        page and find the RationalGrid MCP server. Enable it and complete its OAuth sign-in when prompted.
                      </li>
                      <li>
                        In an agent conversation, ask it to use RationalGrid for the connection check below.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-cursor-source"
                        href="https://cursor.com/docs/mcp"
                        class="mcp-text-link"
                      >Official Cursor MCP guide</.link>
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-codex"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>OpenAI Codex · command line and IDE extension</summary>
                  <div class="mcp-guide-body">
                    <ol>
                      <li>
                        With a current Codex CLI installed, run these commands in a terminal. They register the server, start OAuth using dynamic client registration, then list your connections.
                      </li>
                    </ol>
                    <pre
                      class="mcp-setup-code"
                      role="region"
                      aria-label="Codex MCP setup commands"
                      tabindex="0"
                    ><code>{"codex mcp add rationalgrid --url #{@mcp_setup_resource}\ncodex mcp login rationalgrid --oauth-client-registration dcr --scopes grids:create,grids:read,grids:append\ncodex mcp list"}</code></pre>
                    <ol start="2">
                      <li>
                        Complete the browser sign-in and RationalGrid consent. The listed scopes request creating, reading and adding ideas; changing visibility requires a separate grant.
                      </li>
                      <li>
                        In Codex, use <code>/mcp</code>
                        to check the connection, then try the prompt below. If your IDE extension was already open, reload its MCP configuration or restart the extension.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-codex-source"
                        href="https://learn.chatgpt.com/docs/extend/mcp?surface=cli"
                        class="mcp-text-link"
                      >Official OpenAI MCP guide</.link>
                    </p>
                  </div>
                </details>
                <details
                  id="feature-setup-claude-code"
                  name="mcp-assistant-setup"
                  class="mcp-disclosure mcp-assistant-guide"
                >
                  <summary>Claude Code · command line</summary>
                  <div class="mcp-guide-body">
                    <ol>
                      <li>
                        With Claude Code installed, run this command to add RationalGrid for your user account across projects.
                      </li>
                    </ol>
                    <pre
                      class="mcp-setup-code"
                      role="region"
                      aria-label="Claude Code MCP setup command"
                      tabindex="0"
                    ><code>{"claude mcp add --transport http --scope user rationalgrid #{@mcp_setup_resource}"}</code></pre>
                    <ol start="2">
                      <li>
                        Start an interactive Claude Code session and enter <code>/mcp</code>. Select RationalGrid and follow the authentication prompt.
                      </li>
                      <li>
                        Sign in on RationalGrid, review the permissions, then return to Claude Code and try the connection check below.
                      </li>
                    </ol>
                    <p>
                      <.link
                        id="feature-setup-claude-code-source"
                        href="https://code.claude.com/docs/en/mcp"
                        class="mcp-text-link"
                      >Official Claude Code MCP guide</.link>
                    </p>
                  </div>
                </details>
              </div>
            </section>
          </div>

          <details id="feature-setup-check" class="mcp-panel mt-8 border-l-4 border-l-teal-700">
            <summary class="min-h-11 cursor-pointer py-2 font-semibold">
              Check that your connection works
            </summary>
            <p class="mt-3 text-sm leading-7 text-slate-600">After connecting, ask your assistant:</p>
            <p class="mt-3 font-serif text-lg leading-8">
              “Use RationalGrid to list my grids with their titles and links. Do not create or change any grids.”
            </p>
            <p class="mt-3 text-sm leading-7 text-slate-600">
              Look for an actual RationalGrid tool call and its result. An empty list is fine if you have not created any grids yet. Once that works, <.link
                href="#ai-assistants-prompts"
                class="underline underline-offset-4"
              >try an exploration prompt</.link>.
            </p>
          </details>
          <details
            id="feature-setup-troubleshooting"
            class="mcp-disclosure mcp-assistant-guide mt-5 border-y border-stone-300"
          >
            <summary>If a setup option is missing or sign-in fails</summary>
            <div class="mcp-guide-body">
              <ul>
                <li>
                  <strong>No custom-server option:</strong>
                  check the eligibility notes for your assistant and ask your workspace administrator whether custom connections are enabled.
                </li>
                <li>
                  <strong>Asked for a client secret:</strong>
                  use OAuth with automatic registration where available. RationalGrid registers public OAuth clients and does not issue client secrets. A client that requires a secret needs additional integration work.
                </li>
                <li>
                  <strong>Connection added but no tool calls:</strong>
                  enable RationalGrid in the conversation or agent, name it in your prompt and inspect the tool result.
                </li>
                <li>
                  <strong>Publication permission denied:</strong>
                  reconnect with the separate visibility permission if you want the assistant to publish. Creating or reading grids alone does not authorize publication.
                </li>
              </ul>
            </div>
          </details>
        </section>

        <section
          id="ai-assistants-thinking-tools"
          class="mcp-connection-diagram"
          aria-labelledby="feature-thinking-tools-title"
        >
          <h2 id="feature-thinking-tools-title" class="font-serif text-2xl font-semibold">
            Find the right question to ask next.
          </h2>
          <p class="mt-3 max-w-2xl text-sm leading-7 text-slate-700">
            Want to understand an idea more deeply, challenge it or see where it leads? The thinking-tools guide helps you choose, with practical examples.
          </p>
          <ul id="mcp-thinking-goals" role="list" class="mt-4 flex flex-wrap gap-2">
            <li :for={group <- ThinkingTools.groups()}>
              <.tool_link
                id={"mcp-thinking-goals-#{group.id}"}
                tool={group.id}
                class="inline-flex min-h-11 items-center border border-teal-900/20 bg-white px-4 py-2 text-sm font-semibold text-teal-900"
              >{group.short}</.tool_link>
            </li>
          </ul>
          <.tool_link id="feature-thinking-tools-guide" class="mcp-text-link mt-3">Explore all thinking tools, with examples</.tool_link>
        </section>

        <section id="ai-assistants-details" aria-labelledby="feature-details-title">
          <p class="mcp-eyebrow">When you want to know more</p>
          <h2 id="feature-details-title" class="mcp-section-title mt-3">A closer look</h2>
          <p class="mt-3 text-sm leading-7 text-slate-600">
            Open the part you need. The full descriptions and technical reference are here.
          </p>
          <div class="mt-5 border-b border-stone-300">
            <details
              id="feature-mcp-explained"
              name="mcp-feature-reference"
              class="mcp-disclosure border-t border-stone-300"
            >
              <summary class="mcp-reference-summary">What is MCP?</summary>
              <p class="max-w-3xl pb-6 text-sm leading-7 text-slate-600">
                MCP stands for Model Context Protocol: a way for an AI assistant to work with other apps. RationalGrid's MCP server gives a compatible assistant tools to read, create and develop your grids, with the access you choose. You ask in ordinary language; your assistant makes the tool requests.
              </p>
            </details>
            <details
              id="ai-assistants-how-it-works"
              name="mcp-feature-reference"
              class="mcp-disclosure border-t border-stone-300"
            >
              <summary id="ai-assistants-thinking-title" class="mcp-reference-summary">
                How does an exploration continue?
              </summary>
              <div class="max-w-3xl pb-6">
                <h3 class="font-semibold">Read an answer. Follow what matters.</h3>
                <p class="mt-4 text-sm leading-7 text-slate-600">
                  With adaptive exploration, RationalGrid creates the opening answer. Your assistant
                  reads it, chooses a useful next tool, waits for the result and reads again. A plan
                  can help, but it is a set of suggestions rather than a checklist.
                </p>
                <p class="mt-4 text-sm leading-7 text-slate-600">
                  You might investigate one claim closely, follow several questions or connect
                  two findings. The aim is a clearer understanding, with its limits, rather than
                  a particular number of branches.
                </p>
                <div
                  id="feature-exploration-modes"
                  class="mt-6 space-y-5 border-l-2 border-teal-700 pl-5"
                >
                  <div>
                    <h3 class="font-semibold">Adaptive: choose as you learn</h3>
                    <p class="mt-1 text-sm leading-7 text-slate-600">
                      The default. Completion means the current step is saved; your connected assistant still needs to choose and request the next step.
                    </p>
                  </div>
                  <div>
                    <h3 class="font-semibold">Guided: a fixed four-step overview</h3>
                    <p class="mt-1 text-sm leading-7 text-slate-600">
                      Ask for this explicitly to get an opening answer, a testing branch, a deeper branch and a synthesis. This bounded sequence continues on the server.
                    </p>
                  </div>
                </div>
              </div>
            </details>
            <details
              id="ai-assistants-sharing"
              name="mcp-feature-reference"
              class="mcp-disclosure border-t border-stone-300"
            >
              <summary class="mcp-reference-summary">How can I export or share my work?</summary>
              <div class="grid gap-6 pb-6 lg:grid-cols-2 lg:gap-10">
                <div>
                  <p class="mcp-eyebrow">From exploring to explaining</p>
                  <h3 class="mcp-section-title mt-3">Take the research with you</h3>
                  <p class="mt-4 text-sm leading-7 text-slate-600">
                    Export a saved version of a grid for writing, teaching or another workflow. The export
                    keeps all kinds of ideas, their connections and available source references, including
                    branches with more than one parent. It reads existing work without generating new answers.
                  </p>
                  <p class="mt-4 text-sm leading-7 text-slate-600">
                    Your assistant can read private material with permission. The export currently supplies
                    the graph; a prepared editorial brief, verified claims and ready-made social posts are
                    not included. Use the material selectively and check the sources yourself.
                  </p>
                </div>
                <div id="feature-publication" class="mcp-panel border-t-2 border-t-teal-700">
                  <span class="mcp-icon-tile" aria-hidden="true"><.icon
                    name="hero-globe-alt"
                    class="h-5 w-5"
                  /></span>
                  <h3 class="mt-4 font-serif text-2xl font-semibold">
                    Share a finished grid, on your terms
                  </h3>
                  <p class="mt-4 text-sm leading-7 text-slate-600">
                    Ask your assistant to make a grid you own public, or make it private again. This
                    requires a separate visibility permission; permission to create a grid does not
                    grant permission to publish it.
                  </p>
                  <p class="mt-3 text-sm leading-7 text-slate-600">
                    Publication checks the saved version you reviewed and rejects a request while
                    generation or unsaved edits are in the way. It reports whether anonymous access is
                    still being checked, verified or failed, so an accepted request is not mistaken for
                    a verified public link.
                  </p>
                  <p class="mt-3 text-sm leading-7 text-slate-600">
                    Making a grid private blocks public access. It cannot recall copies people have
                    already downloaded or material shared elsewhere.
                  </p>
                </div>
              </div>
            </details>
            <details
              id="ai-assistants-permissions"
              name="mcp-feature-reference"
              class="mcp-disclosure border-t border-stone-300"
            >
              <summary id="ai-assistants-permissions-title" class="mcp-reference-summary">
                What can my assistant access, and what are the limits?
              </summary>
              <div class="max-w-3xl space-y-4 pb-6 text-sm leading-7 text-slate-600">
                <p>
                  Choose whether a connected app can create grids, read grids you can access, add ideas where editing is enabled, or change visibility on grids you own. New grids start private. Additions to an already public grid are public.
                </p>
                <p>
                  Accepted generation steps run in the background. Your assistant can check progress and read the saved result. Requests have saved references, so a lost reply can be checked without starting a duplicate grid. Reading a grid or checking progress does not generate more content.
                </p>
                <p>
                  You can revisit saved work later. Your assistant needs to stay involved to choose and request new adaptive steps. Automatic publication at the end, batch exploration, and run-level resume or cancel controls are not available through this connection.
                </p>
                <p>
                  The connection adds new ideas; it cannot overwrite existing ideas or delete grids. AI-generated answers and source links still need your judgement. RationalGrid does not schedule or deliver social posts.
                </p>
                <p>
                  You can disconnect an app at any time from <.link
                    id="feature-manage-connections"
                    href={~p"/users/connections"}
                    class="mcp-text-link"
                  >your connected apps</.link>.
                </p>
              </div>
            </details>
            <section id="ai-assistants-tool-directory" class="border-t border-stone-300">
              <details id="feature-tool-directory" name="mcp-feature-reference" class="mcp-disclosure">
                <summary class="mcp-reference-summary">
                  All 14 MCP tools: the full reference
                </summary>
                <p class="mb-6 mt-2 max-w-3xl text-sm leading-7 text-slate-600">
                  These are the tools a compatible assistant can discover. You can ask in ordinary language; your assistant handles the tool calls and checks the server's current limits.
                </p>
                <dl class="grid gap-x-10 sm:grid-cols-2">
                  <div
                    :for={tool <- @mcp_tools}
                    id={"feature-tool-#{tool.name}"}
                    class="min-w-0 border-t border-stone-300 py-5"
                  >
                    <dt>
                      <%= if tool.name in ["apply_grid_action", "create_learning_plan", "get_exploration_tools"] do %>
                        <.tool_link
                          tool={if(tool.name == "create_learning_plan", do: "learning_plan")}
                          class="block font-semibold"
                        >{tool.label}</.tool_link>
                      <% else %>
                        <span class="block font-semibold">{tool.label}</span>
                      <% end %>
                      <code class="mt-1 block break-words text-xs text-teal-800">{tool.name}</code>
                    </dt>
                    <dd class="mt-2 text-sm leading-7 text-slate-600">{tool.explanation}</dd>
                  </div>
                </dl>
              </details>
            </section>
          </div>
        </section>
      </div>
    </article>
    """
  end

  defp feature_setup_resource(resource) do
    if URI.parse(resource).scheme == "https", do: resource, else: "https://rationalgrid.ai/mcp"
  end

  defp feature_mcp_tools do
    [
      %{
        name: "search_public_grids",
        label: "Search public explorations",
        explanation:
          "Find published public grids by topic, title or idea text, with matching passages and grid links."
      },
      %{
        name: "list_my_grids",
        label: "Find your own grids",
        explanation:
          "List grids you own, including private ones, and filter by title. Grids merely shared with you are not included in this list."
      },
      %{
        name: "read_grid",
        label: "Read a connected map",
        explanation:
          "Read saved ideas and links across a public, owned or shared grid you can access. Larger grids can be read in pages from the same saved version."
      },
      %{
        name: "read_grid_node",
        label: "Read one idea in context",
        explanation:
          "Read an idea's full text, available sources and learning plan, with previews of its parent and child ideas. This also provides the reference used to target an exact passage."
      },
      %{
        name: "explore_question",
        label: "Begin an exploration",
        explanation:
          "Start a private opening question and answer. Adaptive mode leaves each next decision to your assistant; explicitly choosing guided mode starts the fixed four-step overview."
      },
      %{
        name: "create_grid",
        label: "Start with one opening answer",
        explanation:
          "Create a private question-and-answer grid without the guided coordinator. RationalGrid generates the answer; this does not import an answer written in your chat."
      },
      %{
        name: "add_grid_idea",
        label: "Add a comment or follow-up question",
        explanation:
          "Save your wording beneath an existing idea. A comment saves text only; a question also requests a connected RationalGrid answer."
      },
      %{
        name: "apply_grid_action",
        label: "Use a thinking tool",
        explanation:
          "Generate a connected explanation, counterexample, evidence question or another thinking move from the thinking-tools guide. Synthesis can connect several existing ideas."
      },
      %{
        name: "create_learning_plan",
        label: "Suggest a learning path",
        explanation:
          "Save suggested tools and follow-up questions for an idea or selected passage, with reasons. It prepares a plan rather than executing every suggestion."
      },
      %{
        name: "get_exploration_tools",
        label: "Discover the thinking tools",
        explanation:
          "Read the current catalogue, what each tool does and whether it can work on a selected passage, without generating anything."
      },
      %{
        name: "get_operation",
        label: "Check progress and saved results",
        explanation:
          "Check an accepted request by its saved reference, including partial generation or visibility verification. Checking does not restart or duplicate the work."
      },
      %{
        name: "get_server_capabilities",
        label: "Check availability and limits",
        explanation:
          "Read current generation capacity, content limits, polling guidance and supported features, so a client can work within the server's bounds."
      },
      %{
        name: "export_grid",
        label: "Export a saved version",
        explanation:
          "Read the full persisted graph in a versioned editorial format, with available source references. It creates no new answers and currently leaves unprepared editorial brief fields empty."
      },
      %{
        name: "set_grid_visibility",
        label: "Make an owned grid public or private",
        explanation:
          "Set the intended visibility with a separate permission. Public requests require a reviewed revision and completed generation; results distinguish an applied change from verified anonymous access."
      }
    ]
  end
end
