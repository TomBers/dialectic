import { createApp } from "./server.js";

const port = Number(process.env.MCP_PORT || 4001);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("MCP_PORT must be an integer between 1 and 65535.");
}

const app = createApp(process.env.PHOENIX_BASE_URL || "http://localhost:4000");
const listener = app.listen(port, "127.0.0.1", () => {
  console.log(`RationalGrid MCP listening at http://127.0.0.1:${port}/mcp`);
});

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.once(signal, () => { listener.close(); });
}
