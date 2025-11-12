import { defineConfig, devices } from '@playwright/test';

// Playwright configuration for Dialectic E2E runner
// - Uses only public routes and UI
// - Assumes the Phoenix server is already running locally
// - Does NOT start or manage the server (no webServer config)
// - Generous timeouts to accommodate LLM streaming

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:4000';

export default defineConfig({
  testDir: './tests',

  // Default max time one test can run
  timeout: 5 * 60 * 1000, // 5 minutes

  expect: {
    // Maximum time expect() should wait for the condition to be met
    timeout: 60_000, // 60s
  },

  // Keep runs deterministic and simple for a single local server
  fullyParallel: false,
  workers: 1,
  retries: 0,

  // Reports
  reporter: [
    ['list'],
    ['html', { open: 'never' }],
  ],

  // Artifacts and defaults for all tests
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    viewport: { width: 1440, height: 900 },
    headless: true,

    // Be generous with timeouts to handle network/streaming latency
    actionTimeout: 30_000,
    navigationTimeout: 60_000,
  },

  outputDir: 'test-results',

  // Define projects (browsers)
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
