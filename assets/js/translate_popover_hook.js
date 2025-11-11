/* dialectic/assets/js/translate_popover_hook.js
Add TranslatePopover JS hook that portals the dropdown to body and positions it as a fixed popover.
*/

const MARGIN = 8;
const Z_INDEX = 10050;

function clamp(v, min, max) {
  return Math.min(Math.max(v, min), max);
}

function getPanelCandidate(root) {
  // Try likely selector candidates, in order
  const candidates = [
    '[data-role="panel"]',
    '[data-popover-panel]',
    '.translate-popover-panel',
    '.translate-menu',
  ];
  for (const sel of candidates) {
    const el = root.querySelector(sel);
    if (el) return el;
  }

  // Fallback: the first direct child that looks like a menu container
  const maybe = Array.from(root.children).find((c) => {
    const tag = (c.tagName || '').toLowerCase();
    if (tag === 'template') return false;
    const hasLinks = c.querySelector && c.querySelector('a, button, [role="menuitem"]');
    const hasMenuRole = c.getAttribute && c.getAttribute('role') === 'menu';
    const isHidden =
      (c.style && (c.style.display === 'none' || c.style.visibility === 'hidden')) ||
      c.hasAttribute('hidden');
    return (hasLinks || hasMenuRole) && !isHidden;
  });
  return maybe || null;
}

function getTriggerCandidate(root) {
  // Preferred explicit trigger
  let trigger = root.querySelector('[data-role="trigger"]');
  if (trigger) return trigger;

  // Otherwise, first button inside
  trigger = root.querySelector('button');
  if (trigger) return trigger;

  // Fallback to the root element itself (clickable container)
  return root;
}

function computePosition(triggerRect, panelWidth, panelHeight, align) {
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  // Preferred below
  const preferBelow = triggerRect.bottom + MARGIN + panelHeight <= vh;

  // Horizontal alignment: center by default, clamp to viewport
  let left;
  if (align === 'left') {
    left = triggerRect.left;
  } else if (align === 'right') {
    left = triggerRect.right - panelWidth;
  } else {
    // center
    left = triggerRect.left + triggerRect.width / 2 - panelWidth / 2;
  }
  left = clamp(left, MARGIN, vw - panelWidth - MARGIN);

  let top;
  if (preferBelow) {
    top = triggerRect.bottom + MARGIN;
  } else {
    top = triggerRect.top - panelHeight - MARGIN;
    // If still out of view, clamp
    if (top < MARGIN) {
      top = clamp(triggerRect.top + triggerRect.height + MARGIN, MARGIN, vh - panelHeight - MARGIN);
    }
  }

  return { top, left };
}

const translatePopoverHook = {
  mounted() {
    // State
    this._open = false;
    this._container = null;
    this._panel = null;
    this._originalParent = null;
    this._originalNextSibling = null;
    this._storedPanelStyle = null;

    // Elements
    this._trigger = getTriggerCandidate(this.el);
    this._panel = getPanelCandidate(this.el);

    if (!this._trigger || !this._panel) {
      // Gracefully no-op if we can't find what we need
      // eslint-disable-next-line no-console
      console.warn('[TranslatePopover] Missing trigger or panel element. Hook inert.');
      return;
    }

    // Store references to restore later
    this._originalParent = this._panel.parentNode;
    this._originalNextSibling = this._panel.nextSibling;
    this._storedPanelStyle = this._panel.getAttribute('style');

    // Ensure panel visible semantics are controlled by us
    this._panel.removeAttribute('hidden');
    this._panel.style.display = '';

    // Create a fixed-position portal container in body
    this._container = document.createElement('div');
    this._container.className = 'translate-popover-portal';
    Object.assign(this._container.style, {
      position: 'fixed',
      top: '-9999px',
      left: '-9999px',
      zIndex: String(Z_INDEX),
      display: 'none', // hidden by default
    });

    // Move panel into container
    this._container.appendChild(this._panel);
    document.body.appendChild(this._container);

    // Bindings
    this._onTriggerClick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.toggle();
    };

    this._onDocPointerDown = (e) => {
      if (!this._open) return;
      const t = e.target;
      if (!t) return;
      const clickInsidePanel = this._container.contains(t);
      const clickOnTrigger = this._trigger.contains(t);
      if (!clickInsidePanel && !clickOnTrigger) {
        this.close();
      }
    };

    this._onKeyDown = (e) => {
      if (!this._open) return;
      if (e.key === 'Escape') {
        e.preventDefault();
        this.close();
        // Return focus to trigger for accessibility
        if (this._trigger && this._trigger.focus) {
          this._trigger.focus();
        }
      }
    };

    this._onScrollOrResize = () => {
      if (!this._open) return;
      this.position();
    };

    this._ro = new ResizeObserver(() => {
      if (!this._open) return;
      this.position();
    });

    this._trigger.addEventListener('click', this._onTriggerClick);
    document.addEventListener('mousedown', this._onDocPointerDown, true);
    document.addEventListener('touchstart', this._onDocPointerDown, true);
    document.addEventListener('keydown', this._onKeyDown, true);
    window.addEventListener('scroll', this._onScrollOrResize, true);
    window.addEventListener('resize', this._onScrollOrResize, true);
    this._ro.observe(this._panel);
    this._ro.observe(this._trigger);
  },

  updated() {
    // The LV patch may re-render the trigger container; keep positioning fresh when open
    if (this._open) {
      this.position();
    }
  },

  destroyed() {
    try {
      if (this._trigger && this._onTriggerClick) {
        this._trigger.removeEventListener('click', this._onTriggerClick);
      }
      document.removeEventListener('mousedown', this._onDocPointerDown, true);
      document.removeEventListener('touchstart', this._onDocPointerDown, true);
      document.removeEventListener('keydown', this._onKeyDown, true);
      window.removeEventListener('scroll', this._onScrollOrResize, true);
      window.removeEventListener('resize', this._onScrollOrResize, true);
      if (this._ro) {
        try {
          this._ro.disconnect();
        } catch (_e) {}
      }

      // Restore panel to original parent if possible
      if (this._panel) {
        if (this._storedPanelStyle == null) {
          this._panel.removeAttribute('style');
        } else {
          this._panel.setAttribute('style', this._storedPanelStyle);
        }

        if (this._originalParent && this._originalParent.isConnected) {
          if (this._originalNextSibling && this._originalNextSibling.parentNode === this._originalParent) {
            this._originalParent.insertBefore(this._panel, this._originalNextSibling);
          } else {
            this._originalParent.appendChild(this._panel);
          }
        } else if (this._panel.parentNode) {
          // If original parent is gone, at least detach from container
          this._panel.parentNode.removeChild(this._panel);
        }
      }

      if (this._container && this._container.parentNode) {
        this._container.parentNode.removeChild(this._container);
      }
    } catch (_e) {
      // swallow cleanup exceptions
    }
  },

  open() {
    if (!this._container || !this._panel || !this._trigger) return;
    this._open = true;
    this._container.style.display = 'block';
    this.position();

    // Manage aria-expanded
    this._trigger.setAttribute('aria-expanded', 'true');

    // Focus first interactive element for accessibility
    const focusable = this._panel.querySelector('a, button, [tabindex]:not([tabindex="-1"])');
    if (focusable && focusable.focus) {
      // Small delay to ensure layout is applied before focusing
      requestAnimationFrame(() => focusable.focus());
    }
  },

  close() {
    if (!this._container || !this._panel || !this._trigger) return;
    this._open = false;
    this._container.style.display = 'none';

    // Manage aria-expanded
    this._trigger.setAttribute('aria-expanded', 'false');
  },

  toggle() {
    if (this._open) this.close();
    else this.open();
  },

  position() {
    if (!this._container || !this._panel || !this._trigger) return;
    // Compute preferred alignment from data attribute
    const align = this.el.getAttribute('data-popover-align') || 'center';

    const rect = this._trigger.getBoundingClientRect();
    const panelRect = this._panel.getBoundingClientRect();

    // If width is 0 because it's hidden or not measured, temporarily force display to measure
    let panelWidth = panelRect.width;
    let panelHeight = panelRect.height;

    if (panelWidth === 0 || panelHeight === 0) {
      // Temporarily show invisibly for measurement
      const prevDisplay = this._container.style.display;
      const prevVisibility = this._container.style.visibility;
      this._container.style.display = 'block';
      this._container.style.visibility = 'hidden';

      const r = this._panel.getBoundingClientRect();
      panelWidth = r.width;
      panelHeight = r.height;

      this._container.style.visibility = prevVisibility || '';
      this._container.style.display = prevDisplay || 'none';
    }

    const { top, left } = computePosition(rect, panelWidth, panelHeight, align);

    Object.assign(this._container.style, {
      top: `${top}px`,
      left: `${left}px`,
    });
  },
};

export default translatePopoverHook;
