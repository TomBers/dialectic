import { afterEach, expect, it, vi } from "vitest";
import { containModalFocus } from "../modal_focus.js";

afterEach(() => { vi.restoreAllMocks(); document.body.innerHTML = ""; });

it("handles Escape and restores previously inert background state", () => {
  document.body.innerHTML = '<section id="background"></section><div id="modal"><button>Close</button></div>';
  const background = document.getElementById("background");
  background.inert = true;
  vi.spyOn(HTMLElement.prototype, "getClientRects").mockReturnValue([{}]);
  const onEscape = vi.fn();
  const focus = containModalFocus(document.getElementById("modal"), {onEscape});
  focus.focusFirst();
  document.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true}));
  expect(onEscape).toHaveBeenCalledOnce();
  focus.destroy();
  expect(background.inert).toBe(true);
});
