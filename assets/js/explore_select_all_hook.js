/Users/tomberman/Development/dialectic/assets/js/explore_select_all_hook.js
/**
 * ExploreSelectAll LiveView Hook
 *
 * Usage:
 * - Attach phx-hook="ExploreSelectAll" to any container that includes:
 *   - A "Select all" checkbox with id="explore-select-all"
 *   - A list of item checkboxes matching: input[type="checkbox"][name^="items["]
 *
 * Behavior:
 * - Keeps the "Select all" checkbox in sync with the individual item checkboxes.
 * - Toggles all item checkboxes when "Select all" is changed.
 * - Handles LiveView patches (updated) and cleans up listeners on destroy.
 */

const QUERY_SELECT_ALL = "#explore-select-all";
const QUERY_ITEM_BOXES = 'input[type="checkbox"][name^="items["]';

const exploreSelectAllHook = {
  mounted() {
    this._init();
  },

  updated() {
    // DOM may have changed; re-bind listeners
    this._teardown();
    this._init();
  },

  destroyed() {
    this._teardown();
  },

  // Internal helpers

  _init() {
    this._handlers = [];
    this._selectAll = this.el.querySelector(QUERY_SELECT_ALL);
    this._itemBoxes = Array.from(this.el.querySelectorAll(QUERY_ITEM_BOXES));

    // Nothing to do if we don't have any of the expected elements
    if (!this._selectAll && this._itemBoxes.length === 0) return;

    // Bind events
    this._bind();

    // Initial sync
    this._syncSelectAll();
  },

  _bind() {
    // Sync function needs stable reference for event listeners
    this._syncSelectAll = () => {
      const total = this._itemBoxes.length;
      const checkedCount = this._itemBoxes.reduce(
        (acc, cb) => acc + (cb.checked ? 1 : 0),
        0,
      );

      if (this._selectAll) {
        // Set checked when all items are checked
        this._selectAll.checked = total > 0 && checkedCount === total;
        // Set indeterminate when some but not all are checked
        this._selectAll.indeterminate =
          checkedCount > 0 && checkedCount < total;
      }
    };

    if (this._selectAll) {
      const onSelectAllChange = () => {
        const shouldCheck = this._selectAll.checked;
        this._itemBoxes.forEach((cb) => {
          cb.checked = shouldCheck;
        });
        this._syncSelectAll();
      };
      this._addHandler(this._selectAll, "change", onSelectAllChange);
    }

    this._itemBoxes.forEach((cb) => {
      this._addHandler(cb, "change", this._syncSelectAll);
    });
  },

  _addHandler(el, evt, handler) {
    el.addEventListener(evt, handler);
    this._handlers.push({ el, evt, handler });
  },

  _teardown() {
    if (this._handlers) {
      this._handlers.forEach(({ el, evt, handler }) => {
        el.removeEventListener(evt, handler);
      });
    }
    this._handlers = [];
    this._selectAll = null;
    this._itemBoxes = [];
    this._syncSelectAll = () => {};
  },
};

export default exploreSelectAllHook;
