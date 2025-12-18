/**
 * LiveView Hook: InterfaceHighlight
 *
 * Purpose
 * - Toggle which region of the interface screenshot is highlighted when the user
 *   hovers (or focuses) description items.
 *
 * How it works
 * - Expects the hook root element (`this.el`) to contain:
 *   - "trigger" elements with: `data-interface-highlight-trigger="<key>"`
 *   - an image wrapper that will be styled based on:
 *       `data-interface-highlight-active="<key>"`
 *
 * Behaviour
 * - On mouseenter / focusin of a trigger, sets:
 *     this.el.dataset.interfaceHighlightActive = <key>
 * - On mouseleave / focusout, clears the active highlight (unless focus remains
 *   within another trigger).
 *
 * Notes
 * - This hook is intentionally framework-light: it only manages a data-attribute.
 *   You handle actual visuals in CSS/Tailwind (e.g. show/hide overlay rectangles
 *   based on `[data-interface-highlight-active="graph"]`).
 */
const InterfaceHighlightHook = {
  mounted() {
    this._onTriggerEnter = (e) => {
      const trigger = this._closestTrigger(e.target);
      if (!trigger) return;

      const key = trigger.getAttribute("data-interface-highlight-trigger");
      if (!key) return;

      this.el.dataset.interfaceHighlightActive = key;
    };

    this._onTriggerLeave = (e) => {
      // If we're moving to another trigger, don't clear; the enter handler will set it.
      const related = e.relatedTarget;
      if (related && this._closestTrigger(related)) return;

      // If focus is currently within a trigger, keep it active.
      const activeTrigger = this._closestTrigger(document.activeElement);
      if (activeTrigger) {
        const key = activeTrigger.getAttribute("data-interface-highlight-trigger");
        if (key) this.el.dataset.interfaceHighlightActive = key;
        return;
      }

      delete this.el.dataset.interfaceHighlightActive;
    };

    this._onFocusIn = (e) => this._onTriggerEnter(e);
    this._onFocusOut = (e) => this._onTriggerLeave(e);

    // Delegate events from the hook root.
    this.el.addEventListener("mouseenter", this._onTriggerEnter, true);
    this.el.addEventListener("mouseover", this._onTriggerEnter, true);
    this.el.addEventListener("mouseleave", this._onTriggerLeave, true);
    this.el.addEventListener("mouseout", this._onTriggerLeave, true);

    this.el.addEventListener("focusin", this._onFocusIn, true);
    this.el.addEventListener("focusout", this._onFocusOut, true);

    // Optional: if markup provides a default active key.
    const initial = this.el.getAttribute("data-interface-highlight-initial");
    if (initial) this.el.dataset.interfaceHighlightActive = initial;
  },

  destroyed() {
    this.el.removeEventListener("mouseenter", this._onTriggerEnter, true);
    this.el.removeEventListener("mouseover", this._onTriggerEnter, true);
    this.el.removeEventListener("mouseleave", this._onTriggerLeave, true);
    this.el.removeEventListener("mouseout", this._onTriggerLeave, true);

    this.el.removeEventListener("focusin", this._onFocusIn, true);
    this.el.removeEventListener("focusout", this._onFocusOut, true);
  },

  _closestTrigger(node) {
    if (!node) return null;
    // `Element.closest` is safe-guarded since `node` might be a Text node.
    const el = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    if (!el || !el.closest) return null;
    return el.closest("[data-interface-highlight-trigger]");
  },
};

export default InterfaceHighlightHook;
