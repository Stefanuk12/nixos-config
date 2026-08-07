"use strict";

// Talking to the background page from a panel.
//
// The background page is an MV3 event page: Thunderbird suspends it when idle and is meant to
// restart it when a message arrives. That restart races a panel that sends the instant it opens,
// and the first attempt can land before the page is listening again - which is precisely what
// "close and reopen this panel" was asking the user to do by hand. Retrying does it for them.
globalThis.SLIpc = (() => {
  const ATTEMPTS = 4;
  const BACKOFF_MS = 150;

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  /**
   * Send a request, retrying while the background page is waking.
   *
   * Always resolves. A total failure comes back as { ok: false, unreachable: true } so callers
   * distinguish "the add-on is not answering" from "the request was refused", and never sit on a
   * promise that neither resolves nor rejects.
   */
  async function send(type, payload = {}) {
    let last = "no response";

    for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
      try {
        const response = await browser.runtime.sendMessage({ type, ...payload });
        // The background page answers every message it receives, unknown types included, so an
        // undefined response means nothing was listening rather than "handled, no result".
        if (response !== undefined) return response;
        last = "the background page did not respond";
      } catch (e) {
        // "Could not establish connection. Receiving end does not exist." while it restarts.
        last = e.message;
      }

      if (attempt < ATTEMPTS) await sleep(BACKOFF_MS * attempt);
    }

    return {
      ok: false,
      unreachable: true,
      error: `The add-on's background page is not responding (${last}). Restarting Thunderbird usually clears it; if it persists, check the Error Console with Ctrl+Shift+J.`,
    };
  }

  return { send };
})();
