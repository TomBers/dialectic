import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  initAnalyticsEventTracking,
  initDelayedAnalytics,
  initProductAnalytics,
  loadGoogleAnalytics,
} from "../analytics.js";

const analyticsScripts = () =>
  document.querySelectorAll("script[data-google-analytics]");
const lastAnalyticsCommand = () => Array.from(window.dataLayer.at(-1));

let cleanups;

beforeEach(() => {
  vi.useFakeTimers();
  cleanups = [];
  delete window.gtag;
  delete window.dataLayer;
  delete window.pendingAnalyticsEvents;
  document.head
    .querySelectorAll("script[data-google-analytics]")
    .forEach((script) => script.remove());
  document.body.innerHTML = "";
  sessionStorage.clear();
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
    expect(Array.isArray(window.dataLayer[0])).toBe(false);
    expect(Array.from(window.dataLayer[1])).toEqual([
      "config",
      "G-NZDE9PL5FG",
    ]);
  });

  it("loads after a short fallback delay without human interaction", () => {
    cleanups.push(initDelayedAnalytics());
    window.dispatchEvent(new Event("load"));

    vi.advanceTimersByTime(4999);
    expect(analyticsScripts()).toHaveLength(0);

    vi.advanceTimersByTime(1);
    expect(analyticsScripts()).toHaveLength(1);
    expect(sessionStorage.getItem("analytics_engaged")).toBe("true");
  });

  it("loads when a visitor scrolls", () => {
    cleanups.push(initDelayedAnalytics());

    window.dispatchEvent(new Event("scroll"));

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

  it("cancels interaction listeners during cleanup", () => {
    const cleanup = initDelayedAnalytics();
    cleanup();

    window.dispatchEvent(new Event("pointerdown"));
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
    cleanups.push(initAnalyticsEventTracking(), initDelayedAnalytics());
    window.dispatchEvent(new Event("pointerdown"));

    document.querySelector("a").click();

    expect(lastAnalyticsCommand()).toEqual([
      "event",
      "sign_up_cta_clicked",
      { event_location: "home_hero" },
    ]);
  });

  it("includes declared privacy-safe event parameters", () => {
    document.body.innerHTML = `
      <button data-analytics-event="answer_depth_selected"
        data-analytics-location="question_form"
        data-analytics-answer-depth="expert">Expert</button>
    `;
    cleanups.push(initAnalyticsEventTracking(), initDelayedAnalytics());
    window.dispatchEvent(new Event("keydown"));

    document.querySelector("button").click();

    expect(window.dataLayer.at(-1)[2]).toEqual({
      event_location: "question_form",
      answer_depth: "expert",
    });
  });

  it("tracks forms submitted without a click", () => {
    document.body.innerHTML = `
      <form data-analytics-event="registration_form_submitted"></form>
    `;
    cleanups.push(initAnalyticsEventTracking(), initDelayedAnalytics());
    window.dispatchEvent(new Event("touchstart"));

    document.querySelector("form").dispatchEvent(
      new Event("submit", { bubbles: true, cancelable: true }),
    );

    expect(window.dataLayer.at(-1)[1]).toBe("registration_form_submitted");
    expect(JSON.parse(sessionStorage.getItem("pending_auth_event"))).toEqual({
      event: "sign_up_completed",
      method: "password",
    });
  });

  it("preserves Google as the pending authentication method", () => {
    document.body.innerHTML = `
      <a data-analytics-event="login_google_clicked">Continue with Google</a>
    `;
    cleanups.push(initAnalyticsEventTracking(), initDelayedAnalytics());
    window.dispatchEvent(new Event("pointerdown"));

    document.querySelector("a").click();

    expect(JSON.parse(sessionStorage.getItem("pending_auth_event"))).toEqual({
      event: null,
      method: "google",
    });
  });

  it("uses the callback outcome rather than the originating Google CTA", () => {
    document.body.innerHTML = '<a aria-label="My Profile"></a>';
    document.body.dataset.authAnalyticsEvent = "login_completed";
    sessionStorage.setItem(
      "pending_auth_event",
      JSON.stringify({ event: null, method: "google" }),
    );

    cleanups.push(initProductAnalytics(), initDelayedAnalytics());
    window.dispatchEvent(new Event("pointerdown"));

    expect(lastAnalyticsCommand()).toEqual([
      "event",
      "login_completed",
      { method: "google" },
    ]);
    expect(document.body.dataset.authAnalyticsEvent).toBeUndefined();
  });

  it("queues confirmed LiveView events until the visitor engages", () => {
    cleanups.push(initProductAnalytics(), initDelayedAnalytics());

    window.dispatchEvent(
      new CustomEvent("phx:analytics", {
        detail: { event: "grid_created", params: { answer_depth: "university" } },
      }),
    );

    expect(analyticsScripts()).toHaveLength(0);
    window.dispatchEvent(new Event("pointerdown"));

    expect(lastAnalyticsCommand()).toEqual([
      "event",
      "grid_created",
      { answer_depth: "university" },
    ]);
  });

  it("records a pending authentication outcome after authenticated navigation", () => {
    document.body.innerHTML = '<a aria-label="My Profile"></a>';
    sessionStorage.setItem(
      "pending_auth_event",
      JSON.stringify({ event: "sign_up_completed", method: "google" }),
    );

    cleanups.push(initProductAnalytics(), initDelayedAnalytics());
    window.dispatchEvent(new Event("pointerdown"));

    expect(lastAnalyticsCommand()).toEqual([
      "event",
      "sign_up_completed",
      { method: "google" },
    ]);
    expect(sessionStorage.getItem("pending_auth_event")).toBeNull();
  });

  it("handles pending events stored by the previous string format", () => {
    document.body.innerHTML = '<a aria-label="My Profile"></a>';
    sessionStorage.setItem("pending_auth_event", "login_completed");

    cleanups.push(initProductAnalytics(), initDelayedAnalytics());
    window.dispatchEvent(new Event("pointerdown"));

    expect(lastAnalyticsCommand()).toEqual([
      "event",
      "login_completed",
      { method: "unknown" },
    ]);
  });
});
