import { afterEach, describe, expect, it } from "vitest";
import { GRID_DRAFT_KEY, preserveAuthReturn } from "../auth_return.js";

afterEach(() => {
  document.body.replaceChildren();
  window.history.replaceState({}, "", "/");
  sessionStorage.clear();
});

function prepareLink(path = "/users/log_in") {
  document.body.innerHTML = `<div data-auth-return-node="12"><a href="${path}" data-phx-link="redirect" data-phx-link-state="push">Log in</a></div>`;
  return document.querySelector("a");
}

describe("authentication return links", () => {
  it("keeps private-grid signup separate from an unfinished public question", () => {
    const link = prepareLink("/users/register?return_to=%2Fmy%2Flearning%3Fnew%3Dtrue");
    link.dataset.preserveAuthReturn = "false";
    const form = document.createElement("form");
    form.id = "new-idea-form";
    form.innerHTML = '<textarea name="vertex[content]">An unfinished question</textarea>';
    document.body.append(form);
    preserveAuthReturn({target: link});
    expect(new URL(link.href).searchParams.get("return_to")).toBe("/my/learning?new=true");
    expect(sessionStorage.getItem(GRID_DRAFT_KEY)).toBeNull();
  });

  it("keeps a homepage question and depth out of the URL while arranging its return", () => {
    const link = prepareLink();
    const form = document.createElement("form");
    form.id = "new-idea-form";
    form.dataset.selectedMode = "expert";
    form.innerHTML = '<textarea name="vertex[content]">Why do ideas spread?</textarea>';
    document.body.append(form);
    preserveAuthReturn({target: link});
    expect(new URL(link.href).searchParams.get("return_to")).toBe("/?resume=grid#start-here");
    expect(link.href).not.toContain("ideas");
    expect(JSON.parse(sessionStorage.getItem(GRID_DRAFT_KEY))).toMatchObject({
      content: "Why do ideas spread?", mode: "expert",
    });
  });

  it("captures the selected passage's node and uses a full authentication request", () => {
    window.history.replaceState({}, "", "/g/my-grid?node=16&path=1,16");
    const link = prepareLink();
    preserveAuthReturn({ target: link });
    const destination = new URL(link.href);
    const returnTo = new URL(destination.searchParams.get("return_to"), window.location.origin);
    expect(returnTo.pathname).toBe("/g/my-grid");
    expect(returnTo.searchParams.get("node")).toBe("12");
    expect(returnTo.searchParams.get("path")).toBe("1,16");
    expect(returnTo.hash).toBe("#reading-node-12");
    expect(link.hasAttribute("data-phx-link")).toBe(false);
  });

  it("preserves the graph editor context for signup", () => {
    window.history.replaceState({}, "", "/g/my-grid/graph?node=16&focus=ask");
    const link = prepareLink("/users/register");
    preserveAuthReturn({ target: link });
    expect(new URL(link.href).searchParams.get("return_to"))
      .toBe("/g/my-grid/graph?node=12&focus=ask");
  });

  it("leaves links outside the grid and external links alone", () => {
    const link = prepareLink();
    preserveAuthReturn({ target: link });
    expect(link.getAttribute("href")).toBe("/users/log_in");
    window.history.replaceState({}, "", "/g/my-grid");
    link.href = "https://example.com/users/log_in";
    preserveAuthReturn({ target: link });
    expect(link.href).toBe("https://example.com/users/log_in");
  });
});
