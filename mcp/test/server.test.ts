import assert from "node:assert/strict";
import { once } from "node:events";
import { createServer as createHttpServer, get, type Server } from "node:http";
import { afterEach, beforeEach, test } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { createApp } from "../src/server.js";

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
let requests: { url: URL; method: string; authorization?: string; cookie?: string }[];
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
  upstream = createHttpServer((request, response) => {
    const url = new URL(request.url!, "http://localhost");
    requests.push({ url, method: request.method!, authorization: request.headers.authorization, cookie: request.headers.cookie });
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

test("initializes over Streamable HTTP and exposes only two read-only tools", async () => {
  const { tools } = await client.listTools();
  assert.deepEqual(tools.map(tool => tool.name).sort(), ["read_grid", "search_public_grids"]);
  for (const tool of tools) {
    assert.equal(tool.annotations?.readOnlyHint, true);
    assert.equal(tool.annotations?.destructiveHint, false);
    assert.ok(tool.inputSchema);
    assert.ok(tool.outputSchema);
  }
  assert.equal(requests.length, 0);
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

test("invalid inputs and unknown write tools cannot reach Phoenix", async () => {
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
