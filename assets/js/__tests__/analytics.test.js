import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  initAnalyticsEventTracking,
  initDelayedAnalytics,
  loadGoogleAnalytics,
} from "../analytics.js";

const analyticsScripts = () =>
  document.querySelectorAll("script[data-google-analytics]");

let cleanups;

beforeEach(() => {
  vi.useFakeTimers();
  cleanups = [];
  delete window.gtag;
  delete window.dataLayer;
  document.head
    .querySelectorAll("script[data-google-analytics]")
    .forEach((script) => script.remove());
});

afterEach(() => {
  cleanups.forEach((cleanup) => cleanup());
  cleanups = [];
  delete window.gtag;
  delete window.dataLayer;
  document.head
    .querySelectorAll("script[data-google-analytics]")
    .forEach((script) => script.remove());
  vi.useRealTimers();
});

describe("delayed Google Analytics", () => {
  it("loads on the first meaningful interaction", () => {
    cleanups.push(initDelayedAnalytics());

    window.dispatchEvent(new Event("pointerdown"));

    expect(analyticsScripts()).toHaveLength(1);
    expect(analyticsScripts()[0].src).toContain(
      "googletagmanager.com/gtag/js?id=G-NZDE9PL5FG",
    );
    expect(window.dataLayer).toHaveLength(2);
  });

  it("loads five seconds after window load when there is no interaction", () => {
    cleanups.push(initDelayedAnalytics());
    window.dispatchEvent(new Event("load"));

    vi.advanceTimersByTime(4999);
    expect(analyticsScripts()).toHaveLength(0);

    vi.advanceTimersByTime(1);
    expect(analyticsScripts()).toHaveLength(1);
  });

  it("deduplicates direct and independently scheduled load attempts", () => {
    cleanups.push(initDelayedAnalytics(), initDelayedAnalytics());

    window.dispatchEvent(new Event("keydown"));
    loadGoogleAnalytics();
    vi.advanceTimersByTime(5000);

    expect(analyticsScripts()).toHaveLength(1);
    expect(window.dataLayer).toHaveLength(2);
  });

  it("cancels interaction listeners and the fallback timer during cleanup", () => {
    const cleanup = initDelayedAnalytics();
    cleanup();

    window.dispatchEvent(new Event("scroll"));
    window.dispatchEvent(new Event("load"));
    vi.advanceTimersByTime(5000);

    expect(analyticsScripts()).toHaveLength(0);
  });
});

describe("conversion event tracking", () => {
  it("tracks named actions with their page location", () => {
    document.body.innerHTML = `
      <a data-analytics-event="sign_up_cta_clicked" data-analytics-location="home_hero">
        Sign up
      </a>
    `;
    cleanups.push(initAnalyticsEventTracking());

    document.querySelector("a").click();

    expect(window.dataLayer.at(-1)).toEqual([
      "event",
      "sign_up_cta_clicked",
      { event_location: "home_hero" },
    ]);
  });

  it("tracks forms submitted without a click", () => {
    document.body.innerHTML = `
      <form data-analytics-event="registration_form_submitted"></form>
    `;
    cleanups.push(initAnalyticsEventTracking());

    document.querySelector("form").dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true }),
    );

    expect(window.dataLayer.at(-1)[1]).toBe("registration_form_submitted");
  });
});
