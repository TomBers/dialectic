import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    // Test the real texture allocator while mocking its unused source utilities.
    server: {
      deps: { inline: [/cytoscape\/src\/extensions\/renderer\/canvas\/webgl\/atlas\.mjs/] },
    },
  },
});
