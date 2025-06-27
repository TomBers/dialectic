/**
 * @jest-environment jsdom
 */

import listDetectionHook from "./list_detection_hook";

describe("List Detection Hook", () => {
  let container;
  let mockPushEvent;

  // Create a test harness that simulates the Phoenix LiveView hook environment
  function createHookHarness(html) {
    container = document.createElement("div");
    container.innerHTML = html;
    document.body.appendChild(container);

    // Create a mock hook context
    const hookContext = {
      el: container,
      pushEvent: mockPushEvent,
    };

    // Attach methods to the context
    Object.keys(listDetectionHook).forEach((key) => {
      if (typeof listDetectionHook[key] === "function") {
        hookContext[key] = listDetectionHook[key].bind(hookContext);
      }
    });

    return hookContext;
  }

  beforeEach(() => {
    mockPushEvent = jest.fn();
    // Clean up any previous test elements
    if (container) {
      document.body.removeChild(container);
    }
  });

  afterEach(() => {
    if (container) {
      document.body.removeChild(container);
    }
    jest.clearAllMocks();
  });

  test("should detect HTML lists (ul/ol)", () => {
    const html = `
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
        <li>Item 3</li>
      </ul>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: ["Item 1", "Item 2", "Item 3"],
    });
  });

  test("should detect paragraphs starting with bullet points", () => {
    const html = `
      <p>• First item</p>
      <p>• Second item</p>
      <p>• Third item</p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: ["First item", "Second item", "Third item"],
    });
  });

  test("should detect dash-style bullet points", () => {
    const html = `
      <p>- First item</p>
      <p>- Second item</p>
      <p>- Third item</p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: ["First item", "Second item", "Third item"],
    });
  });

  test("should detect bullet points separated by <br> tags in a single paragraph", () => {
    const html = `
      <p>
        • First item<br>
        • Second item<br>
        • Third item
      </p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: ["First item", "Second item", "Third item"],
    });
  });

  test("should handle the Macbeth characters example", () => {
    const html = `
      <p>
      • Macbeth – A Scottish noble and the play's tragic hero whose ambition leads him to murderous deeds.  <br>
      • Lady Macbeth – Macbeth's wife, whose manipulation and ambition spur him on.  <br>
      • The Three Witches – Mysterious figures whose prophecies set the tragic events in motion.  <br>
      • Banquo – Macbeth's friend and fellow general; his fate and his son's future play a crucial role in the unfolding prophecy.  <br>
      • King Duncan – The benevolent ruler whose murder marks the beginning of Macbeth's descent into tyranny.  <br>
      • Macduff – A nobleman who ultimately defies Macbeth and seeks to restore order to Scotland.  <br>
      • Malcolm – King Duncan's eldest son and the rightful heir, representing hope for Scotland's future.  <br>
      • Donalbain – Duncan's younger son, whose escape highlights the ensuing atmosphere of suspicion and chaos.
      </p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: [
        "Macbeth – A Scottish noble and the play's tragic hero whose ambition leads him to murderous deeds.",
        "Lady Macbeth – Macbeth's wife, whose manipulation and ambition spur him on.",
        "The Three Witches – Mysterious figures whose prophecies set the tragic events in motion.",
        "Banquo – Macbeth's friend and fellow general; his fate and his son's future play a crucial role in the unfolding prophecy.",
        "King Duncan – The benevolent ruler whose murder marks the beginning of Macbeth's descent into tyranny.",
        "Macduff – A nobleman who ultimately defies Macbeth and seeks to restore order to Scotland.",
        "Malcolm – King Duncan's eldest son and the rightful heir, representing hope for Scotland's future.",
        "Donalbain – Duncan's younger son, whose escape highlights the ensuing atmosphere of suspicion and chaos.",
      ],
    });
  });

  test("should detect bullet points within paragraph text", () => {
    const html = `
      <p>Here are some key points: • First important point • Second key insight • Third crucial detail</p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: [
        "First important point",
        "Second key insight",
        "Third crucial detail",
      ],
    });
  });

  test("should handle mixed bullet point styles in a paragraph", () => {
    const html = `
      <p>• First item<br>- Second item<br>* Third item</p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).toHaveBeenCalledWith("branch_list", {
      items: ["First item", "Second item", "Third item"],
    });
  });

  test("should not detect bullet points when none exist", () => {
    const html = `
      <p>This is a regular paragraph with no bullet points.</p>
      <p>Another paragraph without any lists.</p>
    `;

    const hook = createHookHarness(html);
    hook.checkForLists();

    expect(mockPushEvent).not.toHaveBeenCalled();
  });
});
