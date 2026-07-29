"use strict";

// Turns a From address into one of the states the rest of the add-on renders and acts on. Pure
// functions only, so the popup and background page classify the same snapshot identically.
globalThis.SLClassify = (() => {
  const PREFIX_RE = /^[0-9a-z._-]+$/;

  // Recognised so an already-wrapped recipient is never wrapped twice.
  const REVERSE_ALIAS_RE = /^(ra|reply)\+[^@]+@/i;

  // Handles `a@b.c`, `Name <a@b.c>` and `"Last, First" <a@b.c>`.
  function parseAddress(value) {
    if (!value) return "";
    const raw = String(value).trim();
    const angled = raw.match(/<([^<>]+)>\s*$/);
    const addr = (angled ? angled[1] : raw).trim().replace(/^mailto:/i, "");
    return addr.includes("@") ? addr.toLowerCase() : "";
  }

  // Display name in `Name <a@b.c>`, or "" for a bare address.
  function parseDisplayName(value) {
    if (!value) return "";
    const raw = String(value).trim();
    if (!/<[^<>]+>\s*$/.test(raw)) return "";
    return raw.slice(0, raw.lastIndexOf("<")).trim().replace(/^"|"$/g, "").trim();
  }

  const isReverseAlias = (address) => REVERSE_ALIAS_RE.test(address || "");

  // Commas separate only outside quotes and angle brackets: `"Doe, John" <a@b.c>, x@y.z` is two
  // recipients, not three.
  function parseAddressList(value) {
    if (!value) return [];

    const parts = [];
    let current = "";
    let inQuotes = false;
    let inAngles = false;
    let escaped = false;

    for (const char of String(value)) {
      if (escaped) { current += char; escaped = false; continue; }
      if (char === "\\") { current += char; escaped = true; continue; }
      if (char === '"') inQuotes = !inQuotes;
      else if (!inQuotes && char === "<") inAngles = true;
      else if (!inQuotes && char === ">") inAngles = false;
      else if (char === "," && !inQuotes && !inAngles) { parts.push(current); current = ""; continue; }
      current += char;
    }
    parts.push(current);

    return parts.map(parseAddress).filter(Boolean);
  }

  // Longest suffix from /api/v5/alias/options that `address` ends with, whose remaining prefix is
  // legal. Longest wins, matching SimpleLogin. Premium-only suffixes are skipped for free accounts
  // because the create call would fail.
  function matchSuffix(address, suffixes, { isPremium = true } = {}) {
    if (!address || !Array.isArray(suffixes)) return null;

    let best = null;
    for (const entry of suffixes) {
      const suffix = String(entry.suffix || "").toLowerCase();
      if (!suffix || !address.endsWith(suffix)) continue;
      if (entry.is_premium && !isPremium) continue;

      const prefix = address.slice(0, address.length - suffix.length);
      if (!prefix || !PREFIX_RE.test(prefix)) continue;
      if (!best || suffix.length > best.suffix.suffix.length) best = { prefix, suffix: entry };
    }
    return best;
  }

  // -> { state, address, label, detail, alias?, candidate? }, state being one of:
  //   no-key | stale (no usable snapshot) | not-alias | alias | alias-disabled (mail is dropped)
  //   will-create | can-create (auto-create off, needs a click) | cannot-create (out of quota)
  function classify(address, snapshot, settings, displayName = "") {
    const base = { address, displayName, alias: null, candidate: null };

    if (!settings || !settings.apiKey) {
      return {
        ...base,
        state: "no-key",
        label: "Set API key",
        detail: "Add your SimpleLogin API key in the add-on options.",
      };
    }

    if (!address) {
      return { ...base, state: "not-alias", label: "", detail: "No From address set." };
    }

    if (!snapshot) {
      return {
        ...base,
        state: "stale",
        label: "No data",
        detail: "Alias list not loaded yet - open the panel to sync.",
      };
    }

    const existing = (snapshot.aliases || []).find((a) => String(a.email).toLowerCase() === address);
    if (existing) {
      return existing.enabled
        ? {
            ...base,
            state: "alias",
            alias: existing,
            label: "Alias",
            detail: `${existing.email} is one of your SimpleLogin aliases.`,
          }
        : {
            ...base,
            state: "alias-disabled",
            alias: existing,
            label: "Disabled",
            detail: `${existing.email} exists but is disabled - SimpleLogin will drop mail sent to it.`,
          };
    }

    const options = snapshot.options || {};
    const match = matchSuffix(address, options.suffixes, { isPremium: snapshot.isPremium !== false });
    if (!match) {
      return {
        ...base,
        state: "not-alias",
        label: "",
        detail: `${address} is not a SimpleLogin alias and its domain is not one you can create aliases on.`,
      };
    }

    // The display name typed into From becomes the alias's name, which is what recipients see. A
    // bare address deliberately means no name — that's how you ask for an unnamed alias.
    const candidate = { prefix: match.prefix, suffix: match.suffix, address, name: displayName };
    const named = displayName ? ` with the display name "${displayName}"` : " with no display name";

    if (options.can_create === false) {
      return {
        ...base,
        state: "cannot-create",
        candidate,
        label: "Quota",
        detail: "SimpleLogin says this account cannot create more aliases right now.",
      };
    }

    return settings.autoCreateOnSend
      ? {
          ...base,
          state: "will-create",
          candidate,
          label: "Will create",
          detail: `${address} does not exist yet - it will be created in SimpleLogin${named} when you send.`,
        }
      : {
          ...base,
          state: "can-create",
          candidate,
          label: "Create?",
          detail: `${address} can be created in SimpleLogin${named}. Auto-create on send is off, so create it from this panel.`,
        };
  }

  const isLiveAlias = (state) => state === "alias" || state === "alias-disabled";

  const isCreatable = (state) => state === "will-create" || state === "can-create";

  return {
    parseAddress, parseDisplayName, parseAddressList, isReverseAlias,
    matchSuffix, classify, isLiveAlias, isCreatable, PREFIX_RE,
  };
})();
