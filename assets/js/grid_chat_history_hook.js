const MAX_MESSAGES = 100;

function mergeMessages(...histories) {
  const messages = new Map();
  for (const history of histories) {
    if (!Array.isArray(history)) continue;
    for (const message of history.slice(-MAX_MESSAGES)) {
      if (message && typeof message.id === "string") {
        messages.set(message.id, message);
      }
    }
  }
  return [...messages.values()].slice(-MAX_MESSAGES);
}

export default {
  mounted() {
    this.messages = [];
    this.storageKey = this.el.dataset.storageKey;

    this.handleEvent("grid_chat_message", ({ storage_key, message }) => {
      if (storage_key !== this.storageKey) return;
      this.messages = mergeMessages(this.messages, [message]);
      try {
        this.messages = mergeMessages(this.readMessages(), this.messages);
        localStorage.setItem(`${this.storageKey}:messages`, JSON.stringify(this.messages));
        this.showSavedStatus();
      } catch {
        this.showStorageError();
      }
    });

    this.handleEvent("grid_chat_history_cleared", ({ storage_key }) => {
      if (storage_key !== this.storageKey) return;
      this.messages = [];
      try {
        localStorage.removeItem(`${this.storageKey}:messages`);
        this.showSavedStatus();
      } catch {
        this.showStorageError();
      }
    });

    this.onStorageError = () => this.showStorageError();
    window.addEventListener("grid-chat-storage-error", this.onStorageError);
    this.restore();
  },

  updated() {
    if (this.storageKey === this.el.dataset.storageKey) return;
    this.storageKey = this.el.dataset.storageKey;
    this.messages = [];
    this.restore();
  },

  reconnected() {
    this.restore();
  },

  readMessages() {
    const saved = localStorage.getItem(`${this.storageKey}:messages`);
    if (!saved) return [];
    try {
      return mergeMessages(JSON.parse(saved));
    } catch {
      localStorage.removeItem(`${this.storageKey}:messages`);
      return [];
    }
  },

  restore() {
    try {
      this.messages = mergeMessages(this.readMessages(), this.messages);
      this.showSavedStatus();
    } catch {
      this.showStorageError();
    }
    this.pushEvent("restore_grid_chat", { messages: this.messages });
  },

  showSavedStatus() {
    this.el.textContent = "Last 100 messages saved in this browser only.";
  },

  showStorageError() {
    this.el.textContent = "Browser storage unavailable. Chat may be lost on refresh.";
  },

  destroyed() {
    window.removeEventListener("grid-chat-storage-error", this.onStorageError);
  },
};
