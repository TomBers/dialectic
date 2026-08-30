import { afterEach, beforeEach, describe, expect, it } from "vitest";
import ProofCarouselHook from "../proof_carousel_hook.js";

let hook;

beforeEach(() => {
  document.body.innerHTML = `
    <section id="proof">
      <button data-carousel-previous>Previous</button>
      <button data-carousel-next>Next</button>
      <article id="case-study" data-carousel-slide>Case study</article>
      <article id="testimonial" data-carousel-slide hidden>Testimonial</article>
      <button data-carousel-indicator="0" class="bg-teal-700">Case study</button>
      <button data-carousel-indicator="1" class="bg-stone-300">Testimonial</button>
      <span data-carousel-status></span>
    </section>
  `;

  hook = Object.create(ProofCarouselHook);
  hook.el = document.querySelector("#proof");
  hook.mounted();
});

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
});

describe("ProofCarouselHook", () => {
  it("moves between slides and updates its accessible state", () => {
    hook.nextButton.click();

    expect(document.querySelector("#case-study").hidden).toBe(true);
    expect(document.querySelector("#case-study").classList.contains("hidden")).toBe(true);
    expect(document.querySelector("#testimonial").hidden).toBe(false);
    expect(document.querySelector("#testimonial").classList.contains("hidden")).toBe(false);
    expect(document.querySelector("#testimonial").getAttribute("aria-hidden")).toBe("false");
    expect(hook.indicators[1].getAttribute("aria-current")).toBe("true");
    expect(hook.status.textContent).toBe("2 of 2");

    hook.previousButton.click();

    expect(document.querySelector("#case-study").hidden).toBe(false);
    expect(document.querySelector("#testimonial").hidden).toBe(true);
    expect(hook.status.textContent).toBe("1 of 2");
  });

  it("wraps from the first slide to the last", () => {
    hook.previousButton.click();

    expect(document.querySelector("#testimonial").hidden).toBe(false);
    expect(hook.status.textContent).toBe("2 of 2");
  });
});
