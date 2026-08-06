import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const appSource = readFileSync(resolve(process.cwd(), "js/app.js"), "utf8");

describe("global socket setup", () => {
  it("does not import the dormant user socket client", () => {
    expect(appSource).not.toMatch(
      /^\s*import\b[^\n]*["']\.\/user_socket(?:\.js)?["'];?\s*$/m,
    );
  });
});
