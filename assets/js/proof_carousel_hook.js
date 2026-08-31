const ProofCarouselHook = {
  mounted() {
    this.slides = Array.from(this.el.querySelectorAll("[data-carousel-slide]"));
    this.indicators = Array.from(
      this.el.querySelectorAll("[data-carousel-indicator]"),
    );
    this.status = this.el.querySelector("[data-carousel-status]");
    this.activeIndex = 0;

    this.showPrevious = () => this.show(this.activeIndex - 1);
    this.showNext = () => this.show(this.activeIndex + 1);
    this.showIndicator = (event) => {
      this.show(Number(event.currentTarget.dataset.carouselIndicator));
    };

    this.previousButton = this.el.querySelector("[data-carousel-previous]");
    this.nextButton = this.el.querySelector("[data-carousel-next]");
    this.previousButton?.addEventListener("click", this.showPrevious);
    this.nextButton?.addEventListener("click", this.showNext);
    this.indicators.forEach((indicator) =>
      indicator.addEventListener("click", this.showIndicator),
    );
    this.show(0);
  },

  destroyed() {
    this.previousButton?.removeEventListener("click", this.showPrevious);
    this.nextButton?.removeEventListener("click", this.showNext);
    this.indicators.forEach((indicator) =>
      indicator.removeEventListener("click", this.showIndicator),
    );
  },

  show(index) {
    if (this.slides.length === 0) return;

    this.activeIndex = (index + this.slides.length) % this.slides.length;
    this.slides.forEach((slide, slideIndex) => {
      const active = slideIndex === this.activeIndex;
      slide.hidden = !active;
      slide.classList.toggle("hidden", !active);
      slide.setAttribute("aria-hidden", String(!active));
    });
    this.indicators.forEach((indicator, indicatorIndex) => {
      const active = indicatorIndex === this.activeIndex;
      indicator.setAttribute("aria-current", String(active));
      indicator.classList.toggle("bg-teal-700", active);
      indicator.classList.toggle("bg-stone-300", !active);
    });
    if (this.status) {
      this.status.textContent = `${this.activeIndex + 1} of ${this.slides.length}`;
    }
  },
};

export default ProofCarouselHook;
