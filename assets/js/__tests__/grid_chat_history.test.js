import { afterEach, expect, it, vi } from "vitest";
import historyHook from "../grid_chat_history_hook.js";
import formHook from "../grid_chat_form_hook.js";

const mounted = [];
const key = "grid-chat:v1:user:1:example";

afterEach(() => {
  for (const instance of mounted.splice(0)) instance.destroyed();
  vi.restoreAllMocks();
  localStorage.clear();
});

function mount(hook, storageKey = key, form = false) {
  const el = document.createElement(form ? "form" : "p");
  el.dataset.storageKey = storageKey;
  if (form) el.appendChild(document.createElement("textarea"));
  const handlers = {};
  const instance = {
    ...hook,
    el,
    pushEvent: vi.fn(),
    handleEvent: (name, handler) => { handlers[name] = handler; },
    handlers,
  };
  instance.mounted();
  mounted.push(instance);
  return instance;
}

function receive(instance, id) {
  instance.handlers.grid_chat_message({
    storage_key: instance.storageKey,
    message: { id, body: `Message ${id}` },
  });
}

it("persists received messages, caps and deduplicates them, and restores after remount and reconnect", () => {
  const first = mount(historyHook);
  for (let id = 0; id < 105; id++) receive(first, String(id));
  receive(first, "104");
  const saved = JSON.parse(localStorage.getItem(`${key}:messages`));
  expect(saved).toHaveLength(100);
  expect(saved[0].id).toBe("5");
  expect(saved[99].id).toBe("104");

  const second = mount(historyHook);
  expect(second.pushEvent).toHaveBeenLastCalledWith("restore_grid_chat", { messages: saved });
  second.reconnected();
  expect(second.pushEvent).toHaveBeenLastCalledWith("sync_grid_chat_history", { messages: saved });

  localStorage.removeItem(`${key}:messages`);
  second.reconnected();
  expect(second.messages).toEqual([]);
  expect(second.pushEvent).toHaveBeenLastCalledWith("sync_grid_chat_history", { messages: [] });
});

it("keeps accounts and grids separate and clears only the selected history", () => {
  const first = mount(historyHook);
  const second = mount(historyHook, "grid-chat:v1:user:2:example");
  const peer = mount(historyHook);
  receive(first, "one");
  receive(peer, "peer-message");
  receive(second, "two");
  first.handlers.grid_chat_message({storage_key: second.storageKey, message: {id: "wrong"}});
  expect(JSON.parse(localStorage.getItem(`${key}:messages`))).toHaveLength(2);

  first.handlers.grid_chat_history_cleared({storage_key: key});
  expect(localStorage.getItem(`${key}:messages`)).toBeNull();
  expect(localStorage.getItem(`${second.storageKey}:messages`)).not.toBeNull();
  window.dispatchEvent(new StorageEvent("storage", {
    key: `${key}:messages`, newValue: null, storageArea: localStorage,
  }));
  expect(peer.messages).toEqual([]);
  expect(peer.pushEvent).toHaveBeenLastCalledWith("sync_grid_chat_history", { messages: [] });
  expect(second.messages.map(message => message.id)).toEqual(["two"]);

  peer.messages = [{id: "stale", body: "An old cached message"}];
  receive(peer, "new");
  expect(JSON.parse(localStorage.getItem(`${key}:messages`)).map(m => m.id)).toEqual(["new"]);
  expect(mount(historyHook, `${key}-another-grid`).pushEvent)
    .toHaveBeenCalledWith("restore_grid_chat", {messages: []});
});

it("recovers from corrupt history and reports unavailable storage without breaking chat", () => {
  localStorage.setItem(`${key}:messages`, "{broken");
  const instance = mount(historyHook);
  expect(instance.pushEvent).toHaveBeenCalledWith("restore_grid_chat", {messages: []});
  vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("Full"); });
  expect(() => receive(instance, "one")).not.toThrow();
  expect(instance.el.textContent).toContain("storage unavailable");
});

it("restores drafts after remount and clears the saved draft when a message is accepted", () => {
  const first = mount(formHook, key, true);
  first.textarea.value = "An unfinished thought";
  first.textarea.dispatchEvent(new Event("input"));
  const second = mount(formHook, key, true);
  expect(second.textarea.value).toBe("An unfinished thought");
  expect(mount(formHook, `${key}-other`, true).textarea.value).toBe("");
  second.handlers.clear_grid_chat_form();
  expect(second.textarea.value).toBe("");
  expect(localStorage.getItem(`${key}:draft`)).toBeNull();
});
