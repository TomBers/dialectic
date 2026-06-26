import { describe, it, expect, vi } from "vitest";
import { enhanceFollowUpQuestions } from "../markdown_hook.js";

function rootWith(html) {
  const root = document.createElement("div");
  root.id = "markdown-body-test";
  root.innerHTML = html;
  document.body.replaceChildren(root);
  return root;
}

describe("enhanceFollowUpQuestions", () => {
  it("turns a stable follow-up questions list into buttons", () => {
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>What makes the Higgs field unlike a mechanical medium?</li>
        <li>Why did ether theories fail experimentally?</li>
        <li>How does Lorentz invariance constrain modern fields?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    const buttons = root.querySelectorAll("button[data-follow-up-question]");
    expect(buttons).toHaveLength(3);
    expect(root.querySelector("ol")).toBeNull();
    expect(buttons[0].id).toBe("markdown-body-test-follow-up-1");
    expect(buttons[0].dataset.followUpQuestion).toBe(
      "What makes the Higgs field unlike a mechanical medium?",
    );
  });

  it("asks the clicked question through the provided callback", () => {
    const askQuestion = vi.fn();
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>Question one?</li>
        <li>Question two?</li>
        <li>Question three?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, askQuestion);
    root.querySelector("#markdown-body-test-follow-up-2").click();

    expect(askQuestion).toHaveBeenCalledWith("Question two?");
    expect(root.querySelector("#markdown-body-test-follow-up-2").disabled).toBe(
      true,
    );
  });

  it("does not convert lists without exactly three questions", () => {
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>Question one?</li>
        <li>Question two?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    expect(
      root.querySelectorAll("button[data-follow-up-question]"),
    ).toHaveLength(0);
    expect(root.querySelector("ol")).not.toBeNull();
  });

  it("preserves follow-up lists that include extra generated content", () => {
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>Question one?</li>
        <li>Question two?</li>
        <li>Question three?</li>
        <li>Additional context that should remain visible.</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    expect(
      root.querySelectorAll("button[data-follow-up-question]"),
    ).toHaveLength(0);
    expect(root.querySelector("ol")).not.toBeNull();
    expect(root.textContent).toContain(
      "Additional context that should remain visible.",
    );
  });

  it("does not convert unrelated lists", () => {
    const root = rootWith(`
      <h2>Reasons to care</h2>
      <ol>
        <li>Question one?</li>
        <li>Question two?</li>
        <li>Question three?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    expect(
      root.querySelectorAll("button[data-follow-up-question]"),
    ).toHaveLength(0);
    expect(root.querySelector("ol")).not.toBeNull();
  });

  it("supports legacy exploration headings and strips bold labels", () => {
    const root = rootWith(`
      <h2>Deepen Your Exploration</h2>
      <p>Consider these avenues of inquiry:</p>
      <ol>
        <li><strong>The Vacuum:</strong> What would happen if the Higgs field changed state?</li>
        <li><strong>Everyday Mass:</strong> Where does most proton mass originate?</li>
        <li><strong>Cosmic Coincidence:</strong> Why is the Higgs boson mass theoretically puzzling?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    const buttons = root.querySelectorAll("button[data-follow-up-question]");
    expect(buttons).toHaveLength(3);
    expect(buttons[0].dataset.followUpQuestion).toBe(
      "What would happen if the Higgs field changed state?",
    );
  });

  it("does not include rendered link domain badges in question text", () => {
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>What does <a href="https://example.com">vacuum decay<span class="link-domain">example.com</span></a> imply?</li>
        <li>Question two?</li>
        <li>Question three?</li>
      </ol>
    `);

    enhanceFollowUpQuestions(root, vi.fn());

    expect(
      root.querySelector("#markdown-body-test-follow-up-1").dataset
        .followUpQuestion,
    ).toBe("What does vacuum decay imply?");
  });

  it("disables a button when that question already exists as a child", () => {
    const askQuestion = vi.fn();
    const root = rootWith(`
      <h2>Follow-up questions</h2>
      <ol>
        <li>Question one?</li>
        <li>Question two?</li>
        <li>Question three?</li>
      </ol>
    `);
    root.setAttribute(
      "data-existing-follow-up-questions",
      JSON.stringify([" question TWO? "]),
    );

    enhanceFollowUpQuestions(root, askQuestion);

    const button = root.querySelector("#markdown-body-test-follow-up-2");
    expect(button.disabled).toBe(true);
    expect(button.dataset.followUpQuestionAsked).toBe("true");
    expect(button.textContent).toContain("Asked");

    button.click();
    expect(askQuestion).not.toHaveBeenCalled();
  });
});
