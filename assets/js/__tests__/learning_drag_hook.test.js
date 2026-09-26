import { afterEach, describe, expect, it, vi } from "vitest";
import LearningDrag from "../learning_drag_hook.js";

let hook;

function setup() {
  document.body.innerHTML = `<div id="learning-workspace">
    <div id="controller"></div>
    <button id="grid" data-learning-drag data-grid-title="Inflation"></button>
    <a id="topic" data-learning-drop="42"><span id="topic-label">Economics</span></a>
  </div>`;
  hook = Object.create(LearningDrag);
  hook.el = document.getElementById("controller");
  hook.pushEvent = vi.fn();
  hook.mounted();
}

function drag(id, type) {
  const event = new Event(type, { bubbles: true, cancelable: true });
  event.dataTransfer = { setData: vi.fn() };
  document.getElementById(id).dispatchEvent(event);
  return event;
}

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
});

describe("learning topic drag and drop", () => {
  it("adds a dragged grid to the topic under the pointer and clears drag state", () => {
    setup();
    drag("grid", "dragstart");
    expect(drag("topic-label", "dragover").defaultPrevented).toBe(true);
    expect(document.getElementById("topic").dataset.dragOver).toBe("true");
    drag("topic-label", "drop");
    expect(hook.pushEvent).toHaveBeenCalledWith("drop_grid", { title: "Inflation", collection_id: "42" });
    expect(document.getElementById("topic").dataset.dragOver).toBeUndefined();
    drag("topic", "drop");
    expect(hook.pushEvent).toHaveBeenCalledTimes(1);
  });

  it("ignores external drops and cancels a drag that ends outside a topic", () => {
    setup();
    drag("topic", "drop");
    drag("grid", "dragstart");
    drag("topic", "dragover");
    drag("grid", "dragend");
    drag("topic", "drop");
    expect(hook.pushEvent).not.toHaveBeenCalled();
    expect(document.getElementById("topic").dataset.dragOver).toBeUndefined();
  });

  it("handles streamed-in grids and removes listeners on destruction", () => {
    setup();
    const grid = document.getElementById("grid");
    grid.replaceWith(grid.cloneNode(true));
    drag("grid", "dragstart");
    drag("topic", "drop");
    expect(hook.pushEvent).toHaveBeenCalledTimes(1);
    const instance = hook;
    hook.destroyed();
    hook = null;
    drag("grid", "dragstart");
    drag("topic", "drop");
    expect(instance.pushEvent).toHaveBeenCalledTimes(1);
  });
});
