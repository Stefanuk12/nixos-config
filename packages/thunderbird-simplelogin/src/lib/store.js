"use strict";

// Aliases, creatable suffixes, mailboxes and plan status, fetched together and cached as one blob.
// One blob rather than four caches because classification needs them mutually consistent — an
// alias list from before a domain was added plus suffixes from after gives a contradictory badge.
globalThis.SLStore = (() => {
  // Concurrent callers share one round trip instead of racing to overwrite each other's write.
  let inflight = null;

  async function fetchSnapshot(apiKey, hostname) {
    // Cheapest call first, so a bad key fails before enumerating every alias.
    const user = await SLApi.userInfo(apiKey);
    const [aliases, options, mailboxes] = await Promise.all([
      SLApi.listAliases(apiKey),
      SLApi.aliasOptions(apiKey, hostname),
      SLApi.listMailboxes(apiKey),
    ]);

    return {
      aliases: aliases.items,
      truncated: aliases.truncated,
      options,
      mailboxes,
      isPremium: Boolean(user.is_premium || user.in_trial),
      userEmail: user.email || "",
      maxAliasFreePlan: user.max_alias_free_plan ?? null,
      fetchedAt: Date.now(),
    };
  }

  // `force` bypasses the TTL (after creating an alias, and the Refresh button). `hostname` biases
  // the prefix suggestion toward the recipient's domain and is otherwise inert.
  async function getSnapshot({ force = false, hostname = null } = {}) {
    const settings = await SLPrefs.getSettings();
    if (!settings.apiKey) return { snapshot: null, error: null, settings };

    const cached = await SLPrefs.getCache();
    const fresh = cached && Date.now() - cached.fetchedAt < settings.cacheTtlMs;
    if (fresh && !force) return { snapshot: cached, error: null, settings };

    if (!inflight) {
      inflight = fetchSnapshot(settings.apiKey, hostname)
        .then(async (snapshot) => {
          await SLPrefs.setCache(snapshot);
          return snapshot;
        })
        .finally(() => {
          inflight = null;
        });
    }

    try {
      return { snapshot: await inflight, error: null, settings };
    } catch (e) {
      // A stale snapshot still classifies known aliases, so return it with the error rather than
      // blank the UI on a flaky network.
      return { snapshot: cached || null, error: { message: e.message, code: e.code || "error" }, settings };
    }
  }

  // Merge in without a full refetch.
  async function addAlias(alias) {
    const cached = await SLPrefs.getCache();
    if (!cached) return;
    const others = (cached.aliases || []).filter((a) => a.id !== alias.id);
    await SLPrefs.setCache({ ...cached, aliases: [alias, ...others] });
  }

  async function patchAlias(aliasId, patch) {
    const cached = await SLPrefs.getCache();
    if (!cached) return;
    await SLPrefs.setCache({
      ...cached,
      aliases: (cached.aliases || []).map((a) => (a.id === aliasId ? { ...a, ...patch } : a)),
    });
  }

  async function removeAlias(aliasId) {
    const cached = await SLPrefs.getCache();
    if (!cached) return;
    await SLPrefs.setCache({
      ...cached,
      aliases: (cached.aliases || []).filter((a) => a.id !== aliasId),
    });
  }

  // SimpleLogin's "you've used this alias with this site before" hint, keyed by recipient domain.
  // In memory only: cheap to re-fetch and scoped to one compose session.
  const recommendations = new Map();

  // Cached per hostname: the answer only changes when you create or use an alias for that site,
  // and compose re-checks on every keystroke.
  async function recommendationFor(hostname, apiKey) {
    if (!hostname || !apiKey) return null;
    if (recommendations.has(hostname)) return recommendations.get(hostname);

    let recommendation = null;
    try {
      const options = await SLApi.aliasOptions(apiKey, hostname);
      // Only trust it when SimpleLogin agrees it is about this hostname.
      const hit = options?.recommendation;
      if (hit?.alias && (!hit.hostname || hit.hostname === hostname)) recommendation = hit;
    } catch {
      /* a missing suggestion is not worth surfacing as an error */
    }

    recommendations.set(hostname, recommendation);
    return recommendation;
  }

  return { getSnapshot, addAlias, patchAlias, removeAlias, recommendationFor };
})();
