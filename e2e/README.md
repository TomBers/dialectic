# Dialectic E2E Runner (Playwright)

This folder contains a lightweight, standalone end‑to‑end (E2E) runner you can use locally to exercise the full Dialectic UI with real LLM requests. It intentionally uses only public routes and UI (no dev/test hooks, no internal function calls) so it mirrors a real user’s experience.

Highlights
- Uses the actual “Inspire me” button to generate a question via /api/random_question.
- Submits the Ask form to create a brand new graph and watches real-time LLM streaming (OpenAIWorker).
- Clicks through key graph actions (Related Ideas, Pros/Cons, Combine, Deep Dive, Explore).
- Toggles the lock and attempts an action (to surface the “locked” behavior).
- Opens the Reader and performs node move actions via arrow keys.
- No assertions; the script just paces itself so you can visually confirm the flow.

Safety and scope
- This E2E code is not referenced by the Phoenix application and does not change any router/views/components. It’s safe to keep in the repo and deploy your app—production is unaffected.
- The runner uses only publicly available UI and routes.

Prerequisites
- Node.js >= 18
- Phoenix app running locally (dev environment)
- A configured OpenAI API key on the Phoenix server process:
  - OPENAI_API_KEY must be set and accessible to the server. The app uses OpenAI in non‑test environments for LLM streaming.
- Oban queues must be running (the server should start them by default in dev).

Install
1) From this folder:
   - cd dialectic/e2e
   - npm install
   - npm run e2e:install   # installs Playwright browsers and deps

2) Start the Phoenix server (separately), from the project root:
   - MIX_ENV=dev OPENAI_API_KEY=sk-... mix phx.server

   Notes:
   - The runner assumes http://localhost:4000 by default.
   - If you are using a different host/port, set BASE_URL before running tests (see Configuration below).

Run
- Headed (recommended the first time so you can watch it happen):
  - cd dialectic/e2e
  - npm run e2e:headed

- Headless:
  - cd dialectic/e2e
  - npm run e2e

- Playwright UI (debugger-like UI):
  - cd dialectic/e2e
  - npm run e2e:ui

- Run only the structured test:
  - cd dialectic/e2e
  - npm run e2e:structured

- Run only the creative test:
  - cd dialectic/e2e
  - npm run e2e:creative

- One command (start server + run a single test):
  - Structured:
    - npm run e2e:structured:with-server
  - Creative:
    - npm run e2e:creative:with-server

Artifacts and reports
- HTML report:
  - npm run e2e:report
- Trace/video:
  - The config keeps trace/video on failures by default; you can force traces with:
    - npm run e2e:trace

Configuration
- BASE_URL: override the target app URL (default: http://localhost:4000)
  - Example:
    - BASE_URL=http://127.0.0.1:4000 npm run e2e:headed
- Timing/pacing:
  - E2E_PAUSE_MS: small pauses between actions (default: 3000)
  - E2E_LONG_PAUSE_MS: long pauses to allow LLM streaming (default: 10000)
  - Example:
    - E2E_PAUSE_MS=1500 E2E_LONG_PAUSE_MS=8000 npm run e2e:headed

What the script does (at a glance)
- Navigate to /start/new/idea
- Click the “Inspire me” button (fetches a random question and fills #global-chat-input)
- Submit the ask form (creates a new graph: /:graph_name?node=1&ask=...)
- Wait while LLM streams a response (real OpenAI path)
- Click toolbar actions:
  - Related ideas
  - Pros/Cons (branch)
  - Combine (opens modal, selects a second node)
  - Deep Dive
  - Explore (open and submit modal)
- Toggle lock and attempt an edit action to show the “locked” flash
- Open Reader (press Enter), send Arrow keys (move nodes), close Reader (Esc)

Troubleshooting
- If nothing streams:
  - Ensure the Phoenix server has OPENAI_API_KEY set.
  - Watch server logs for “OpenAI API key not configured” or request errors.
- If the runner times out:
  - Increase E2E_LONG_PAUSE_MS to give the model more time.
  - Ensure Oban is running and the queues are processing jobs.
- If selectors change:
  - The script relies on stable attributes in the public UI (e.g., #global-chat-input, button titles like “Related ideas”, “Pros and Cons”, “Deep dive”, and #explore-all-points). If these change in the app, adjust the selectors in tests/graph-exercise.spec.ts.

Notes on “one command” server + test
- This E2E runner intentionally does not manage the Phoenix server. You start it yourself and run the tests in a separate shell. This keeps it simple and avoids accidental coupling to your local setup.

Caveats
- Running this exercise uses your real OpenAI API key and may incur costs. Keep the scenario brief or throttle usage as needed.
- The test does not assert on the content; it’s meant to visually confirm that UI and streaming behave as expected.

Happy testing!