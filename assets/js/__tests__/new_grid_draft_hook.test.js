import { afterEach, expect, it, vi } from "vitest";
import hook from "../new_grid_draft_hook.js";
import { GRID_DRAFT_KEY } from "../auth_return.js";

afterEach(() => sessionStorage.clear());

function restore(resume = "true") {
  const el = document.createElement("form");
  el.dataset.resumeDraft = resume;
  const pushEventTo = vi.fn();
  hook.mounted.call({el, pushEventTo});
  return pushEventTo;
}

it("restores a draft once and waits for server acknowledgement before clearing it", () => {
  const draft = {content: "Why do ideas spread?", mode: "expert", savedAt: Date.now()};
  sessionStorage.setItem(GRID_DRAFT_KEY, JSON.stringify(draft));
  const send = restore();
  expect(send).toHaveBeenCalledWith(expect.any(HTMLFormElement), "restore_draft", draft, expect.any(Function));
  expect(sessionStorage.getItem(GRID_DRAFT_KEY)).not.toBeNull();
  send.mock.calls[0][3]({restored: false});
  expect(sessionStorage.getItem(GRID_DRAFT_KEY)).not.toBeNull();
  send.mock.calls[0][3]({restored: true});
  expect(sessionStorage.getItem(GRID_DRAFT_KEY)).toBeNull();
});

it("does not resume on an ordinary visit or restore invalid and expired drafts", () => {
  sessionStorage.setItem(GRID_DRAFT_KEY, JSON.stringify({content: "Draft", mode: "expert", savedAt: Date.now()}));
  expect(restore("false")).not.toHaveBeenCalled();
  for (const value of ["invalid", "null", JSON.stringify({content: "Draft", mode: "expert", savedAt: 0})]) {
    sessionStorage.setItem(GRID_DRAFT_KEY, value);
    expect(restore()).not.toHaveBeenCalled();
  }
});
