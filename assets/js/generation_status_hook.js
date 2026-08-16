const DETAIL_DELAY_MS = 3000;
const FINISHING_DELAY_MS = 8000;

const detailMessage = (responseLevel) => {
  switch (responseLevel) {
    case "expert":
      return "Comparing evidence and perspectives";
    case "university":
      return "Checking relevant sources";
    default:
      return "Writing a clear response";
  }
};

const GenerationStatusHook = {
  mounted() {
    this.startStatusSequence();
  },

  updated() {
    const responseLevel = this.el.dataset.responseLevel || "";
    if (responseLevel !== this.responseLevel) {
      this.startStatusSequence();
    }
  },

  destroyed() {
    this.clearStatusTimers();
  },

  startStatusSequence() {
    this.clearStatusTimers();
    this.responseLevel = this.el.dataset.responseLevel || "";
    this.statusElement = this.el.querySelector("[data-generation-status]");
    if (!this.statusElement) return;

    this.statusElement.textContent = "Preparing response";
    this.statusTimers = [
      window.setTimeout(() => {
        this.statusElement.textContent = detailMessage(this.responseLevel);
      }, DETAIL_DELAY_MS),
      window.setTimeout(() => {
        this.statusElement.textContent = "Finishing response";
      }, FINISHING_DELAY_MS),
    ];
  },

  clearStatusTimers() {
    for (const timer of this.statusTimers || []) {
      window.clearTimeout(timer);
    }
    this.statusTimers = [];
  },
};

export { DETAIL_DELAY_MS, FINISHING_DELAY_MS };
export default GenerationStatusHook;
