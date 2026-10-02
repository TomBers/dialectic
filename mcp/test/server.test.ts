import assert from "node:assert/strict";
import { once } from "node:events";
import { createHash, randomUUID } from "node:crypto";
import { z } from "zod";
import { createServer as createHttpServer, get, type Server } from "node:http";
import { afterEach, beforeEach, test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import type { OAuthClientProvider } from "@modelcontextprotocol/sdk/client/auth.js";
import { createApp, previewUri } from "../src/server.js";

const grid = { id: "reasoning-abc123", title: "Reasoning", url: "https://rationalgrid.ai/g/reasoning-abc123", tags: ["philosophy"] };
const searchResult = { grids: [{ ...grid, matches: [{ node_id: "2", snippet: "Follow the evidence" }] }] };
const readResult = {
  grid,
  nodes: [{ id: "2", content: "Follow the evidence", class: "answer" }],
  edges: [{ from: "1", to: "2" }],
  total_nodes: 3,
  next_offset: 2,
};

let upstream: Server;
let listener: Server;
let client: Client;
let endpoint: URL;
let requests: { url: URL; method: string; authorization?: string; cookie?: string; body: string }[];
let upstreamStatus: number;
let upstreamBody: unknown;

function origin(server: Server) {
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  return `http://127.0.0.1:${address.port}`;
}

beforeEach(async () => {
  requests = [];
  upstreamStatus = 200;
  upstreamBody = undefined;
  upstream = createHttpServer(async (request, response) => {
    const url = new URL(request.url!, "http://localhost");
    let body = "";
    for await (const chunk of request) body += chunk;
    requests.push({ url, method: request.method!, authorization: request.headers.authorization, cookie: request.headers.cookie, body });
    if (url.pathname === "/.well-known/oauth-authorization-server") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({
        issuer: origin(upstream),
        authorization_endpoint: `${origin(upstream)}/oauth/authorize`,
        token_endpoint: `${origin(upstream)}/oauth/token`,
        response_types_supported: ["code"],
        grant_types_supported: ["authorization_code"],
        token_endpoint_auth_methods_supported: ["none"],
        code_challenge_methods_supported: ["S256"],
      }));
      return;
    }
    if (url.pathname === "/oauth/token") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ access_token: "linked-test-token", token_type: "Bearer", expires_in: 3600, scope: "grids:read" }));
      return;
    }
    response.writeHead(upstreamStatus, { "content-type": "application/json" });
    response.end(JSON.stringify(upstreamBody ?? (url.pathname === "/api/public/grids" ? searchResult : readResult)));
  }).listen(0, "127.0.0.1");
  await once(upstream, "listening");

  listener = createHttpServer().listen(0, "127.0.0.1");
  await once(listener, "listening");
  endpoint = new URL("/mcp", origin(listener));
  listener.on("request", createApp(origin(upstream), { publicUrl: endpoint.href }));
  client = new Client({ name: "rationalgrid-test", version: "0.1.0" });
  await client.connect(new StreamableHTTPClientTransport(endpoint));
});

afterEach(async () => {
  await client?.close();
  for (const server of [listener, upstream]) {
    if (server) await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});

test("discovers public reads, preview, and four scoped account tools", async () => {
  const { tools } = await client.listTools();
  assert.equal(tools.length, 7);
  assert.equal(tools.filter(tool => tool.name.startsWith("get_")).length, 0);
  for (const tool of tools) {
    assert.equal(tool.annotations?.readOnlyHint, !["create_grid", "apply_grid_action", "add_grid_idea"].includes(tool.name));
    assert.equal(tool.annotations?.destructiveHint, false);
    assert.ok(tool.inputSchema);
    assert.ok(tool.outputSchema);
    const scope = tool.name === "create_grid" ? "grids:create" : tool.name === "read_my_grid" ? "grids:read" : ["apply_grid_action", "add_grid_idea"].includes(tool.name) ? "grids:append" : undefined;
    const securitySchemes = scope ? [{ type: "oauth2", scopes: [scope] }] : [{ type: "noauth" }];
    assert.deepEqual(tool._meta?.securitySchemes, securitySchemes);
  }
  assert.equal(requests.length, 0);
  const raw = await fetch(endpoint, {
    method: "POST", headers: { accept: "application/json, text/event-stream", "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 20, method: "tools/list" }),
  });
  const rawTools = (await raw.json()).result.tools;
  for (const tool of rawTools) assert.deepEqual(tool.securitySchemes, tool._meta.securitySchemes);
});

test("search returns text and structured data and safely encodes query parameters", async () => {
  const query = "evidence & privacy?";
  const result = await client.callTool({ name: "search_public_grids", arguments: { query } });
  assert.equal(result.isError, undefined);
  assert.deepEqual(result.structuredContent, searchResult);
  assert.deepEqual(result.content, [{ type: "text", text: JSON.stringify(searchResult, null, 2) }]);
  assert.equal(requests[0].url.pathname, "/api/public/grids");
  assert.equal(requests[0].url.searchParams.get("query"), query);
  assert.equal(requests[0].url.searchParams.get("limit"), "10");
  assert.equal(requests[0].method, "GET");
});

test("read forwards pagination and retains node IDs and cross-page edges", async () => {
  const result = await client.callTool({ name: "read_grid", arguments: { grid_id: grid.id, offset: 1, limit: 1 } });
  assert.deepEqual(result.structuredContent, readResult);
  assert.equal(requests[0].url.pathname, `/api/public/grids/${grid.id}`);
  assert.equal(requests[0].url.searchParams.get("offset"), "1");
  assert.equal(requests[0].url.searchParams.get("limit"), "1");
});

test("invalid inputs cannot reach Phoenix", async () => {
  for (const call of [
    { name: "search_public_grids", arguments: { query: "x" } },
    { name: "search_public_grids", arguments: { query: "evidence", limit: 21 } },
    { name: "read_grid", arguments: { grid_id: ".." } },
    { name: "read_grid", arguments: { grid_id: "../private" } },
    { name: "read_grid", arguments: { grid_id: grid.id, offset: -1 } },
    { name: "create_grid", arguments: { question: "change something" } },
  ]) {
    const result = await client.callTool(call);
    assert.equal(result.isError, true);
  }
  assert.equal(requests.length, 0);
});

const draft = {
  request_id: randomUUID(), title: "Chat ideas", tags: [],
  nodes: [{ id: "question", content: "What would change our minds?", kind: "origin" }], edges: [],
};

async function authenticatedCall(name: string, args: Record<string, unknown>, token = "test-token", expectedStatus = 200) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { accept: "application/json, text/event-stream", "content-type": "application/json", authorization: `Bearer ${token}`, cookie: "ignored=session" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 10, method: "tools/call", params: { name, arguments: args } }),
  });
  assert.equal(response.status, expectedStatus);
  const result = (await response.json()).result;
  if ([401, 403].includes(expectedStatus)) {
    assert.equal(response.headers.get("www-authenticate"), result._meta["mcp/www_authenticate"][0]);
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
  return result;
}

test("grid actions require append permission and forward only the selected action", async () => {
  const action = { grid_id: grid.id, request_id: randomUUID(), node_id: "2", action: "clarify" };
  const anonymous = await authenticatedCall("apply_grid_action", action, "", 401);
  assert.equal(anonymous.isError, true);
  assert.match(JSON.stringify(anonymous._meta), /grids:append/);
  assert.equal(requests.length, 0);
  for (const status of ["queued", "generating", "completed", "failed", "unknown"]) {
    upstreamBody = { grid: { ...grid, visibility: "public" }, request_id: action.request_id, status, node: { id: "4", parent_node_id: "2", class: "clarify", content: status === "completed" ? "Clarified terms" : "" } };
    const result = await authenticatedCall("apply_grid_action", { ...action, user_id: 123, content: "ignored", chat_history: "ignored" });
    assert.deepEqual(result.structuredContent, upstreamBody);
    assert.deepEqual(result.content, [{ type: "text", text: JSON.stringify(upstreamBody, null, 2) }]);
  }
  assert.equal(requests.length, 5);
  for (const request of requests) {
    assert.equal(request.method, "POST");
    assert.equal(request.url.pathname, `/api/mcp/grids/${grid.id}/actions`);
    assert.equal(request.authorization, "Bearer test-token");
    assert.deepEqual(JSON.parse(request.body), { request_id: action.request_id, node_id: "2", action: "clarify" });
  }
});

test("invalid grid actions never reach Phoenix and append failures are safe", async () => {
  const action = { grid_id: grid.id, request_id: randomUUID(), node_id: "2", action: "clarify" };
  for (const invalid of [{ action: "delete" }, { node_id: "" }, { grid_id: "../private" }, { request_id: "bad" }]) {
    assert.equal((await authenticatedCall("apply_grid_action", { ...action, ...invalid })).isError, true);
  }
  assert.equal(requests.length, 0);
  for (const status of [401, 403, 404, 409, 410, 422, 423, 429, 500]) {
    upstreamStatus = status;
    upstreamBody = { error: "private backend detail" };
    const result = await authenticatedCall("apply_grid_action", action, "test-token", [401, 403].includes(status) ? status : 200);
    assert.equal(result.isError, true);
    assert.doesNotMatch(JSON.stringify(result), /private backend detail/);
    if ([401, 403].includes(status)) assert.match(JSON.stringify(result._meta), /grids:append/);
    if (status === 423) assert.match(JSON.stringify(result.content), /locked/);
  }
  assert.equal(requests.length, 9);
});

test("authored ideas require append permission and forward exact text, not generation or ownership fields", async () => {
  const idea = { grid_id: grid.id, request_id: randomUUID(), parent_node_id: "2", content: "  My **own** idea\n\nKeep it.  " };
  const anonymous = await authenticatedCall("add_grid_idea", idea, "", 401);
  assert.equal(anonymous.isError, true);
  assert.match(JSON.stringify(anonymous._meta), /grids:append/);
  assert.equal(requests.length, 0);
  upstreamBody = { grid: { ...grid, visibility: "private" }, request_id: idea.request_id, status: "completed", node: { id: "4", parent_node_id: "2", class: "user", content: idea.content } };
  for (const _attempt of [1, 2]) {
    const result = await authenticatedCall("add_grid_idea", { ...idea, user_id: 123, action: "clarify", is_public: true, chat_history: "ignored" });
    assert.deepEqual(result.structuredContent, upstreamBody);
    assert.deepEqual(result.content, [{ type: "text", text: JSON.stringify(upstreamBody, null, 2) }]);
  }
  assert.equal(requests.length, 2);
  for (const request of requests) {
    assert.equal(request.method, "POST");
    assert.equal(request.url.pathname, `/api/mcp/grids/${grid.id}/nodes`);
    assert.equal(request.authorization, "Bearer test-token");
    assert.deepEqual(JSON.parse(request.body), { request_id: idea.request_id, parent_node_id: "2", content: idea.content, kind: "comment" });
  }
});

test("question mode preserves user text and exposes a separate asynchronous AI answer", async () => {
  const question = { grid_id: grid.id, request_id: randomUUID(), parent_node_id: "2", content: "Why is this true?", kind: "question" };
  for (const status of ["queued", "generating", "completed", "failed"]) {
    upstreamBody = {
      grid: { ...grid, visibility: "private" }, request_id: question.request_id, status,
      node: { id: "4", parent_node_id: "2", class: "question", content: question.content },
      answer_node: { id: "5", parent_node_id: "4", class: "answer", content: status === "completed" ? "The AI answer" : "" },
    };
    const result = await authenticatedCall("add_grid_idea", question);
    assert.deepEqual(result.structuredContent, upstreamBody);
    assert.deepEqual(result.content, [{ type: "text", text: JSON.stringify(upstreamBody, null, 2) }]);
  }
  assert.equal(requests.length, 4);
  for (const request of requests) {
    assert.equal(request.url.pathname, `/api/mcp/grids/${grid.id}/nodes`);
    assert.deepEqual(JSON.parse(request.body), { request_id: question.request_id, parent_node_id: "2", content: question.content, kind: "question" });
  }
  const { tools } = await client.listTools();
  const input = tools.find(tool => tool.name === "add_grid_idea")!.inputSchema;
  assert.deepEqual((input.properties!.kind as { enum: string[] }).enum, ["comment", "question"]);
  assert.equal((input.properties!.kind as { default: string }).default, "comment");
});

test("invalid authored ideas never reach Phoenix and errors do not claim a save", async () => {
  const idea = { grid_id: grid.id, request_id: randomUUID(), parent_node_id: "2", content: "My idea" };
  for (const invalid of [{ kind: "answer" }, { kind: null }, { content: " \n\t" }, { content: "a".repeat(4001) }, { content: null }, { parent_node_id: "" }, { grid_id: "../private" }, { request_id: "bad" }]) {
    assert.equal((await authenticatedCall("add_grid_idea", { ...idea, ...invalid })).isError, true);
  }
  assert.equal(requests.length, 0);
  for (const status of [401, 403, 404, 409, 410, 422, 423, 500]) {
    upstreamStatus = status;
    upstreamBody = { error: "private backend detail" };
    const result = await authenticatedCall("add_grid_idea", idea, "test-token", [401, 403].includes(status) ? status : 200);
    assert.equal(result.isError, true);
    assert.equal(result.structuredContent, undefined);
    assert.doesNotMatch(JSON.stringify(result), /private backend detail/);
    if ([401, 403].includes(status)) assert.match(JSON.stringify(result._meta), /grids:append/);
  }
});

test("anonymous saves return a scoped OAuth challenge and never reach Phoenix", async () => {
  const result = await authenticatedCall("create_grid", draft, "", 401);
  assert.equal(result.isError, true);
  assert.match(JSON.stringify(result._meta), /mcp\/www_authenticate/);
  assert.match(JSON.stringify(result._meta), /grids:create/);
  assert.match(JSON.stringify(result._meta), /oauth-protected-resource\/mcp/);
  assert.equal(requests.length, 0);
});

test("SDK OAuth client discovers auth, generates its own state and PKCE, exchanges a code and reads with its token", async () => {
  let tokens: Awaited<ReturnType<OAuthClientProvider["tokens"]>>;
  let verifier = "";
  let authorizationUrl: URL | undefined;
  const state = randomUUID();
  const provider: OAuthClientProvider = {
    redirectUrl: "http://localhost:6274/oauth/callback",
    clientMetadata: {
      redirect_uris: ["http://localhost:6274/oauth/callback"],
      grant_types: ["authorization_code"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    },
    state: () => state,
    clientInformation: () => ({ client_id: "test-client", issuer: origin(upstream) }),
    tokens: () => tokens,
    saveTokens: saved => { tokens = saved; },
    codeVerifier: () => verifier,
    saveCodeVerifier: saved => { verifier = saved; },
    redirectToAuthorization: url => { authorizationUrl = url; },
  };
  const transport = new StreamableHTTPClientTransport(endpoint, { authProvider: provider });
  const authenticatedClient = new Client({ name: "oauth-test", version: "1.0.0" });
  try {
    await authenticatedClient.connect(transport);
    await assert.rejects(authenticatedClient.callTool({ name: "read_my_grid", arguments: { grid_id: grid.id } }), /Unauthorized/);
    assert.ok(authorizationUrl);
    assert.equal(authorizationUrl.origin, origin(upstream));
    assert.equal(authorizationUrl.searchParams.get("state"), state);
    assert.equal(authorizationUrl.searchParams.get("client_id"), "test-client");
    assert.equal(authorizationUrl.searchParams.get("resource"), endpoint.href);
    assert.equal(authorizationUrl.searchParams.get("scope"), "grids:read");
    assert.equal(authorizationUrl.searchParams.get("code_challenge_method"), "S256");
    assert.equal(authorizationUrl.searchParams.get("code_challenge"), createHash("sha256").update(verifier).digest("base64url"));
    assert.ok(!requests.some(request => request.url.pathname.startsWith("/api/mcp/")));
    await transport.finishAuth("approved-test-code");
    const tokenRequest = requests.find(request => request.url.pathname === "/oauth/token")!;
    const tokenParams = new URLSearchParams(tokenRequest.body);
    assert.equal(tokenParams.get("code"), "approved-test-code");
    assert.equal(tokenParams.get("code_verifier"), verifier);
    assert.equal(tokenParams.get("resource"), endpoint.href);
    assert.equal(tokenParams.get("client_id"), "test-client");
    upstreamBody = { ...readResult, grid: { ...grid, visibility: "private" } };
    const result = await authenticatedClient.callTool({ name: "read_my_grid", arguments: { grid_id: grid.id } });
    assert.deepEqual(result.structuredContent, upstreamBody);
    assert.equal(requests.at(-1)?.authorization, "Bearer linked-test-token");
  } finally {
    await authenticatedClient.close();
  }
});

test("expired tokens and insufficient scopes trigger SDK authorization instead of an ordinary tool error", async () => {
  for (const status of [401, 403]) {
    upstreamStatus = status;
    let authorizationUrl: URL | undefined;
    let verifier = "";
    const provider: OAuthClientProvider = {
      redirectUrl: "http://localhost:6274/oauth/callback",
      clientMetadata: { redirect_uris: ["http://localhost:6274/oauth/callback"], grant_types: ["authorization_code"], response_types: ["code"], token_endpoint_auth_method: "none" },
      clientInformation: () => ({ client_id: "test-client", issuer: origin(upstream) }),
      tokens: () => ({ access_token: "old-token", token_type: "Bearer", scope: "grids:read" }),
      saveTokens: () => {},
      codeVerifier: () => verifier,
      saveCodeVerifier: saved => { verifier = saved; },
      redirectToAuthorization: url => { authorizationUrl = url; },
    };
    const authenticatedClient = new Client({ name: "reauth-test", version: "1.0.0" });
    try {
      await authenticatedClient.connect(new StreamableHTTPClientTransport(endpoint, { authProvider: provider }));
      await assert.rejects(authenticatedClient.callTool({ name: "add_grid_idea", arguments: { grid_id: grid.id, parent_node_id: "2", content: "My idea", request_id: randomUUID() } }), /Unauthorized/);
      assert.ok(authorizationUrl);
      assert.equal(authorizationUrl.searchParams.get("scope"), "grids:append");
    } finally {
      await authenticatedClient.close();
    }
  }
});

test("protected metadata identifies the resource and Phoenix authorization server", async () => {
  const response = await fetch(new URL("/.well-known/oauth-protected-resource/mcp", endpoint));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    resource: endpoint.href, authorization_servers: [origin(upstream)],
    scopes_supported: ["grids:create", "grids:read", "grids:append"], bearer_methods_supported: ["header"],
  });
  assert.throws(() => createApp(origin(upstream), { publicUrl: "http://insecure.example/mcp" }));
});

test("saving forwards only the linked token and validated draft, with no implicit retry", async () => {
  upstreamBody = { grid: { ...grid, visibility: "private" }, node_count: 1 };
  const result = await authenticatedCall("create_grid", { ...draft, user_id: 123, is_public: true, chat_history: "not transferred" });
  assert.deepEqual(result.structuredContent, upstreamBody);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].method, "POST");
  assert.equal(requests[0].url.pathname, "/api/mcp/grids");
  assert.equal(requests[0].authorization, "Bearer test-token");
  assert.equal(requests[0].cookie, undefined);
  assert.deepEqual(JSON.parse(requests[0].body), draft);
});

test("tokens are isolated between simultaneous requests and owned reads are paginated", async () => {
  upstreamBody = { ...readResult, grid: { ...grid, visibility: "private" } };
  const results = await Promise.all([
    authenticatedCall("read_my_grid", { grid_id: grid.id, limit: 1, offset: 2 }, "first-token"),
    authenticatedCall("read_my_grid", { grid_id: grid.id, limit: 1, offset: 2 }, "second-token"),
  ]);
  assert.ok(results.every(result => !result.isError));
  assert.deepEqual(requests.map(request => request.authorization).sort(), ["Bearer first-token", "Bearer second-token"]);
  assert.ok(requests.every(request => request.url.pathname === `/api/mcp/grids/${grid.id}` && request.url.searchParams.get("offset") === "2"));
});

test("invalid or insufficient tokens ask for authorization; safe errors hide backend details", async () => {
  upstreamBody = { error: "private backend detail" };
  for (const status of [401, 403, 409, 410, 422, 500]) {
    upstreamStatus = status;
    const result = await authenticatedCall("create_grid", draft, "test-token", [401, 403].includes(status) ? status : 200);
    assert.equal(result.isError, true);
    assert.doesNotMatch(JSON.stringify(result), /private backend detail/);
    if ([401, 403].includes(status)) assert.match(JSON.stringify(result._meta), /mcp\/www_authenticate/);
    else assert.equal(result._meta, undefined);
  }
  assert.equal(requests.length, 6);
});

test("skill discovery returns matching frontmatter, readable content, and digest", async () => {
  const response = await client.request({ method: "skills/list" }, z.object({ skills: z.array(z.object({ uri: z.string(), frontmatter: z.object({ name: z.string(), description: z.string() }), resources: z.array(z.object({ uri: z.string(), digest: z.string() })) })) }));
  assert.equal(response.skills.length, 1);
  const skill = response.skills[0];
  const read = await client.readResource({ uri: skill.uri });
  const text = read.contents[0].text;
  assert.equal(typeof text, "string");
  assert.match(text as string, new RegExp(`name: ${skill.frontmatter.name}`));
  assert.ok((text as string).includes(`description: ${skill.frontmatter.description}`));
  assert.equal(skill.resources[0].digest, `sha256:${createHash("sha256").update(text as string).digest("hex")}`);
  const fetched = await client.request({ method: "skills/get", params: { uri: skill.uri } }, z.object({ skill: z.unknown() }));
  assert.deepEqual(fetched.skill, skill);
});

test("preview returns a complete unsaved draft without contacting Phoenix", async () => {
  const result = await client.callTool({ name: "preview_grid", arguments: { ...draft, user_id: 123, transcript: "not included" } });
  assert.equal(result.isError, undefined);
  assert.deepEqual(result.structuredContent, { status: "draft", draft });
  assert.match(JSON.stringify(result.content), /nothing saved/);
  assert.doesNotMatch(JSON.stringify(result), /not included|user_id/);
  assert.equal(requests.length, 0);
});

test("only the preview tool renders UI, while create remains callable by model and app", async () => {
  const { tools } = await client.listTools();
  const preview = tools.find(tool => tool.name === "preview_grid")!;
  assert.deepEqual(preview._meta?.ui, { resourceUri: previewUri, visibility: ["model"] });
  assert.deepEqual(preview._meta?.securitySchemes, [{ type: "noauth" }]);
  const create = tools.find(tool => tool.name === "create_grid")!;
  assert.deepEqual(create._meta?.ui, { visibility: ["model", "app"] });
  for (const tool of tools.filter(tool => tool.name !== "preview_grid")) {
    assert.equal((tool._meta?.ui as Record<string, unknown> | undefined)?.resourceUri, undefined);
  }
  const resource = await client.readResource({ uri: previewUri });
  assert.equal(resource.contents.length, 1);
  assert.equal(resource.contents[0].mimeType, "text/html;profile=mcp-app");
  const text = resource.contents[0].text as string;
  assert.match(text, /id="save-grid"/);
  assert.match(text, /id="open-grid"/);
  assert.doesNotMatch(text, /\{\{SCRIPT\}\}|<script[^>]+src=/);
  assert.deepEqual(resource.contents[0]._meta, { ui: { prefersBorder: true, csp: { connectDomains: [], resourceDomains: [] } } });
  assert.equal(requests.length, 0);
});

test("invalid graph previews fail without writing or presenting an actionable draft", async () => {
  const root = draft.nodes[0];
  const idea = { id: "idea", content: "Another idea", kind: "answer" };
  for (const invalid of [
    { ...draft, nodes: [root, root] },
    { ...draft, nodes: [idea] },
    { ...draft, nodes: [root, idea] },
    { ...draft, edges: [{ from: "question", to: "missing" }] },
    { ...draft, nodes: [root, idea], edges: [{ from: "question", to: "idea" }, { from: "idea", to: "question" }] },
  ]) {
    const result = await client.callTool({ name: "preview_grid", arguments: invalid });
    assert.equal(result.isError, true);
    assert.equal(result.structuredContent, undefined);
  }
  assert.equal(requests.length, 0);
});

test("local demo is opt-in and serves the same self-contained card", async () => {
  assert.equal((await fetch(new URL("/preview-demo", endpoint))).status, 404);
  const demo = createApp(origin(upstream), { uiDemo: true }).listen(0, "127.0.0.1");
  await once(demo, "listening");
  try {
    const page = await fetch(`${origin(demo)}/preview-demo`);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /Local, read-only demo/);
    const widget = await fetch(`${origin(demo)}/preview-demo/widget`);
    assert.match(await widget.text(), /id="save-grid"/);
  } finally {
    await new Promise<void>((resolve, reject) => demo.close(error => error ? reject(error) : resolve()));
  }
});

test("upstream failures become tool errors without exposing backend details", async () => {
  for (const status of [404, 429, 500]) {
    upstreamStatus = status;
    upstreamBody = { error: "secret backend details" };
    const result = await client.callTool({ name: "read_grid", arguments: { grid_id: grid.id } });
    assert.equal(result.isError, true);
    assert.equal(result.structuredContent, undefined);
    assert.doesNotMatch(JSON.stringify(result.content), /secret backend details/);
  }
  upstreamStatus = 200;
  upstreamBody = { unexpected: "secret backend details" };
  const malformed = await client.callTool({ name: "search_public_grids", arguments: { query: "evidence" } });
  assert.equal(malformed.isError, true);
  assert.doesNotMatch(JSON.stringify(malformed.content), /secret backend details/);
});

test("simultaneous calls use independent stateless transports", async () => {
  const results = await Promise.all([
    client.callTool({ name: "search_public_grids", arguments: { query: "evidence" } }),
    client.callTool({ name: "read_grid", arguments: { grid_id: grid.id } }),
  ]);
  assert.deepEqual(results.map(result => result.structuredContent), [searchResult, readResult]);
});

test("unsupported HTTP methods and browser origins are rejected", async () => {
  for (const method of ["GET", "DELETE", "PUT"]) {
    const response = await fetch(endpoint, { method });
    assert.equal(response.status, 405);
    assert.equal(response.headers.get("allow"), "POST");
  }
  const response = await fetch(endpoint, { method: "POST", headers: { origin: "https://untrusted.example" } });
  assert.equal(response.status, 403);
  const invalidHostStatus = await new Promise<number | undefined>((resolve, reject) => {
    get(endpoint, { headers: { host: "untrusted.example" } }, response => {
      response.resume();
      resolve(response.statusCode);
    }).on("error", reject);
  });
  assert.equal(invalidHostStatus, 403);
  assert.equal(requests.length, 0);
});

test("MCP client credentials are never forwarded to the anonymous Phoenix API", async () => {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      accept: "application/json, text/event-stream",
      "content-type": "application/json",
      authorization: "Bearer client-secret",
      cookie: "session=client-secret",
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "search_public_grids", arguments: { query: "evidence" } } }),
  });
  assert.equal(response.status, 200);
  assert.equal(requests[0].authorization, undefined);
  assert.equal(requests[0].cookie, undefined);
});
