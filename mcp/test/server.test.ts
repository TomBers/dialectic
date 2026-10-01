import assert from "node:assert/strict";
import { once } from "node:events";
import { createHash, randomUUID } from "node:crypto";
import { z } from "zod";
import { createServer as createHttpServer, get, type Server } from "node:http";
import { afterEach, beforeEach, test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
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
    response.writeHead(upstreamStatus, { "content-type": "application/json" });
    response.end(JSON.stringify(upstreamBody ?? (url.pathname === "/api/public/grids" ? searchResult : readResult)));
  }).listen(0, "127.0.0.1");
  await once(upstream, "listening");

  listener = createApp(origin(upstream)).listen(0, "127.0.0.1");
  await once(listener, "listening");
  endpoint = new URL("/mcp", origin(listener));
  client = new Client({ name: "rationalgrid-test", version: "0.1.0" });
  await client.connect(new StreamableHTTPClientTransport(endpoint));
});

afterEach(async () => {
  await client?.close();
  for (const server of [listener, upstream]) {
    if (server) await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
});

test("discovers public reads, nine chat methods, and two scoped account tools", async () => {
  const { tools } = await client.listTools();
  assert.equal(tools.length, 14);
  assert.equal(tools.filter(tool => tool.name.startsWith("get_")).length, 9);
  for (const tool of tools) {
    assert.equal(tool.annotations?.readOnlyHint, tool.name !== "create_grid");
    assert.equal(tool.annotations?.destructiveHint, false);
    assert.ok(tool.inputSchema);
    assert.ok(tool.outputSchema);
    const scope = tool.name === "create_grid" ? "grids:create" : tool.name === "read_my_grid" ? "grids:read" : undefined;
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

async function authenticatedCall(name: string, args: Record<string, unknown>, token = "test-token") {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { accept: "application/json, text/event-stream", "content-type": "application/json", authorization: `Bearer ${token}`, cookie: "ignored=session" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 10, method: "tools/call", params: { name, arguments: args } }),
  });
  assert.equal(response.status, 200);
  return (await response.json()).result;
}

test("chat methods need no auth or conversation data and return usable guidance", async () => {
  upstreamBody = { id: "assumptions", title: "Identify assumptions", instructions: "Apply this method locally", prompt_template: "Consider {{selected_idea}}" };
  const result = await client.callTool({ name: "get_assumptions_method", arguments: {} });
  assert.deepEqual(result.structuredContent, upstreamBody);
  assert.equal(requests[0].url.pathname, "/api/public/thinking-methods/assumptions");
  assert.equal(requests[0].url.search, "");
  assert.equal(requests[0].body, "");
  assert.equal(requests[0].authorization, undefined);
});

test("anonymous saves return a scoped OAuth challenge and never reach Phoenix", async () => {
  const result = await client.callTool({ name: "create_grid", arguments: draft });
  assert.equal(result.isError, true);
  assert.match(JSON.stringify(result._meta), /mcp\/www_authenticate/);
  assert.match(JSON.stringify(result._meta), /grids:create/);
  assert.match(JSON.stringify(result._meta), /oauth-protected-resource\/mcp/);
  assert.equal(requests.length, 0);
});

test("protected metadata identifies the resource and Phoenix authorization server", async () => {
  const response = await fetch(new URL("/.well-known/oauth-protected-resource/mcp", endpoint));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    resource: "http://127.0.0.1:4001/mcp", authorization_servers: [origin(upstream)],
    scopes_supported: ["grids:create", "grids:read"], bearer_methods_supported: ["header"],
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
    const result = await authenticatedCall("create_grid", draft);
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
