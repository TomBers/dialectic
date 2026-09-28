import { GRID_DRAFT_KEY } from "./auth_return.js";

export default {
  mounted() {
    if (this.el.dataset.resumeDraft !== "true") return;
    try {
      const draft = JSON.parse(sessionStorage.getItem(GRID_DRAFT_KEY));
      if (!draft || typeof draft.content !== "string" ||
          !["high_school", "university", "expert"].includes(draft.mode) ||
          !Number.isFinite(draft.savedAt) || Date.now() - draft.savedAt > 86400000) return;
      this.pushEventTo(this.el, "restore_draft", draft, (reply) => {
        if (reply.restored) sessionStorage.removeItem(GRID_DRAFT_KEY);
      });
    } catch { /* The form remains usable when storage is unavailable. */ }
  },
};
