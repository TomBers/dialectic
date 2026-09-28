import { afterEach, describe, expect, it, vi } from "vitest";
import LearningDrag from "../learning_drag_hook.js";

let hook;

function setup() {
  document.body.innerHTML = `<div id="learning-workspace">
    <div id="controller"></div>
    <button id="grid" data-learning-drag data-grid-title="Inflation"></button>
    <a id="topic" data-learning-drop="42"><span id="topic-label">Economics</span></a>
    <a id="folder" data-learning-folder-drag="7" data-learning-folder-drop="7" data-learning-drop="7"></a>
    <a id="destination" data-learning-folder-drop="8" data-learning-drop="8"></a>
    <h2 id="root" data-learning-folder-drop="root">Collections</h2>
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
  it("moves folders into a destination or back to the collection root", () => {
    setup();
    expect(drag("folder", "dragstart").dataTransfer.effectAllowed).toBe("move");
    expect(drag("destination", "dragover").dataTransfer.dropEffect).toBe("move");
    drag("destination", "drop");
    expect(hook.pushEvent).toHaveBeenCalledWith("drop_folder", { collection_id: "7", parent_id: "8" });
    expect(hook.draggedFolderId).toBeNull();
    expect(document.getElementById("destination").dataset.dragOver).toBeUndefined();
    drag("folder", "dragstart");
    drag("root", "drop");
    expect(hook.pushEvent).toHaveBeenLastCalledWith("drop_folder", { collection_id: "7", parent_id: "root" });
  });

  it("rejects folder drops on topics or themselves and clears abandoned moves", () => {
    setup();
    drag("folder", "dragstart");
    expect(drag("topic", "dragover").defaultPrevented).toBe(false);
    expect(drag("folder", "dragover").defaultPrevented).toBe(false);
    drag("topic", "drop");
    drag("folder", "drop");
    drag("folder", "dragend");
    drag("destination", "drop");
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  it("copies grids into folders without treating them as folder moves", () => {
    setup();
    drag("grid", "dragstart");
    expect(drag("destination", "dragover").dataTransfer.dropEffect).toBe("copy");
    drag("destination", "drop");
    expect(hook.pushEvent).toHaveBeenCalledWith("drop_grid", { title: "Inflation", collection_id: "8" });
    drag("grid", "dragstart");
    expect(drag("root", "drop").defaultPrevented).toBe(false);
    expect(hook.pushEvent).toHaveBeenCalledTimes(1);
  });

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
