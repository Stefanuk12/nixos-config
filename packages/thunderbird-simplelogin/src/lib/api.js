"use strict";

// SimpleLogin REST client. Cache-free by design — store.js decides when a round trip is worth it —
// and the key is passed in, so nothing here knows about storage.
//
// Self-hosting: change BASE_URL *and* manifest.json's `host_permissions`. fetch() is blocked for
// unlisted hosts, and the mismatch surfaces as an opaque network error, not a permission prompt.
globalThis.SLApi = (() => {
  const BASE_URL = "https://app.simplelogin.io";

  // Every paginated endpoint caps at 20 rows; past this many pages, stop and tell the UI rather
  // than loop forever.
  const PAGE_SIZE = 20;
  const MAX_PAGES = 100;

  // fetch() has no default timeout, and store.js hands one in-flight promise to every caller, so a
  // connection that stalls rather than fails wedges the popup on its placeholder with nothing to
  // show and no way to recover short of restarting Thunderbird.
  const TIMEOUT_MS = 20000;

  class SLError extends Error {
    constructor(message, { status = 0, code = "error", body = null } = {}) {
      super(message);
      this.name = "SLError";
      this.status = status;
      this.code = code;
      this.body = body;
    }
  }

  // Failures come back as {"error": "..."}; a proxy or outage may return no JSON at all.
  async function readError(res) {
    let body = null;
    let message = `${res.status} ${res.statusText}`;
    try {
      body = await res.json();
      if (body && typeof body.error === "string") message = body.error;
    } catch {
      /* non-JSON error body - keep the status line */
    }
    return { body, message };
  }

  async function request(path, { method = "GET", query = null, json = null, apiKey } = {}) {
    if (!apiKey) throw new SLError("No SimpleLogin API key configured.", { code: "no-key" });

    const url = new URL(path, BASE_URL);
    if (query) {
      for (const [k, v] of Object.entries(query)) {
        if (v !== null && v !== undefined && v !== "") url.searchParams.set(k, String(v));
      }
    }

    const headers = { Authentication: apiKey, Accept: "application/json" };
    if (json !== null) headers["Content-Type"] = "application/json";

    const unreachable = (e) =>
      e.name === "TimeoutError"
        ? new SLError(`${url.host} did not respond within ${TIMEOUT_MS / 1000}s.`, { code: "timeout" })
        : new SLError(`Cannot reach ${url.host}: ${e.message}`, { code: "network" });

    let res;
    try {
      res = await fetch(url.toString(), {
        method,
        headers,
        body: json === null ? undefined : JSON.stringify(json),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (e) {
      throw unreachable(e);
    }

    if (!res.ok) {
      const { body, message } = await readError(res);
      const code =
        res.status === 401 ? "unauthorized" :
        res.status === 403 ? "forbidden" :
        res.status === 409 ? "duplicate" :
        res.status === 429 ? "rate-limited" :
        res.status === 400 ? "invalid" : "error";
      throw new SLError(message, { status: res.status, code, body });
    }

    if (res.status === 204) return null;
    // The timeout covers the body too, so a response that stops mid-stream lands here.
    try {
      return await res.json();
    } catch (e) {
      throw unreachable(e);
    }
  }

  // `truncated` is surfaced so the UI can say "showing the first N" rather than under-report.
  async function paginate(path, key, { apiKey, query = null }) {
    const items = [];
    let page = 0;
    let truncated = false;

    for (;;) {
      const data = await request(path, { apiKey, query: { ...(query || {}), page_id: page } });
      const batch = (data && data[key]) || [];
      items.push(...batch);
      if (batch.length < PAGE_SIZE) break;
      if (++page >= MAX_PAGES) {
        truncated = true;
        break;
      }
    }

    return { items, truncated };
  }

  return {
    SLError,
    BASE_URL,

    // The cheapest way to validate a key.
    userInfo: (apiKey) => request("/api/user_info", { apiKey }),

    listAliases: (apiKey) => paginate("/api/v2/aliases", "aliases", { apiKey }),

    listMailboxes: async (apiKey) => {
      const data = await request("/api/v2/mailboxes", { apiKey });
      return (data && data.mailboxes) || [];
    },

    // `signed_suffix` is server-signed, so options must be fetched fresh-ish before creating — a
    // stale one is rejected. `hostname` only biases `prefix_suggestion`.
    aliasOptions: (apiKey, hostname = null) =>
      request("/api/v5/alias/options", { apiKey, query: { hostname } }),

    // 409 means the alias already exists.
    createCustomAlias: (apiKey, { prefix, signedSuffix, mailboxIds, note, name, hostname }) =>
      request("/api/v3/alias/custom/new", {
        apiKey,
        method: "POST",
        query: { hostname },
        json: {
          alias_prefix: prefix,
          signed_suffix: signedSuffix,
          ...(mailboxIds && mailboxIds.length ? { mailbox_ids: mailboxIds } : {}),
          ...(note ? { note } : {}),
          ...(name ? { name } : {}),
        },
      }),

    createRandomAlias: (apiKey, { mode = "word", note, hostname } = {}) =>
      request("/api/alias/random/new", {
        apiKey,
        method: "POST",
        query: { hostname, mode },
        json: note ? { note } : {},
      }),

    // Mints the reverse-alias: mail to `reverse_alias_address` is re-sent to the real recipient
    // with the alias as From. 201 = new, 200 = existed.
    createContact: (apiKey, aliasId, contact) =>
      request(`/api/aliases/${encodeURIComponent(aliasId)}/contacts`, {
        apiKey,
        method: "POST",
        json: { contact },
      }),

    listContacts: (apiKey, aliasId) =>
      paginate(`/api/aliases/${encodeURIComponent(aliasId)}/contacts`, "contacts", { apiKey }),

    getAlias: (apiKey, aliasId) =>
      request(`/api/aliases/${encodeURIComponent(aliasId)}`, { apiKey }),

    toggleAlias: (apiKey, aliasId) =>
      request(`/api/aliases/${encodeURIComponent(aliasId)}/toggle`, { apiKey, method: "POST" }),

    // Irreversible; mail to the alias bounces afterwards.
    deleteAlias: (apiKey, aliasId) =>
      request(`/api/aliases/${encodeURIComponent(aliasId)}`, { apiKey, method: "DELETE" }),

    updateAlias: (apiKey, aliasId, patch) =>
      request(`/api/aliases/${encodeURIComponent(aliasId)}`, {
        apiKey,
        method: "PATCH",
        json: patch,
      }),

    // Per-contact, not per-alias: stops this one sender without disturbing the alias.
    toggleContact: (apiKey, contactId) =>
      request(`/api/contacts/${encodeURIComponent(contactId)}/toggle`, { apiKey, method: "POST" }),
  };
})();
