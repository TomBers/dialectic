export default {
  mounted() {
    this.trigger = this.el.querySelector('[popovertarget]');
    this.panel = this.el.querySelector('[popover]');
    this.position = () => {
      if (!this.panel.matches(':popover-open')) return;
      const rect = this.trigger.getBoundingClientRect();
      const viewport = window.visualViewport;
      const leftEdge = viewport?.offsetLeft || 0;
      const topEdge = viewport?.offsetTop || 0;
      const width = viewport?.width || window.innerWidth;
      const height = viewport?.height || window.innerHeight;
      const panelWidth = Math.min(320, width - 16);
      const below = topEdge + height - rect.bottom - 16;
      const above = rect.top - topEdge - 16;
      const upwards = below < 240 && above > below;
      this.panel.style.width = `${panelWidth}px`;
      this.panel.style.left = `${Math.max(leftEdge + 8, Math.min(rect.right - panelWidth, leftEdge + width - panelWidth - 8))}px`;
      this.panel.style.maxHeight = `${Math.max(80, upwards ? above : below)}px`;
      this.panel.style.top = upwards ? 'auto' : `${rect.bottom + 8}px`;
      this.panel.style.bottom = upwards ? `${window.innerHeight - rect.top + 8}px` : 'auto';
    };
    this.toggle = (event) => {
      const open = event.newState === 'open';
      this.trigger.setAttribute('aria-expanded', String(open));
      if (open) {
        this.position();
        const selected = this.panel.querySelector('[aria-pressed="true"]') || this.panel.querySelector('button') || this.panel;
        selected?.focus({preventScroll: true});
      }
    };
    this.click = (event) => {
      if (!(event.target instanceof Element) || !event.target.closest('[data-dropdown-choice]')) return;
      this.panel.hidePopover();
      this.trigger.focus({preventScroll: true});
    };
    this.keydown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        this.panel.hidePopover();
        this.trigger.focus({preventScroll: true});
        return;
      }
      if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return;
      const buttons = Array.from(this.panel.querySelectorAll('button:not(:disabled)'));
      const index = buttons.indexOf(document.activeElement);
      const next = event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length - 1 :
        (index + (event.key === 'ArrowDown' ? 1 : -1) + buttons.length) % buttons.length;
      event.preventDefault();
      event.stopPropagation();
      buttons[next]?.focus({preventScroll: true});
    };
    this.panel.addEventListener('toggle', this.toggle);
    this.panel.addEventListener('click', this.click);
    this.panel.addEventListener('keydown', this.keydown);
    window.addEventListener('resize', this.position);
    window.visualViewport?.addEventListener('resize', this.position);
    document.addEventListener('scroll', this.position, true);
  },
  updated() {
    this.trigger.setAttribute('aria-expanded', String(this.panel.matches(':popover-open')));
    this.position();
  },
  destroyed() {
    this.panel.removeEventListener('toggle', this.toggle);
    this.panel.removeEventListener('click', this.click);
    this.panel.removeEventListener('keydown', this.keydown);
    window.removeEventListener('resize', this.position);
    window.visualViewport?.removeEventListener('resize', this.position);
    document.removeEventListener('scroll', this.position, true);
  },
};
