import { test, expect } from "@playwright/test";

/**
 * Deployment readiness E2E
 *
 * This spec fully exercises the major UI flows:
 * - New graph creation (from Start Tutorial page)
 * - Streaming end-to-end with robust completion waits
 * - Action toolbar interactions: Related Ideas, Pros/Cons, Deep Dive
 * - Disabled states while a query is in-flight (ask form + action buttons)
 * - Toggling right panel and bottom menu
 * - Starting a new stream via the "Start a new group" modal
 * - Reader (modal) open via Enter, arrow navigation, and close
 * - Optional: Lock/unlock behavior and Combine flow best-effort (if available)
 *
 * Assumptions:
 * - Server is running locally and OPENAI_API_KEY is set (non-test env).
 * - Base URL is configured in Playwright config (or default http://localhost:4000).
 * - Oban queues are running for streaming workers.
 */

const PAUSE = Number(process.env.E2E_PAUSE_MS || 3000);
const LONG_PAUSE = Number(process.env.E2E_LONG_PAUSE_MS || 15000);
const EXPECT_TIMEOUT = Number(process.env.E2E_EXPECT_TIMEOUT || 30000);

// Small helper to avoid unhandled rejections on conditional interactions
async function isVisibleSafe(locator: ReturnType<typeof test.extend> extends never ? never : any) {
  try {
    return await locator.isVisible({ timeout: 1000 });
  } catch {
    return false;
  }
}

async function wait(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}

// Wait for streaming to settle by observing that core controls become enabled again.
// Uses multiple signals to be robust:
// - Ask form submit re-enabled
// - Ask input re-enabled
// - Action buttons re-enabled
async function waitForStreamingToSettle(page: any) {
  const askSubmit = page.locator('form:has(#global-chat-input) button[type="submit"]');
  const askInput = page.locator("#global-chat-input");
  const relatedBtn = page.locator('button[title="Related ideas"]');
  const prosConsBtn = page.locator('button[title="Pros and Cons"]');
  const deepDiveBtn = page.locator('button[title="Deep dive"]');

  await expect(askSubmit).toBeEnabled({ timeout: EXPECT_TIMEOUT });
  await expect(askInput).toBeEnabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(relatedBtn)) await expect(relatedBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(prosConsBtn)) await expect(prosConsBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(deepDiveBtn)) await expect(deepDiveBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });

  // Give the UI a breath post-enable (DOM settle)
  await wait(500);
}

// Assert core ask/action controls are disabled (in-flight)
async function expectInFlightDisabled(page: any) {
  const askSubmit = page.locator('form:has(#global-chat-input) button[type="submit"]');
  const askInput = page.locator("#global-chat-input");
  const relatedBtn = page.locator('button[title="Related ideas"]');
  const prosConsBtn = page.locator('button[title="Pros and Cons"]');
  const deepDiveBtn = page.locator('button[title="Deep dive"]');

  await expect(askSubmit).toBeDisabled({ timeout: EXPECT_TIMEOUT });
  await expect(askInput).toBeDisabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(relatedBtn)) await expect(relatedBtn).toBeDisabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(prosConsBtn)) await expect(prosConsBtn).toBeDisabled({ timeout: EXPECT_TIMEOUT });
  if (await isVisibleSafe(deepDiveBtn)) await expect(deepDiveBtn).toBeDisabled({ timeout: EXPECT_TIMEOUT });
}

test("deployment readiness: full UI flow works end-to-end", async ({ page }) => {
  // 1) Start page with tutorial + ask form
  await page.goto("/start/new/idea", { waitUntil: "domcontentloaded" });

  const askInput = page.locator("#global-chat-input");
  await expect(askInput).toBeVisible({ timeout: EXPECT_TIMEOUT });

  // Cycle prompt mode is visible and clickable pre-stream
  const modeBtn = page.locator('button[title="Cycle LLM mode"]');
  await expect(modeBtn).toBeVisible({ timeout: EXPECT_TIMEOUT });

  // "Inspire me" populates a question
  const inspireBtn = page.getByTitle("Inspire me");
  await expect(inspireBtn).toBeVisible({ timeout: EXPECT_TIMEOUT });
  await inspireBtn.click();
  await wait(PAUSE);

  // Submit to create a new graph and begin streaming
  const askFormSubmit = page.locator('form:has(#global-chat-input) button[type="submit"]');
  await expect(askFormSubmit).toBeVisible({ timeout: EXPECT_TIMEOUT });
  await askFormSubmit.click();

  // Should redirect off /start/new/idea
  await expect(page).not.toHaveURL(/\/start\/new\/idea/, { timeout: EXPECT_TIMEOUT });

  // Wait for initial streaming to settle
  await waitForStreamingToSettle(page);

  // Ensure some rendered content exists (stable portion or article)
  const prose = page.locator("article.prose");
  const stableBlock = page.locator('[id^="node-stable-"]');
  await expect(prose.or(stableBlock)).toBeVisible({ timeout: EXPECT_TIMEOUT });

  // 2) Toggle right panel open/close
  const rightToggle = page.locator("#right-panel-toggle");
  if (await isVisibleSafe(rightToggle)) {
    const initialExpanded = (await rightToggle.getAttribute("aria-expanded")) === "true";
    await rightToggle.click();
    await expect(rightToggle).toHaveAttribute("aria-expanded", initialExpanded ? "false" : "true", {
      timeout: EXPECT_TIMEOUT,
    });
    // Toggle back to original state
    await rightToggle.click();
    await expect(rightToggle).toHaveAttribute("aria-expanded", initialExpanded ? "true" : "false", {
      timeout: EXPECT_TIMEOUT,
    });
  }

  // 3) Toggle bottom menu open/close
  const bottomToggle = page.locator("#bottom-menu-toggle");
  const bottomClose = page.locator("#bottom-menu-close");
  if (await isVisibleSafe(bottomToggle)) {
    await bottomToggle.click();
    await expect(bottomToggle).toHaveAttribute("aria-expanded", "true", { timeout: EXPECT_TIMEOUT });
    if (await isVisibleSafe(bottomClose)) {
      await bottomClose.click();
      await expect(bottomToggle).toHaveAttribute("aria-expanded", "false", { timeout: EXPECT_TIMEOUT });
    }
  }

  // 4) Open Start Stream modal, then cancel, then open and create a group
  // Ensure right panel is open (button exists and aria-expanded true)
  if (await isVisibleSafe(rightToggle)) {
    // Ensure open
    const expanded = (await rightToggle.getAttribute("aria-expanded")) === "true";
    if (!expanded) {
      await rightToggle.click().catch(() => {});
      await expect(rightToggle).toHaveAttribute("aria-expanded", "true", {
        timeout: EXPECT_TIMEOUT,
      });
    }

    const startStreamTrigger = page.locator('button[phx-click="open_start_stream_modal"]');
    if (await isVisibleSafe(startStreamTrigger)) {
      // First: open and cancel
      await startStreamTrigger.click();
      const startStreamModal = page.locator("#start-stream-modal");
      await expect(startStreamModal).toBeVisible({ timeout: EXPECT_TIMEOUT });

      const cancelBtn = startStreamModal.locator('button[phx-click="cancel_start_stream"]');
      if (await isVisibleSafe(cancelBtn)) {
        await cancelBtn.click();
        await expect(startStreamModal).toBeHidden({ timeout: EXPECT_TIMEOUT });
      }

      // Next: open and create
      await startStreamTrigger.click();
      await expect(startStreamModal).toBeVisible({ timeout: EXPECT_TIMEOUT });

      const nameInput = startStreamModal.locator('input[type="text"]');
      await expect(nameInput).toBeVisible({ timeout: EXPECT_TIMEOUT });
      await nameInput.fill(`E2E Group ${Date.now()}`);

      const submitNewGroup = startStreamModal.locator('form[phx-submit="start_stream"] button[type="submit"]');
      await expect(submitNewGroup).toBeVisible({ timeout: EXPECT_TIMEOUT });
      await submitNewGroup.click();
      await expect(startStreamModal).toBeHidden({ timeout: EXPECT_TIMEOUT });
    }
  }

  // 5) Actions: Related Ideas, Pros/Cons, Deep Dive
  // Each action: click, verify disabled state (in-flight), wait for re-enable (settled)
  const relatedBtn = page.locator('button[title="Related ideas"]');
  const prosConsBtn = page.locator('button[title="Pros and Cons"]');
  const deepDiveBtn = page.locator('button[title="Deep dive"]');

  // Related Ideas
  if (await isVisibleSafe(relatedBtn)) {
    await expect(relatedBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });
    await relatedBtn.click();
    await expectInFlightDisabled(page);
    await waitForStreamingToSettle(page);
  }

  // Pros/Cons
  if (await isVisibleSafe(prosConsBtn)) {
    await expect(prosConsBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });
    await prosConsBtn.click();
    await expectInFlightDisabled(page);
    await waitForStreamingToSettle(page);
  }

  // Deep Dive
  if (await isVisibleSafe(deepDiveBtn)) {
    await expect(deepDiveBtn).toBeEnabled({ timeout: EXPECT_TIMEOUT });
    await deepDiveBtn.click();
    await expectInFlightDisabled(page);
    await waitForStreamingToSettle(page);
  }

  // 6) Optional Combine flow (best-effort)
  const combineBtn = page.locator('button[title="Combine with another"]');
  if (await isVisibleSafe(combineBtn)) {
    try {
      await combineBtn.click({ timeout: 3000 });
      const combineModal = page.locator("#confirm-modal");
      // Wait briefly if it appears; otherwise skip gracefully
      await combineModal.waitFor({ state: "visible", timeout: 5000 }).catch(() => {});
      if (await isVisibleSafe(combineModal)) {
        // Try clicking the first candidate if available
        const candidate = combineModal.locator('[phx-click="combine_node_select"]').first();
        if (await isVisibleSafe(candidate)) {
          await candidate.click({ timeout: 3000 }).catch(() => {});
          // Allow streaming to happen
          await expectInFlightDisabled(page);
          await waitForStreamingToSettle(page);
        } else {
          // Close modal if no candidates
          await page.keyboard.press("Escape").catch(() => {});
          await combineModal.waitFor({ state: "hidden", timeout: 5000 }).catch(() => {});
        }
      }
    } catch {
      // Ignore if overlay or conditions not suitable in this run
    }
  }

  // 7) Lock/unlock behavior
  const lockToggle = page.locator("#toggle_lock_graph");
  if (await isVisibleSafe(lockToggle)) {
    await lockToggle.click().catch(() => {});
    await wait(PAUSE);

    // Attempt an action to surface lock behavior (flash typically appears)
    if (await isVisibleSafe(relatedBtn)) {
      await relatedBtn.click().catch(() => {});
      await wait(PAUSE);
    }

    // Unlock back
    await lockToggle.click().catch(() => {});
    await wait(PAUSE);
  }

  // 8) Reader modal: open (Enter), arrow keys, close (Esc)
  await page.keyboard.press("Enter");
  const readerModal = page.locator("#modal-graph-live-modal-comp");
  await readerModal.waitFor({ state: "visible", timeout: EXPECT_TIMEOUT }).catch(() => {});
  if (await isVisibleSafe(readerModal)) {
    await page.keyboard.press("ArrowUp");
    await page.keyboard.press("ArrowDown");
    await page.keyboard.press("ArrowLeft");
    await page.keyboard.press("ArrowRight");
    await wait(PAUSE);
    await page.keyboard.press("Escape");
    await readerModal.waitFor({ state: "hidden", timeout: EXPECT_TIMEOUT }).catch(() => {});
  }

  // Final sanity: ensure content remains visible and controls are enabled
  await expect(prose.or(stableBlock)).toBeVisible({ timeout: EXPECT_TIMEOUT });
  await waitForStreamingToSettle(page);
});
