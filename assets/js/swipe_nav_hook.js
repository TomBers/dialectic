/**
 * SwipeNav Hook - Handles swipe gestures for branch navigation on mobile
 *
 * Attach to a container element. Detects horizontal swipes and pushes
 * a "swipe_navigate" event to the LiveView with the direction.
 *
 * Also provides haptic feedback on supported devices.
 */
const SwipeNav = {
  mounted() {
    this.startX = null;
    this.startY = null;
    this.startTime = null;
    this.swiping = false;

    // Minimum distance (px) for a swipe to register
    this.minSwipeDistance = 80;
    // Maximum vertical deviation allowed
    this.maxVerticalDeviation = 100;
    // Maximum time (ms) for a swipe gesture
    this.maxSwipeTime = 500;

    this.indicator = null;

    // Target the scroll container rather than this (hidden) element
    this.target = document.getElementById("linear-scroller");
    if (!this.target) return;

    this.handleTouchStart = (e) => {
      // Don't interfere with scrolling in text areas or inputs
      const tag = e.target.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

      this.startX = e.touches[0].clientX;
      this.startY = e.touches[0].clientY;
      this.startTime = Date.now();
      this.swiping = false;
    };

    this.handleTouchMove = (e) => {
      if (this.startX === null) return;

      const currentX = e.touches[0].clientX;
      const currentY = e.touches[0].clientY;
      const diffX = currentX - this.startX;
      const diffY = Math.abs(currentY - this.startY);

      // If vertical movement is dominant, this is a scroll, not a swipe
      if (diffY > Math.abs(diffX) * 1.5) {
        this.startX = null;
        this.removeIndicator();
        return;
      }

      // Show visual indicator once we're clearly swiping horizontally
      if (Math.abs(diffX) > 30 && diffY < this.maxVerticalDeviation) {
        this.swiping = true;
        this.showSwipeIndicator(
          diffX > 0 ? "left" : "right",
          Math.min(Math.abs(diffX) / this.minSwipeDistance, 1),
        );
      }
    };

    this.handleTouchEnd = (e) => {
      if (this.startX === null) return;

      const endX = e.changedTouches[0].clientX;
      const endY = e.changedTouches[0].clientY;
      const diffX = endX - this.startX;
      const diffY = Math.abs(endY - this.startY);
      const elapsed = Date.now() - this.startTime;

      this.removeIndicator();

      if (
        Math.abs(diffX) >= this.minSwipeDistance &&
        diffY < this.maxVerticalDeviation &&
        elapsed < this.maxSwipeTime
      ) {
        const direction = diffX > 0 ? "left" : "right"; // Swipe right = go to previous (left), swipe left = go to next (right)

        // Haptic feedback
        this.triggerHaptic();

        this.pushEvent("swipe_navigate", { direction: direction });
      }

      this.startX = null;
      this.startY = null;
      this.startTime = null;
      this.swiping = false;
    };

    this.target.addEventListener("touchstart", this.handleTouchStart, {
      passive: true,
    });
    this.target.addEventListener("touchmove", this.handleTouchMove, {
      passive: true,
    });
    this.target.addEventListener("touchend", this.handleTouchEnd, {
      passive: true,
    });
  },

  destroyed() {
    if (this.target) {
      this.target.removeEventListener("touchstart", this.handleTouchStart);
      this.target.removeEventListener("touchmove", this.handleTouchMove);
      this.target.removeEventListener("touchend", this.handleTouchEnd);
    }
    this.removeIndicator();
  },

  triggerHaptic() {
    // Use the Vibration API if available
    if (navigator.vibrate) {
      navigator.vibrate(10);
    }
  },

  showSwipeIndicator(direction, progress) {
    if (!this.indicator) {
      this.indicator = document.createElement("div");
      this.indicator.className = "swipe-indicator";
      this.indicator.innerHTML = `
        <div class="swipe-indicator-inner">
          <svg class="swipe-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="${direction === "left" ? "M15 19l-7-7 7-7" : "M9 5l7 7-7 7"}" />
          </svg>
        </div>
      `;
      document.body.appendChild(this.indicator);
    }

    const opacity = Math.min(progress * 0.9, 0.9);
    const scale = 0.5 + progress * 0.5;
    this.indicator.style.cssText = `
      position: fixed;
      top: 50%;
      ${direction === "left" ? "left: 20px; right: auto;" : "right: 20px; left: auto;"}
      transform: translateY(-50%) scale(${scale});
      z-index: 9999;
      pointer-events: none;
      opacity: ${opacity};
      transition: opacity 0.1s;
    `;

    const inner = this.indicator.querySelector(".swipe-indicator-inner");
    if (inner) {
      inner.style.cssText = `
        width: 48px;
        height: 48px;
        border-radius: 50%;
        background: rgba(99, 102, 241, 0.9);
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
      `;
    }

    const arrow = this.indicator.querySelector(".swipe-arrow");
    if (arrow) {
      arrow.style.cssText = `
        width: 24px;
        height: 24px;
        color: white;
      `;
    }
  },

  removeIndicator() {
    if (this.indicator) {
      this.indicator.remove();
      this.indicator = null;
    }
  },
};

export default SwipeNav;
