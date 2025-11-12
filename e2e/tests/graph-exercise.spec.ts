import { test, expect } from "@playwright/test";

/**
 * Dialectic E2E: Graph Exercise
 *
 * This script:
 *  - Navigates to /start/new/idea
 *  - Clicks "Inspire me" to auto-fill a random question
 *  - Submits the ask form to create a new graph with real LLM streaming
 *  - Exercises key graph actions (Related Ideas, Pros/Cons, Deep Dive, Explore, Combine)
 *  - Toggles lock and attempts an action to surface the lock behavior
 *  - Opens the reader and sends arrow keys for node movement
 *
 * Notes:
 *  - Uses only public pages and UI elements.
 *  - No assertions are made on content; waits are included so you can visually confirm progress.
 *  - Assumes the Phoenix server is running locally and OPENAI_API_KEY is set on the server side.
 */

const PAUSE = Number(process.env.E2E_PAUSE_MS || 3000);
const LONG_PAUSE = Number(process.env.E2E_LONG_PAUSE_MS || 10000);

async function pause(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}

test("graph exercise end-to-end", async ({ page }) => {
  // 1) Go to the new-idea route that shows the StartTutorial and ask form
  await page.goto("/start/new/idea", { waitUntil: "domcontentloaded" });

  // Make sure the ask input is visible
  const askInput = page.locator("#global-chat-input");
  await expect(askInput).toBeVisible();

  // 2) Click "Inspire me" to populate a random question
  // StartTutorialComp renders a button with title="Inspire me"
  const inspireBtn = page.getByTitle("Inspire me");
  await expect(inspireBtn).toBeVisible();
  await inspireBtn.click();

  // Give the input population a moment (the button JS populates and dispatches an input event)
  await pause(PAUSE);

  // 3) Submit the ask form to create a new graph and trigger streaming
  // Prefer a local form submit button within the form that contains the input
  const askFormSubmit = page.locator(
    'form:has(#global-chat-input) button[type="submit"]',
  );
  await expect(askFormSubmit).toBeVisible();
  await askFormSubmit.click();

  // Wait for redirect to the new graph page (URL should no longer be /start/new/idea)
  await expect(page).not.toHaveURL(/\/start\/new\/idea/);

  // Allow time for initial streaming tokens to show
  await pause(LONG_PAUSE);

  // 4) Exercise actions from the toolbar (ActionToolbarComp)

  // Related Ideas
  const relatedBtn = page.locator('button[title="Related ideas"]');
  if (await relatedBtn.isVisible().catch(() => false)) {
    await relatedBtn.click();
    await pause(LONG_PAUSE);
  }

  // Pros/Cons (Branch)
  const branchBtn = page.locator('button[title="Pros and Cons"]');
  if (await branchBtn.isVisible().catch(() => false)) {
    await branchBtn.click();
    await pause(LONG_PAUSE);
  }

  // Deep Dive
  const deepDiveBtn = page.locator('button[title="Deep dive"]');
  if (await deepDiveBtn.isVisible().catch(() => false)) {
    await deepDiveBtn.click();
    await pause(LONG_PAUSE);
  }

  // Explore points (open modal and submit)
  // const exploreBtn = page.locator("#explore-all-points");
  // if (await exploreBtn.isVisible().catch(() => false)) {
  //   await exploreBtn.click();

  //   // The explore modal content contains a form with phx-submit="submit_explore_modal"
  //   const exploreForm = page.locator('form[phx-submit="submit_explore_modal"]');
  //   if (await exploreForm.isVisible().catch(() => false)) {
  //     // Click the submit button inside the modal form
  //     const submitExplore = exploreForm.locator('button[type="submit"]');
  //     if (await submitExplore.isVisible().catch(() => false)) {
  //       await submitExplore.click();
  //       await pause(LONG_PAUSE);
  //     }
  //   }
  // }

  // Combine (move later so more nodes exist; open modal, wait for candidates, pick one)
  // const combineBtn = page.locator('button[title="Combine with another"]');
  // if (await combineBtn.isVisible().catch(() => false)) {
  //   // Try normal click; if overlay intercepts, close panels and force click as fallback
  //   try {
  //     await combineBtn.click({ timeout: 3000 });
  //   } catch (_e) {
  //     // Close any modal or overlays (Esc) and try to hide right panel if open
  //     try {
  //       await page.keyboard.press("Escape");
  //     } catch {}
  //     const rightPanelToggle = page.locator("#right-panel-toggle");
  //     if (await rightPanelToggle.isVisible().catch(() => false)) {
  //       const expanded = await rightPanelToggle
  //         .getAttribute("aria-expanded")
  //         .catch(() => null);
  //       if (expanded === "true") {
  //         await rightPanelToggle.click().catch(() => {});
  //         await pause(500);
  //       }
  //     }
  //     // Ensure bottom menu (toolbar) is open in case it's collapsed
  //     const bottomMenuToggle = page.locator("#bottom-menu-toggle");
  //     if (await bottomMenuToggle.isVisible().catch(() => false)) {
  //       await bottomMenuToggle.click().catch(() => {});
  //       await pause(300);
  //     }
  //     // Try a normal click again after clearing overlays
  //     try {
  //       await combineBtn.click({ timeout: 3000 });
  //     } catch {
  //       // Final fallback: force click (bypass actionability checks)
  //       await combineBtn.click({ force: true });
  //     }
  //   }

  //   // Wait for combine modal to appear (id "confirm-modal" from graph_live.html.heex)
  //   const combineModal = page.locator("#confirm-modal");
  //   // Try to wait for modal to be visible; if it doesn't open, retry once and continue
  //   try {
  //     await expect(combineModal).toBeVisible({ timeout: 5000 });
  //   } catch {
  //     // Retry opening the modal once
  //     try {
  //       await combineBtn.click({ timeout: 2000 });
  //     } catch {}
  //     await pause(1000);
  //   }

  //   // Wait for at least one candidate to be available before selecting
  //   const candidates = combineModal.locator(
  //     '[phx-click="combine_node_select"]',
  //   );
  //   await candidates
  //     .first()
  //     .waitFor({ state: "visible", timeout: 15_000 })
  //     .catch(() => {});

  //   // Click the first available candidate
  //   const combineCandidate = candidates.first();
  //   if (await combineCandidate.isVisible().catch(() => false)) {
  //     // Robust click sequence: try normal click, scroll into view, JS click, then mouse fallback
  //     try {
  //       await combineCandidate.click({ timeout: 3000 });
  //     } catch (_e) {
  //       try {
  //         await combineCandidate.scrollIntoViewIfNeeded();
  //         await combineCandidate.click({ timeout: 3000 });
  //       } catch (_e2) {
  //         try {
  //           const el = await combineCandidate.elementHandle();
  //           if (el) {
  //             await el.evaluate((n: HTMLElement) => n.click());
  //           } else {
  //             throw new Error("no elementHandle");
  //           }
  //         } catch (_e3) {
  //           const box = await combineCandidate.boundingBox();
  //           if (box) {
  //             await page.mouse.move(
  //               box.x + box.width / 2,
  //               box.y + box.height / 2,
  //             );
  //             await page.mouse.down();
  //             await page.mouse.up();
  //           } else {
  //             // Final fallback: force click to bypass actionability checks
  //             await combineCandidate.click({ force: true });
  //           }
  //         }
  //       }
  //     }
  //     await pause(LONG_PAUSE);
  //   }
  // }

  // 5) Toggle lock and attempt an action to see lock behavior (flash)
  const lockToggle = page.locator("#toggle_lock_graph");
  if (await lockToggle.isVisible().catch(() => false)) {
    // Lock
    await lockToggle.click();
    await pause(PAUSE);

    // Try an action immediately (e.g., Related Ideas)
    if (await relatedBtn.isVisible().catch(() => false)) {
      await relatedBtn.click();
      // Give time for the flash to show
      await pause(PAUSE);
    }

    // Unlock (optional)
    await lockToggle.click();
    await pause(PAUSE);
  }

  // 6) Open the "Reader" by pressing Enter, then move nodes with arrow keys, then close with Esc
  // The page listens for Enter and opens a modal with id "modal-graph-live-modal-comp"
  await page.keyboard.press("Enter");
  const readerModal = page.locator("#modal-graph-live-modal-comp");
  await readerModal
    .waitFor({ state: "visible", timeout: 15_000 })
    .catch(() => {});

  // Send a couple of movements (window-level keydown is wired in the modal)
  await page.keyboard.press("ArrowUp");
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("ArrowRight");

  await pause(PAUSE);

  // Close the reader modal
  await page.keyboard.press("Escape");
  await readerModal
    .waitFor({ state: "hidden", timeout: 15_000 })
    .catch(() => {});

  // 7) Done — allow a final pause to observe the final state
  await pause(PAUSE);
});
