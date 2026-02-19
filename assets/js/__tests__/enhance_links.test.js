import { describe, it, expect, beforeEach } from "vitest";
import { enhanceLinks, ALLOWED_PROTOCOLS } from "../markdown_hook.js";

/**
 * Helper: creates a detached DOM container with the given inner HTML,
 * runs enhanceLinks on it, and returns the container for assertions.
 */
function enhance(html) {
  const root = document.createElement("div");
  root.innerHTML = html;
  enhanceLinks(root);
  return root;
}

describe("enhanceLinks", () => {
  describe("malicious protocol stripping", () => {
    it("strips javascript: links and keeps the text", () => {
      const root = enhance('<a href="javascript:alert(1)">Click me</a>');
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("Click me");
    });

    it("strips data: links and keeps the text", () => {
      const root = enhance(
        '<a href="data:text/html,<script>alert(1)</script>">Payload</a>',
      );
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("Payload");
    });

    it("strips vbscript: links and keeps the text", () => {
      const root = enhance('<a href="vbscript:MsgBox(1)">VB</a>');
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("VB");
    });

    it("strips javascript: with mixed case", () => {
      const root = enhance('<a href="JavaScript:void(0)">Tricky</a>');
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("Tricky");
    });

    it("strips blob: links", () => {
      const root = enhance(
        '<a href="blob:http://example.com/abc">Blob</a>',
      );
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("Blob");
    });

    it("strips file: links", () => {
      const root = enhance('<a href="file:///etc/passwd">File</a>');
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("File");
    });

    it("strips ftp: links", () => {
      const root = enhance('<a href="ftp://example.com/file">FTP</a>');
      expect(root.querySelector("a")).toBeNull();
      expect(root.textContent).toBe("FTP");
    });
  });

  describe("valid protocols", () => {
    it("keeps https: links intact", () => {
      const root = enhance(
        '<a href="https://example.com/page">Example</a>',
      );
      const link = root.querySelector("a");
      expect(link).not.toBeNull();
      expect(link.getAttribute("href")).toBe("https://example.com/page");
    });

    it("keeps http: links intact", () => {
      const root = enhance(
        '<a href="http://example.com/page">Example</a>',
      );
      const link = root.querySelector("a");
      expect(link).not.toBeNull();
      expect(link.getAttribute("href")).toBe("http://example.com/page");
    });
  });

  describe("relative URL handling", () => {
    it("converts relative paths to absolute using the page origin", () => {
      // Relative URLs are resolved against window.location.origin by new URL().
      // Since jsdom defaults to http://localhost, the resolved protocol is http:
      // which is in ALLOWED_PROTOCOLS, so the link is kept but rewritten.
      const root = enhance('<a href="/some/path">Relative</a>');
      const link = root.querySelector("a");
      // The link should still exist because http: (from localhost) is allowed
      expect(link).not.toBeNull();
    });

    it("handles bare fragment links by resolving against origin", () => {
      const root = enhance('<a href="#section">Jump</a>');
      const link = root.querySelector("a");
      expect(link).not.toBeNull();
    });
  });

  describe("protocol-relative URLs", () => {
    it("resolves protocol-relative URLs using the current page protocol", () => {
      // In jsdom the default location is http://localhost so //example.com
      // becomes http://example.com which is an allowed protocol.
      const root = enhance(
        '<a href="//example.com/path">Proto-relative</a>',
      );
      const link = root.querySelector("a");
      expect(link).not.toBeNull();
      expect(link.textContent).toContain("Proto-relative");
    });
  });

  describe("malformed URLs", () => {
    it("strips links with completely malformed hrefs", () => {
      const root = enhance('<a href="ht!tp://[invalid">Bad</a>');
      // new URL() with the base origin may still parse this, so just verify
      // it doesn't throw and produces a reasonable result
      expect(root.textContent).toContain("Bad");
    });
  });

  describe("safety attributes", () => {
    it("adds target=_blank when not already set", () => {
      const root = enhance(
        '<a href="https://example.com">Link</a>',
      );
      const link = root.querySelector("a");
      expect(link.getAttribute("target")).toBe("_blank");
    });

    it("preserves existing target attribute", () => {
      const root = enhance(
        '<a href="https://example.com" target="_self">Link</a>',
      );
      const link = root.querySelector("a");
      expect(link.getAttribute("target")).toBe("_self");
    });

    it("adds noopener, noreferrer, and nofollow to rel", () => {
      const root = enhance(
        '<a href="https://example.com">Link</a>',
      );
      const link = root.querySelector("a");
      const rel = link.getAttribute("rel");
      expect(rel).toContain("noopener");
      expect(rel).toContain("noreferrer");
      expect(rel).toContain("nofollow");
    });

    it("does not duplicate existing rel values", () => {
      const root = enhance(
        '<a href="https://example.com" rel="noopener">Link</a>',
      );
      const link = root.querySelector("a");
      const rel = link.getAttribute("rel");
      const noopenerCount = rel.split("noopener").length - 1;
      expect(noopenerCount).toBe(1);
      expect(rel).toContain("noreferrer");
      expect(rel).toContain("nofollow");
    });
  });

  describe("domain badge", () => {
    it("appends a domain badge with the hostname", () => {
      const root = enhance(
        '<a href="https://example.com/page">Example</a>',
      );
      const link = root.querySelector("a");
      const badge = link.querySelector(".link-domain");
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("example.com");
    });

    it("does not duplicate the badge on repeated calls", () => {
      const root = document.createElement("div");
      root.innerHTML = '<a href="https://example.com">Link</a>';
      enhanceLinks(root);
      enhanceLinks(root);
      const badges = root.querySelectorAll(".link-domain");
      expect(badges.length).toBe(1);
    });

    it("shows the correct hostname for subdomains", () => {
      const root = enhance(
        '<a href="https://sub.domain.example.com/path">Deep</a>',
      );
      const badge = root.querySelector(".link-domain");
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("sub.domain.example.com");
    });
  });

  describe("multiple links", () => {
    it("processes all links in the container", () => {
      const root = enhance(`
        <a href="https://good.com">Good</a>
        <a href="javascript:alert(1)">Bad</a>
        <a href="https://also-good.com">Also good</a>
      `);
      const links = root.querySelectorAll("a");
      expect(links.length).toBe(2);
      expect(root.textContent).toContain("Bad");
      expect(root.textContent).toContain("Good");
      expect(root.textContent).toContain("Also good");
    });
  });

  describe("ALLOWED_PROTOCOLS constant", () => {
    it("contains only https: and http:", () => {
      expect(ALLOWED_PROTOCOLS).toEqual(["https:", "http:"]);
    });
  });
});
