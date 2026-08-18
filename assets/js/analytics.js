const ANALYTICS_ID = "G-NZDE9PL5FG";
const INTERACTION_EVENTS = ["pointerdown", "keydown", "touchstart", "scroll"];

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

export const initDelayedAnalytics = () => {
  let fallbackTimer;

  const cleanup = () => {
    window.clearTimeout(fallbackTimer);
    window.removeEventListener("load", scheduleFallback);
    INTERACTION_EVENTS.forEach((eventName) =>
      window.removeEventListener(eventName, load),
    );
  };

  const load = () => {
    cleanup();
    loadGoogleAnalytics();
  };

  function scheduleFallback() {
    fallbackTimer = window.setTimeout(load, 5000);
  }

  INTERACTION_EVENTS.forEach((eventName) =>
    window.addEventListener(eventName, load, { once: true, passive: true }),
  );

  if (document.readyState === "complete") {
    scheduleFallback();
  } else {
    window.addEventListener("load", scheduleFallback, { once: true });
  }

  return cleanup;
};
