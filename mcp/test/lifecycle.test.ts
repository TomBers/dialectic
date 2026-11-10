import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

for (const shutdown of ["signal", "parent_exit"] as const) {
  test(`supervised gateway exits when ${shutdown} occurs`, { timeout: 10_000 }, async () => {
    const reservation = createServer().listen(0, "127.0.0.1");
    await once(reservation, "listening");
    const address = reservation.address();
    assert.ok(address && typeof address !== "string");
    const port = address.port;
    await new Promise<void>(resolve => reservation.close(() => resolve()));
    const child = spawn(process.execPath, ["--import", "tsx", fileURLToPath(new URL("../src/index.ts", import.meta.url))], {
      env: { ...process.env, NODE_ENV: "production", MCP_SUPERVISED: "1", MCP_HOST: "127.0.0.1", MCP_PORT: String(port), MCP_PUBLIC_URL: `http://127.0.0.1:${port}/mcp`, PHOENIX_BASE_URL: "http://127.0.0.1:4000" },
      stdio: ["pipe", "ignore", "pipe"],
    });
    let errors = "";
    child.stderr.on("data", chunk => { errors += String(chunk); });
    const exited = once(child, "exit", { signal: AbortSignal.timeout(8000) });
    try {
      let ready = false;
      for (let attempt = 0; attempt < 80 && child.exitCode === null; attempt++) {
        try { ready = (await fetch(`http://127.0.0.1:${port}/health`)).ok; } catch {}
        if (ready) break;
        await new Promise(resolve => setTimeout(resolve, 50));
      }
      assert.ok(ready, errors || "Gateway did not become ready");
      if (shutdown === "signal") child.kill("SIGTERM");
      else child.stdin.end();
      const [code] = await exited;
      assert.equal(code, 0, errors);
    } finally {
      if (child.exitCode === null) child.kill("SIGKILL");
      await exited.catch(() => {});
    }
  });
}
