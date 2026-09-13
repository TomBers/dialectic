import { afterEach, describe, expect, it } from "vitest";
import { preserveAuthReturn } from "../auth_return.js";

afterEach(() => {
  document.body.replaceChildren();
  window.history.replaceState({}, "", "/");
});

function prepareLink(path = "/users/log_in") {
  document.body.innerHTML = `<div data-auth-return-node="12"><a href="${path}" data-phx-link="redirect" data-phx-link-state="push">Log in</a></div>`;
  return document.querySelector("a");
}

describe("authentication return links", () => {
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
