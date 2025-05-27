const storyReadabilityHook = {
  mounted() {
    this.initializeReadabilityControls();
  },

  updated() {
    this.initializeReadabilityControls();
  },

  initializeReadabilityControls() {
    // DOM elements
    this.bionicToggle = this.el.querySelector("#toggle-bionic");
    this.focusToggle = this.el.querySelector("#toggle-focus");
    this.darkModeToggle = this.el.querySelector("#toggle-dark");
    this.increaseFontBtn = this.el.querySelector("#increase-font");
    this.decreaseFontBtn = this.el.querySelector("#decrease-font");
    this.resetFontBtn = this.el.querySelector("#reset-font");

    if (!this.bionicToggle) return;

    // State
    this.bionicActive = false;
    this.focusActive = false;
    this.darkMode = false;
    this.fontSize = 18;

    // Remove existing listeners to prevent duplicates
    this.removeEventListeners();

    // Bind event handlers
    this.handleBionicToggle = this.handleBionicToggle.bind(this);
    this.handleFocusToggle = this.handleFocusToggle.bind(this);
    this.handleDarkModeToggle = this.handleDarkModeToggle.bind(this);
    this.handleIncreaseFontSize = this.handleIncreaseFontSize.bind(this);
    this.handleDecreaseFontSize = this.handleDecreaseFontSize.bind(this);
    this.handleResetFontSize = this.handleResetFontSize.bind(this);
    this.updateFocusOnScroll = this.updateFocusOnScroll.bind(this);

    // Add event listeners
    this.bionicToggle.addEventListener("click", this.handleBionicToggle);
    this.focusToggle.addEventListener("click", this.handleFocusToggle);
    this.darkModeToggle.addEventListener("click", this.handleDarkModeToggle);
    this.increaseFontBtn.addEventListener("click", this.handleIncreaseFontSize);
    this.decreaseFontBtn.addEventListener("click", this.handleDecreaseFontSize);
    this.resetFontBtn.addEventListener("click", this.handleResetFontSize);

    window.addEventListener("scroll", this.updateFocusOnScroll, { passive: true });
  },

  destroyed() {
    this.removeEventListeners();
  },

  removeEventListeners() {
    if (this.bionicToggle) {
      this.bionicToggle.removeEventListener("click", this.handleBionicToggle);
    }
    if (this.focusToggle) {
      this.focusToggle.removeEventListener("click", this.handleFocusToggle);
    }
    if (this.darkModeToggle) {
      this.darkModeToggle.removeEventListener("click", this.handleDarkModeToggle);
    }
    if (this.increaseFontBtn) {
      this.increaseFontBtn.removeEventListener("click", this.handleIncreaseFontSize);
    }
    if (this.decreaseFontBtn) {
      this.decreaseFontBtn.removeEventListener("click", this.handleDecreaseFontSize);
    }
    if (this.resetFontBtn) {
      this.resetFontBtn.removeEventListener("click", this.handleResetFontSize);
    }
    window.removeEventListener("scroll", this.updateFocusOnScroll);
  },

  bionicizeText(text) {
    return text.replace(/\b(\w+)\b/g, (match) => {
      const len = match.length;
      if (len <= 3) {
        return `<b style='font-weight:800'>${match.substring(0, 1)}</b>${match.substring(1)}`;
      } else if (len <= 6) {
        const boldPart = Math.ceil(len * 0.5);
        return `<b style='font-weight:800'>${match.substring(0, boldPart)}</b>${match.substring(boldPart)}`;
      } else {
        const boldPart = Math.ceil(len * 0.33);
        return `<b style='font-weight:800'>${match.substring(0, boldPart)}</b>${match.substring(boldPart)}`;
      }
    });
  },

  handleBionicToggle() {
    this.bionicActive = !this.bionicActive;
    this.bionicToggle.classList.toggle("active", this.bionicActive);
    
    this.el.querySelectorAll('.bubble .bionic').forEach(p => {
      if (this.bionicActive) {
        p.innerHTML = this.bionicizeText(p.textContent);
      } else {
        p.innerHTML = p.textContent;
      }
    });
  },

  handleFocusToggle() {
    this.focusActive = !this.focusActive;
    this.focusToggle.classList.toggle("active", this.focusActive);
    
    this.el.querySelectorAll('.bubble').forEach(bubble => {
      bubble.classList.toggle("focus-fade", this.focusActive);
      if (this.focusActive) {
        const firstP = bubble.querySelector("p");
        if (firstP) firstP.classList.add("focus-current");
      } else {
        bubble.querySelectorAll("p").forEach(p => p.classList.remove("focus-current"));
      }
    });

    if (this.focusActive) {
      this.updateFocusOnScroll();
    }
  },

  handleDarkModeToggle() {
    this.darkMode = !this.darkMode;
    this.darkModeToggle.classList.toggle("active", this.darkMode);
    document.body.classList.toggle("dark-mode", this.darkMode);
  },

  handleIncreaseFontSize() {
    this.updateFontSize(this.fontSize + 2);
  },

  handleDecreaseFontSize() {
    if (this.fontSize > 8) {
      this.updateFontSize(this.fontSize - 2);
    }
  },

  handleResetFontSize() {
    this.updateFontSize(18);
  },

  updateFontSize(size) {
    this.fontSize = size;
    document.documentElement.style.setProperty('--font-size-base', `${size}px`);
  },

  updateFocusOnScroll() {
    if (!this.focusActive) return;
    
    const allParagraphs = Array.from(this.el.querySelectorAll('.bubble p'));
    const winCenter = window.innerHeight / 2;
    let closest = null;
    let minDistance = Infinity;

    allParagraphs.forEach(p => {
      const rect = p.getBoundingClientRect();
      const pCenter = (rect.top + rect.bottom) / 2;
      const distance = Math.abs(pCenter - winCenter);
      
      if (distance < minDistance && rect.top < window.innerHeight && rect.bottom > 0) {
        minDistance = distance;
        closest = p;
      }
    });

    allParagraphs.forEach(p => {
      p.classList.toggle("focus-current", p === closest);
    });
  }
};

export default storyReadabilityHook;