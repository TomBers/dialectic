/**
 * SearchNav hook – manages ArrowUp / ArrowDown keyboard navigation
 * inside the quick-search results list.
 *
 * Attach to the search panel container element:
 *
 *     <div id="quick-search-panel" phx-hook="SearchNav">
 *
 * The hook listens for keydown events on the **document** in the
 * **capture phase** so it intercepts arrow keys before the graph's
 * own keydown handler (registered on document in the bubble phase
 * by draw_graph.js) can navigate graph nodes.  When an arrow key
 * is handled here we call `stopImmediatePropagation()` to prevent
 * any other listeners at the same level from firing.
 */
import { containModalFocus } from "./modal_focus.js";

let cancelPendingResultFocus = () => {};

const SearchNav = {
  mounted() {
    cancelPendingResultFocus();
    this.opener = !this.el.contains(document.activeElement) && document.activeElement?.matches('a[href], button, input, select, textarea, [tabindex]')
      ? document.activeElement : null;
    this.modal = !!this.el.querySelector('[aria-modal="true"]');
    this.modalFocus = this.modal ? containModalFocus(this.el) : null;
    this.focusInput = () => {
      if (this.el.contains(document.activeElement)) return;
      cancelAnimationFrame(this.focusFrame);
      this.focusFrame = requestAnimationFrame(() => {
        if (!this.el.isConnected) return;
        this.el.querySelector('input[type="text"], input:not([type]), textarea')?.focus({ preventScroll: true });
      });
    };
    this._onResultClick = (event) => {
      const result = event.target.closest('button[phx-click="search_result_clicked"]');
      if (result && this.el.dataset.focusResultPrefix) {
        this.resultId = this.el.dataset.focusResultPrefix + result.getAttribute("phx-value-id");
      }
    };
    this._onKeydown = (event) => {
      if (!this.el.contains(document.activeElement)) return;
      if (!["ArrowDown", "ArrowUp", "Enter"].includes(event.key)) return;
      const buttons = Array.from(this.el.querySelectorAll("ul button[phx-click]"));
      if (buttons.length === 0) return;
      const index = buttons.indexOf(document.activeElement);
      if (event.key === "Enter") {
        if (index < 0) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        buttons[index].click();
      } else {
        event.preventDefault();
        event.stopImmediatePropagation();
        const next = event.key === "ArrowDown"
          ? (index + 1) % buttons.length
          : (index <= 0 ? buttons.length - 1 : index - 1);
        buttons[next].focus();
      }
    };
    this.el.addEventListener("click", this._onResultClick, true);
    document.addEventListener("keydown", this._onKeydown, true);
    this.focusInput();
  },

  updated() {
    this.modalFocus?.refresh();
    this.focusInput();
  },

  destroyed() {
    cancelAnimationFrame(this.focusFrame);
    this.el.removeEventListener("click", this._onResultClick, true);
    document.removeEventListener("keydown", this._onKeydown, true);
    this.modalFocus?.destroy();
    const opener = this.opener;
    const fallbackId = this.el.dataset.returnFocusId;
    const resultId = this.resultId;
    requestAnimationFrame(() => requestAnimationFrame(() => {
      const fallback = () => {
        const target = opener?.isConnected ? opener : document.getElementById(fallbackId);
        target?.focus({ preventScroll: true });
      };
      if (!resultId) {
        fallback();
        return;
      }
      const focusResult = () => {
        const result = document.getElementById(resultId);
        if (!result) return false;
        result.focus();
        return true;
      };
      if (focusResult()) return;
      const observer = new MutationObserver(() => {
        if (focusResult()) cancelPendingResultFocus();
      });
      const timeout = setTimeout(() => {
        cancelPendingResultFocus();
        fallback();
      }, 2000);
      cancelPendingResultFocus = () => {
        observer.disconnect();
        clearTimeout(timeout);
        cancelPendingResultFocus = () => {};
      };
      observer.observe(document.body, {childList: true, subtree: true});
    }));
  },
};

export default SearchNav;
