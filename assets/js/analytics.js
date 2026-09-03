const ANALYTICS_ID = "G-NZDE9PL5FG";
const INTERACTION_EVENTS = ["pointerdown", "keydown", "touchstart", "scroll"];
const FALLBACK_DELAY_MS = 5000;
const ENGAGEMENT_KEY = "analytics_engaged";

const pendingEvents = () => {
  window.pendingAnalyticsEvents = window.pendingAnalyticsEvents || [];
  return window.pendingAnalyticsEvents;
};

export const loadGoogleAnalytics = () => {
  if (window.gtag || document.querySelector("script[data-google-analytics]")) {
    return;
  }

  window.dataLayer = window.dataLayer || [];
  window.gtag = (...args) => window.dataLayer.push(args);
  window.gtag("js", new Date());
  window.gtag("config", ANALYTICS_ID);

  const script = document.createElement("script");
  script.async = true;
  script.dataset.googleAnalytics = "true";
  script.src = `https://www.googletagmanager.com/gtag/js?id=${ANALYTICS_ID}`;
  document.head.appendChild(script);
};

export const trackAnalyticsEvent = (eventName, params = {}) => {
  if (!eventName) return;

  if (sessionStorage.getItem(ENGAGEMENT_KEY) !== "true") {
    pendingEvents().push([eventName, params]);
    return;
  }

  loadGoogleAnalytics();
  window.gtag("event", eventName, params);
};

export const initDelayedAnalytics = () => {
  let fallbackTimer;

  const scheduleFallback = () => {
    fallbackTimer = window.setTimeout(activate, FALLBACK_DELAY_MS);
  };

  const cleanup = () => {
    window.clearTimeout(fallbackTimer);
    window.removeEventListener("load", scheduleFallback);
    INTERACTION_EVENTS.forEach((eventName) =>
      window.removeEventListener(eventName, activate),
    );
  };

  const activate = () => {
    cleanup();
    sessionStorage.setItem(ENGAGEMENT_KEY, "true");
    loadGoogleAnalytics();

    pendingEvents()
      .splice(0)
      .forEach(([eventName, params]) => window.gtag("event", eventName, params));
  };

  INTERACTION_EVENTS.forEach((eventName) =>
    window.addEventListener(eventName, activate, { once: true, passive: true }),
  );

  if (sessionStorage.getItem(ENGAGEMENT_KEY) === "true") {
    activate();
  } else if (document.readyState === "complete") {
    scheduleFallback();
  } else {
    window.addEventListener("load", scheduleFallback, { once: true });
  }

  return cleanup;
};

export const initAnalyticsEventTracking = () => {
  const track = (event) => {
    const target = event.target.closest?.("[data-analytics-event]");

    if (!target) return;

    const params = { event_location: target.dataset.analyticsLocation || window.location.pathname };

    Object.entries(target.dataset).forEach(([key, value]) => {
      if (!key.startsWith("analytics") || ["analyticsEvent", "analyticsLocation"].includes(key)) return;
      const parameter = key
        .slice("analytics".length)
        .replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)
        .replace(/^_/, "");
      params[parameter] = value;
    });

    trackAnalyticsEvent(target.dataset.analyticsEvent, params);

    const pendingAuth = {
      registration_form_submitted: { event: "sign_up_completed", method: "password" },
      registration_google_clicked: { event: null, method: "google" },
      login_form_submitted: { event: "login_completed", method: "password" },
      login_google_clicked: { event: null, method: "google" },
    }[target.dataset.analyticsEvent];

    if (pendingAuth) sessionStorage.setItem("pending_auth_event", JSON.stringify(pendingAuth));
  };

  document.addEventListener("click", track);
  document.addEventListener("submit", track);

  return () => {
    document.removeEventListener("click", track);
    document.removeEventListener("submit", track);
  };
};

export const initProductAnalytics = () => {
  let lastGridPath;

  const reconcileAuth = () => {
    const storedAuth = sessionStorage.getItem("pending_auth_event");
    const callbackEvent = document.body.dataset.authAnalyticsEvent;

    if ((!storedAuth && !callbackEvent) || !document.querySelector('[aria-label="My Profile"]')) {
      return;
    }

    let pendingAuth;

    try {
      pendingAuth = storedAuth ? JSON.parse(storedAuth) : {};
    } catch {
      pendingAuth = { event: storedAuth, method: "unknown" };
    }

    pendingAuth.event = callbackEvent || pendingAuth.event;

    if (!["sign_up_completed", "login_completed"].includes(pendingAuth.event)) {
      sessionStorage.removeItem("pending_auth_event");
      return;
    }

    sessionStorage.removeItem("pending_auth_event");
    delete document.body.dataset.authAnalyticsEvent;
    trackAnalyticsEvent(pendingAuth.event, { method: pendingAuth.method || "unknown" });
  };

  const trackGridView = () => {
    if (!window.location.pathname.startsWith("/g/") || lastGridPath === window.location.pathname) return;

    lastGridPath = window.location.pathname;
    trackAnalyticsEvent("grid_viewed", {
      user_state: document.querySelector('[aria-label="My Profile"]') ? "authenticated" : "anonymous",
    });
  };

  const trackServerEvent = (event) => {
    trackAnalyticsEvent(event.detail.event, event.detail.params || {});
  };

  const refresh = () => {
    reconcileAuth();
    trackGridView();
  };

  window.addEventListener("phx:analytics", trackServerEvent);
  window.addEventListener("phx:page-loading-stop", refresh);
  refresh();

  return () => {
    window.removeEventListener("phx:analytics", trackServerEvent);
    window.removeEventListener("phx:page-loading-stop", refresh);
  };
};
