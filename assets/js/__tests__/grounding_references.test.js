import { describe, expect, it } from "vitest";
import { renderGroundingReferences } from "../markdown_hook.js";

function metadata({ chunks, supports, queries = [] }) {
  return {
    google: {
      groundingChunks: chunks,
      groundingSupports: supports,
      webSearchQueries: queries,
    },
  };
}

function web(title, uri) {
  return { web: { title, uri } };
}

function support(text, groundingChunkIndices, extraSegment = {}) {
  return {
    groundingChunkIndices,
    confidenceScores: [0.98],
    segment: { text, ...extraSegment },
  };
}

function render(html, groundingMetadata, id = "markdown-answer") {
  const root = document.createElement("div");
  root.id = id;
  root.innerHTML = html;
  renderGroundingReferences(root, groundingMetadata);
  return root;
}

describe("renderGroundingReferences", () => {
  it("builds references and all support passages from grounding metadata", () => {
    const redirect =
      "https://vertexaisearch.cloud.google.com/grounding-api-redirect/token";
    const root = render(
      "<p>One supported claim. Another supported claim.</p>",
      metadata({
        chunks: [web("example.org", redirect), web("Duplicate", redirect)],
        supports: [
          support("One supported claim.", [0]),
          support("Another supported claim.", [1]),
        ],
      }),
    );

    expect(root.querySelectorAll(".markdown-source-reference")).toHaveLength(1);
    expect(root.querySelector(".markdown-source-link").textContent).toBe(
      "example.org",
    );
    expect(root.querySelector(".link-domain")).toBeNull();
    expect(root.querySelectorAll(".markdown-source-support")).toHaveLength(2);
  });

  it("links Markdown-formatted supported text to its metadata references", () => {
    const root = render(
      "<p>The result is <strong>strong</strong> and independently reproduced.</p>",
      metadata({
        chunks: [
          web("First paper", "https://first.example/paper"),
          web("Second paper", "https://second.example/paper"),
        ],
        supports: [
          support(
            "The result is **strong** and independently reproduced.",
            [0, 1],
            { startIndex: 12, endIndex: 69 },
          ),
        ],
      }),
    );

    const citation = root.querySelector("[data-source-citation='1,2']");
    const links = citation.querySelectorAll("a");

    expect(links).toHaveLength(2);
    expect(links[0].getAttribute("href")).toBe("#markdown-answer-source-1");
    expect(links[1].getAttribute("href")).toBe("#markdown-answer-source-2");
    expect(citation.textContent).toBe("");
  });

  it("places references before follow-up questions", () => {
    const root = render(
      "<p>A sufficiently long uniquely supported claim appears here.</p><h2>Follow-up questions</h2><ol><li>What next?</li></ol>",
      metadata({
        chunks: [web("Research", "https://example.com/research")],
        supports: [
          support("A sufficiently long uniquely supported claim appears here.", [0]),
        ],
      }),
    );

    const headings = Array.from(root.querySelectorAll("h2")).map(
      (heading) => heading.textContent,
    );
    expect(headings).toEqual(["Sources", "Follow-up questions"]);
  });

  it("lists academic sources first without hiding supplementary sources", () => {
    const root = render(
      "<p>A sufficiently long claim with several kinds of supporting source.</p>",
      metadata({
        chunks: [
          web("reddit.com", "https://reddit.com/discussion"),
          web("journal.example", "https://journal.example/article"),
          web("stanford.edu", "https://stanford.edu/research"),
          web("youtube.com", "https://youtube.com/watch?v=example"),
        ],
        supports: [
          support(
            "A sufficiently long claim with several kinds of supporting source.",
            [0, 1, 2, 3],
          ),
        ],
      }),
    );

    const titles = Array.from(
      root.querySelectorAll(".markdown-source-link"),
      (link) => link.firstChild.textContent,
    );

    expect(titles).toEqual([
      "stanford.edu",
      "journal.example",
      "reddit.com",
      "youtube.com",
    ]);
  });

  it("does not render references without grounding metadata", () => {
    const root = render("<p>An ungrounded answer.</p>", null);

    expect(root.querySelector(".markdown-sources-heading")).toBeNull();
    expect(root.querySelector("[data-source-citation]")).toBeNull();
  });

  it("does not guess an inline citation when support text is ambiguous", () => {
    const claim = "This repeated supported passage is long enough to be considered.";
    const root = render(
      `<p>${claim}</p><p>${claim}</p>`,
      metadata({
        chunks: [web("Research", "https://example.com/research")],
        supports: [support(claim, [0])],
      }),
    );

    expect(root.querySelector("[data-source-citation]")).toBeNull();
    expect(root.querySelector(".markdown-source-reference")).not.toBeNull();
  });

  it("formats isolated table rows without exposing Markdown pipes", () => {
    const root = render(
      "<p><strong>View of the Universe</strong> Indifferent and hostile to human striving.</p>",
      metadata({
        chunks: [web("Research", "https://example.com/research")],
        supports: [
          support(
            "|\n| **View of the Universe** | Indifferent and hostile to human striving",
            [0],
          ),
          support("| Indifferent, yet embraced through human consciousness", [0]),
        ],
      }),
    );

    const bodies = root.querySelectorAll(".markdown-source-support-body");

    expect(bodies).toHaveLength(2);
    expect(bodies[0].textContent.trim()).toBe(
      "View of the Universe: Indifferent and hostile to human striving",
    );
    expect(bodies[0].textContent).not.toContain("|");
    expect(bodies[0].querySelector("strong").textContent).toBe(
      "View of the Universe",
    );
    expect(bodies[1].textContent.trim()).toBe(
      "Indifferent, yet embraced through human consciousness",
    );
  });
});
