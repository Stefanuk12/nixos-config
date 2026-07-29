"use strict";

// Injected into every compose window purely as a heartbeat. Thunderbird has no event for "the user
// edited the From field" — onIdentityChanged only covers the dropdown, and typing a custom address
// fires nothing — so the window tells the background page to go and look, on a timer.
//
// The timer lives here because an MV3 event page can be suspended when idle, taking its intervals
// with it, whereas this script's lifetime is exactly the compose window's. It runs in the editor
// document but never touches the DOM.
(() => {
  const FALLBACK_INTERVAL_MS = 900;
  let timer = null;

  const tick = () => browser.runtime.sendMessage({ type: "sl:tick" }).catch(() => {
    // Background page mid-restart, or the add-on was disabled. The next tick recovers; if the
    // add-on is gone, stop rather than log once a second.
    if (!browser.runtime?.id) stop();
  });

  function stop() {
    if (timer !== null) clearInterval(timer);
    timer = null;
  }

  async function readInterval() {
    try {
      const { pollIntervalMs } = await browser.storage.local.get("pollIntervalMs");
      if (Number.isFinite(pollIntervalMs) && pollIntervalMs >= 250) return pollIntervalMs;
    } catch {
      /* storage unreadable - the fallback is fine */
    }
    return FALLBACK_INTERVAL_MS;
  }

  async function start() {
    stop();
    const interval = await readInterval();
    tick();
    timer = setInterval(tick, interval);
  }

  // Pick up an interval change from the options page without a reopen.
  browser.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && "pollIntervalMs" in changes) start();
  });

  window.addEventListener("unload", stop, { once: true });
  start();
})();
