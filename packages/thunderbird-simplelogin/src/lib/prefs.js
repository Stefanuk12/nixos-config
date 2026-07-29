"use strict";

// Settings + cache, both in storage.local.
//
// Settings live under discrete top-level keys so the options page can write one field without
// read-modify-writing the rest. The alias/suffix cache is one blob, always replaced wholesale.
globalThis.SLPrefs = (() => {
  const DEFAULTS = {
    apiKey: "",

    // Empty = let SimpleLogin pick the account default.
    defaultMailboxIds: [],

    // Off = the badge still tells you, but you must press Create in the popup.
    autoCreateOnSend: true,

    // One setting rather than two checkboxes because the modes are mutually exclusive:
    //
    // "reverse-alias" - recipients are swapped for SimpleLogin reverse-aliases and the message
    //   leaves from the real mailbox; SimpleLogin re-sends it to the contact as the alias. From is
    //   only a selector and is reset on send. Works with any provider, needs a paid plan.
    //
    // "identity" - a real Thunderbird identity is created for the alias and the message is sent
    //   directly as it. Cleaner, but only works if the outgoing server accepts the alias as a
    //   sender, and it can't be combined with reverse-aliases: switching identity changes the
    //   envelope MAIL FROM, which is exactly what SimpleLogin checks to authorise the send.
    sendMode: "reverse-alias",

    // Cancel the send rather than let an unresolvable recipient go out un-rewritten and leak the
    // real From.
    strictRewrite: true,

    // SimpleLogin has no notion of a local list, so lists are expanded to members before
    // rewriting. Off = treat a list as unresolvable.
    expandMailingLists: true,

    aliasNote: "Created from Thunderbird",

    // How often the compose window asks the background to re-read From. The check is local; only
    // a changed address costs a round trip.
    pollIntervalMs: 900,

    cacheTtlMs: 5 * 60 * 1000,

    // On reply/forward, set From to the alias the original arrived at.
    autoAliasOnReply: true,

    // SimpleLogin's own recommendation; costs one request per new domain.
    suggestByRecipient: true,

    // The only setting that rewrites stored mail — the saved copy is re-imported with corrected
    // headers and the original deleted — hence off by default. Needs messagesImport/messagesDelete,
    // requested from the options page rather than up front.
    restoreSentRecipients: false,
  };

  const SETTING_KEYS = Object.keys(DEFAULTS);

  // Identities we created, so the options page never offers to clean up a hand-made one.
  const STATE_DEFAULTS = { createdIdentityIds: [] };

  // Lets the key come from a password manager instead of the profile: something outside
  // Thunderbird writes the manifest, we only read it. An absent manifest is the normal case.
  async function managedApiKey() {
    try {
      const managed = await browser.storage.managed.get("apiKey");
      return typeof managed?.apiKey === "string" ? managed.apiKey.trim() : "";
    } catch {
      return "";
    }
  }

  async function getSettings() {
    const stored = await browser.storage.local.get(SETTING_KEYS);
    const settings = { ...DEFAULTS, ...stored };

    // A managed key wins over anything typed into the options page, which locks the field.
    const managed = await managedApiKey();
    settings.apiKeyIsManaged = Boolean(managed);
    if (managed) settings.apiKey = managed;

    return settings;
  }

  async function setSettings(patch) {
    const clean = {};
    for (const [k, v] of Object.entries(patch)) {
      if (SETTING_KEYS.includes(k)) clean[k] = v;
    }
    await browser.storage.local.set(clean);
    return getSettings();
  }

  async function getState() {
    const stored = await browser.storage.local.get(Object.keys(STATE_DEFAULTS));
    return { ...STATE_DEFAULTS, ...stored };
  }

  async function setState(patch) {
    await browser.storage.local.set(patch);
    return getState();
  }

  async function getCache() {
    const { cache } = await browser.storage.local.get("cache");
    return cache || null;
  }

  const setCache = (cache) => browser.storage.local.set({ cache });
  const clearCache = () => browser.storage.local.remove("cache");

  return { DEFAULTS, getSettings, setSettings, getState, setState, getCache, setCache, clearCache };
})();
