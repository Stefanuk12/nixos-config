"use strict";

// Orchestration: watch the From field of every compose window, render what is about to happen onto
// the compose-toolbar button, and make it happen on send.

// Registered FIRST, deliberately. Every panel reaches this page through runtime.onMessage, so if
// the listener were installed after anything that can throw, one bad API call at load would leave
// the add-on mute - sendMessage finding no receiver, and every panel reporting "the background page
// did not answer" with no clue why. Registering it before any other statement means a later failure
// can still be reported rather than swallowed.
//
// HANDLERS is declared far below; the listener only dereferences it once a message arrives, by
// which time the script has finished loading.
const startupProblems = [];

browser.runtime.onMessage.addListener((message, sender) => {
  const type = message?.type;
  const handler = Object.prototype.hasOwnProperty.call(HANDLERS, type) ? HANDLERS[type] : null;

  // Answer even an unrecognised message. Returning false would resolve the sender's sendMessage to
  // undefined, which is indistinguishable from a dead background page - the very ambiguity this
  // ordering exists to remove.
  if (!handler) return Promise.resolve({ ok: false, error: `Unknown request "${type}".` });

  return handler(message, sender).catch((e) => ({ ok: false, error: e.message }));
});

// Register a listener without letting its failure take the add-on down. A namespace missing because
// a permission was declined should cost only the feature that needs it.
function safeListen(label, register) {
  try {
    register();
  } catch (e) {
    startupProblems.push(`${label}: ${e.message}`);
  }
}

/**
 * Required permissions the manifest asks for but Thunderbird has not granted.
 *
 * Thunderbird records the granted set when an add-on is installed and re-evaluates it only on a
 * version change. Shipping a new manifest under the same version therefore leaves a newly-added
 * permission ungranted for ever, and its whole API namespace undefined - which surfaces as an
 * inscrutable "browser.X is undefined" far from the cause. Naming the missing permission turns
 * that into an instruction.
 */
async function missingPermissions() {
  const required = (browser.runtime.getManifest().permissions || [])
    .filter((p) => !p.includes("://"));
  const granted = await browser.permissions.getAll().catch(() => null);
  if (!granted) return [];
  const have = new Set(granted.permissions || []);
  return required.filter((p) => !have.has(p));
}

// Badge text caps at ~4 characters, so it carries only severity; the label carries the meaning and
// the tooltip the full sentence.
const BADGES = {
  "no-key":         { text: "?",   colour: "#6e7681" },
  "stale":          { text: "?",   colour: "#6e7681" },
  "not-alias":      { text: "",    colour: null },
  "alias":          { text: "✓", colour: "#2ea043" },
  "alias-disabled": { text: "off", colour: "#d29922" },
  "will-create":    { text: "NEW", colour: "#d29922" },
  "can-create":     { text: "NEW", colour: "#1f6feb" },
  "cannot-create":  { text: "!",   colour: "#f85149" },
  "creating":       { text: "…", colour: "#1f6feb" },
  "created":        { text: "✓", colour: "#2ea043" },
  "error":          { text: "!",   colour: "#f85149" },
};

// Last computed status per compose tab, so the popup renders the verdict the badge already showed.
const statusByTab = new Map();

// Lets the popup find its own tab even when tabs.query comes back empty, which it does for a popup
// owned by a compose window rather than a mail tab.
let lastComposeTabId = null;

async function render(tabId, status) {
  statusByTab.set(tabId, status);
  const badge = BADGES[status.state] || BADGES.error;
  try {
    await Promise.all([
      browser.composeAction.setBadgeText({ tabId, text: badge.text }),
      browser.composeAction.setBadgeBackgroundColor({ tabId, color: badge.colour }),
      browser.composeAction.setLabel({ tabId, label: status.label ? `SL: ${status.label}` : "SimpleLogin" }),
      browser.composeAction.setTitle({ tabId, title: `SimpleLogin\n${status.detail || ""}` }),
    ]);
  } catch {
    // The compose window closed between classifying and painting. Harmless.
  }
}

function notify(title, message) {
  return browser.notifications
    .create({ type: "basic", title, message })
    .catch(() => {/* notifications unavailable - the badge still carries it */});
}

// `details.from` reflects a custom From typed into the window, so `hello <x@y.z>` yields the name
// "hello" and a bare `x@y.z` yields none. The identity is consulted only when From is empty.
async function resolveFrom(details) {
  const typed = SLClassify.parseAddress(details.from);
  if (typed) return { address: typed, displayName: SLClassify.parseDisplayName(details.from) };

  if (details.identityId) {
    const identity = await browser.identities.get(details.identityId).catch(() => null);
    if (identity) {
      return { address: SLClassify.parseAddress(identity.email), displayName: identity.name || "" };
    }
  }
  return { address: "", displayName: "" };
}

// Used only to bias SimpleLogin's prefix suggestion.
function hostnameHint(details) {
  for (const field of ["to", "cc", "bcc"]) {
    const list = details[field];
    const items = typeof list === "string" ? [list] : list || [];
    for (const item of items) {
      const address = typeof item === "string" ? SLClassify.parseAddress(item) : "";
      if (address) return address.split("@")[1] || null;
    }
  }
  return null;
}

// The flags are separate on purpose: `recheck` re-classifies even when From hasn't moved (a
// setting changed, an alias was created), `refetch` also goes back to SimpleLogin. One flag would
// make every local repaint cost a round trip.
async function evaluate(tabId, { recheck = false, refetch = false } = {}) {
  let details;
  try {
    details = await browser.compose.getComposeDetails(tabId);
  } catch {
    statusByTab.delete(tabId);
    return null;
  }

  const typed = await resolveFrom(details);
  // A panel choice wins over the From field: it is the only place it is recorded, since writing it
  // into From would break the compose window.
  const chosen = selectedAliasByTab.get(tabId);
  const address = chosen || typed.address;
  const displayName = chosen ? "" : typed.displayName;
  const previous = statusByTab.get(tabId);

  // The common case: the poll fired and nothing moved. Bail before any storage or network work.
  // The name counts too — editing it changes what the alias would be created as.
  const unchanged = previous && previous.address === address && previous.displayName === displayName;
  if (!recheck && !refetch && unchanged && previous.state !== "stale") return previous;

  const hostname = hostnameHint(details);
  const { snapshot, error, settings } = await SLStore.getSnapshot({ force: refetch, hostname });

  // Before classifying, so the badge describes the final state rather than the pre-swap one.
  if (!error && (await maybeAutoAlias(tabId, details, settings, snapshot))) {
    return evaluate(tabId, { recheck: true });
  }

  const status = error && !snapshot
    ? { state: "error", address, displayName, alias: null, candidate: null, label: "Error", detail: error.message }
    : SLClassify.classify(address, snapshot, settings, displayName);

  status.sendMode = settings.sendMode;
  status.chosenInPanel = Boolean(chosen);

  // Explain a From the user did not type, for as long as it is still in place.
  const notice = autoAliasNotice.get(tabId);
  if (notice && notice.email.toLowerCase() === address) status.autoApplied = notice.detail;
  else if (notice) autoAliasNotice.delete(tabId);

  // "You've used an alias with this recipient before" — only while From isn't already an alias.
  if (settings.suggestByRecipient && !SLClassify.isLiveAlias(status.state) && hostname) {
    const recommended = await SLStore.recommendationFor(hostname, settings.apiKey);
    if (recommended && String(recommended.alias).toLowerCase() !== address) {
      status.suggestion = { alias: recommended.alias, hostname };
    }
  }

  await render(tabId, status);
  return status;
}

// Options are re-fetched first: `signed_suffix` is a server-side signature with a limited
// lifetime, and one cached five minutes ago may already be rejected.
async function createFromCandidate(candidate, settings, hostname) {
  const options = await SLApi.aliasOptions(settings.apiKey, hostname);
  const fresh = (options.suffixes || []).find((s) => s.suffix === candidate.suffix.suffix);
  if (!fresh) {
    throw new SLApi.SLError(
      `${candidate.suffix.suffix} is no longer an available suffix on your account.`,
      { code: "invalid" },
    );
  }

  const alias = await SLApi.createCustomAlias(settings.apiKey, {
    prefix: candidate.prefix,
    signedSuffix: fresh.signed_suffix,
    mailboxIds: settings.defaultMailboxIds,
    note: settings.aliasNote,
    // Empty passes through as empty, and the API client then omits the field, leaving it unnamed.
    name: candidate.name,
    hostname,
  });

  await SLStore.addAlias(alias);
  return alias;
}

async function accountIdFor(details) {
  if (details.identityId) {
    const identity = await browser.identities.get(details.identityId).catch(() => null);
    if (identity) return identity.accountId;
  }
  const accounts = await browser.accounts.list(false);
  const usable = accounts.find((a) => a.identities && a.identities.length);
  if (!usable) throw new Error("No mail account with an identity to attach the alias to.");
  return usable.id;
}

// Created ids are recorded so the options page can offer to remove them without ever touching a
// hand-made identity.
async function ensureIdentity(accountId, email, displayName) {
  const existing = await browser.identities.list(accountId);
  const match = existing.find((i) => SLClassify.parseAddress(i.email) === email);
  if (match) return match;

  const created = await browser.identities.create(accountId, {
    email,
    name: displayName || "",
    label: "SimpleLogin",
  });

  const { createdIdentityIds } = await SLPrefs.getState();
  await SLPrefs.setState({ createdIdentityIds: [...new Set([...createdIdentityIds, created.id])] });
  return created;
}

// Identity mode switches identity outright. In reverse-alias mode From is only a selector —
// overridden for display, reset on send — so the identity is left alone.
// The alias chosen from the panel, per compose tab.
//
// Held here rather than written into the From field, because writing it there breaks the compose
// window. setComposeDetails({from}) calls Thunderbird's MakeFromFieldEditable() whenever the value
// differs from the field's current one; that sets the identity menulist to a string matching no
// identity, leaving selectedItem null. Any later call then dies on `selectedItem.value` inside
// Thunderbird, the setComposeDetails promise rejects, and if that happens during onBeforeSend the
// message is never sent. Reading a From the *user* typed is unaffected and still works - it is only
// writing one programmatically that is unsafe.
const selectedAliasByTab = new Map();

async function applyAliasToTab(tabId, email, displayName = null) {
  const settings = await SLPrefs.getSettings();
  const details = await browser.compose.getComposeDetails(tabId);

  if (settings.sendMode === "identity") {
    try {
      const accountId = await accountIdFor(details);
      const current = details.identityId ? await browser.identities.get(details.identityId) : null;
      const identity = await ensureIdentity(accountId, email, displayName ?? current?.name ?? "");
      // Selecting a real identity keeps the menulist's selectedItem valid, so this is safe.
      await browser.compose.setComposeDetails(tabId, { identityId: identity.id });
      selectedAliasByTab.delete(tabId);
      return { ok: true, via: "identity" };
    } catch (e) {
      // No safe fallback: a raw From override is what breaks sending. Record the choice instead so
      // the reverse-alias path still applies it on send.
      selectedAliasByTab.set(tabId, email);
      return { ok: true, via: "tracked", warning: e.message };
    }
  }

  selectedAliasByTab.set(tabId, email);
  return { ok: true, via: "tracked" };
}

// Compose tabs already considered; without this the poll would re-apply every tick and stomp a
// deliberate change of From.
const autoAliasHandled = new Set();

// Set when auto-alias fires, so the panel can explain a From the user didn't type.
const autoAliasNotice = new Map();

// On reply or forward, set From to the alias the original came in on. Replies are the bulk of
// alias traffic and would otherwise go out silently from the real mailbox.
async function maybeAutoAlias(tabId, details, settings, snapshot) {
  if (!settings.autoAliasOnReply) return false;
  if (autoAliasHandled.has(tabId)) return false;
  if (!["reply", "forward"].includes(details.type)) return false;
  if (!details.relatedMessageId) return false;

  // The first poll can beat the first successful fetch. Return without claiming the tab, or the
  // single attempt is burned on an empty list and the feature silently disables itself.
  if (!snapshot?.aliases?.length) return false;

  // Claim before the first await, or concurrent ticks both get past the check and apply twice.
  autoAliasHandled.add(tabId);

  const hit = await SLMessages.aliasForMessage(details.relatedMessageId, snapshot?.aliases);
  if (!hit) return false;

  // Never override a From the user has already pointed somewhere deliberate.
  const { address } = await resolveFrom(details);
  if (address === String(hit.alias.email).toLowerCase()) return false;

  await applyAliasToTab(tabId, hit.alias.email);
  autoAliasNotice.set(tabId, {
    email: hit.alias.email,
    // "Selected", not "set in From": in reverse-alias mode the From field is deliberately left
    // alone, and claiming otherwise would send the user looking for a change that isn't there.
    detail: hit.via === "x-simplelogin-envelope-to"
      ? `Selected automatically: the message you are replying to arrived at ${hit.alias.email}.`
      : `Selected automatically: ${hit.alias.email} appeared in the original message's ${hit.via} header.`,
  });
  return true;
}

// Fallback for address books whose entries carry a vCard instead of PrimaryEmail.
function emailFromVCard(vCard) {
  if (!vCard) return "";
  const unfolded = String(vCard).replace(/\r?\n[ \t]/g, "");
  for (const line of unfolded.split(/\r?\n/)) {
    const match = line.match(/^EMAIL(?:;[^:]*)?:(.+)$/i);
    if (match) {
      const address = SLClassify.parseAddress(match[1]);
      if (address) return address;
    }
  }
  return "";
}

async function contactToEntry(id) {
  const node = await browser.contacts.get(id).catch(() => null);
  if (!node) return null;
  const address =
    SLClassify.parseAddress(node.properties?.PrimaryEmail) || emailFromVCard(node.vCard);
  if (!address) return null;
  const name = node.properties?.DisplayName || "";
  return { address, raw: name ? `${name} <${address}>` : address };
}

// Recipients arrive as header strings or address-book node references; reverse-aliasing needs the
// literal address either way. Exactly one output item per input, unresolved ones keeping whatever
// the compose window gave us — dropping a recipient we couldn't read would turn "we couldn't hide
// your address from this person" into "this person never got the message".
async function resolveRecipients(list, settings) {
  const items = typeof list === "string" ? [list] : list || [];
  const resolved = [];

  const fail = (original, why) => resolved.push({ ok: false, original, why });

  for (const item of items) {
    if (typeof item === "string") {
      if (!item.trim()) continue;
      const address = SLClassify.parseAddress(item);
      if (address) resolved.push({ ok: true, address, raw: item, original: item });
      else fail(item, `"${item.trim()}" is not a usable address`);
      continue;
    }

    const id = item.id ?? item.nodeId;
    if (item.type === "contact") {
      const entry = await contactToEntry(id);
      if (entry) resolved.push({ ok: true, ...entry, original: item });
      else fail(item, "an address book contact with no readable email address");
      continue;
    }

    if (item.type === "mailingList") {
      if (!settings.expandMailingLists) {
        fail(item, "a mailing list (list expansion is disabled)");
        continue;
      }
      const members = await browser.mailingLists.listMembers(id).catch(() => []);
      if (!members.length) {
        fail(item, "an empty or unreadable mailing list");
        continue;
      }
      for (const member of members) {
        const entry = await contactToEntry(member.id);
        // An unreadable member falls back to the list itself, not a node the header can't render.
        if (entry) resolved.push({ ok: true, ...entry, original: item });
        else fail(item, "a mailing list member with no readable email address");
      }
      continue;
    }

    fail(item, "an unrecognised recipient");
  }

  return resolved;
}

// Header name per ComposeDetails field, for the Sent-copy repair.
const HEADER_NAMES = { to: "To", cc: "Cc", bcc: "Bcc" };

async function buildReverseAliases(details, alias, settings) {
  const patch = {};
  const problems = [];
  // Recipients as written, so the Sent copy can be put back instead of showing reverse-aliases.
  const originals = {};
  let rewritten = 0;

  for (const field of ["to", "cc", "bcc"]) {
    const list = details[field];
    if (!list || (Array.isArray(list) && !list.length)) continue;

    const out = [];
    const seen = [];
    for (const entry of await resolveRecipients(list, settings)) {
      const label = field.toUpperCase();
      if (entry.ok) seen.push(entry.raw);

      if (!entry.ok) {
        problems.push(`${label}: could not read ${entry.why}`);
        out.push(entry.original);
        continue;
      }

      // A reply to a forward already has a reverse-alias in To; wrapping it again would bounce.
      if (SLClassify.isReverseAlias(entry.address)) {
        out.push(entry.raw);
        continue;
      }

      try {
        const contact = await SLApi.createContact(settings.apiKey, alias.id, entry.raw);
        out.push(contact.reverse_alias_address);
        rewritten++;
      } catch (e) {
        // Keep the original: strict mode cancels anyway, lax mode chose delivery over concealment.
        problems.push(`${label}: ${entry.address} - ${e.message}`);
        out.push(entry.original);
      }
    }

    patch[field] = out;
    originals[HEADER_NAMES[field]] = seen;
  }

  return { patch, problems, rewritten, originals };
}

safeListen("compose.onBeforeSend", () => browser.compose.onBeforeSend.addListener(async (tab, details) => {
  const settings = await SLPrefs.getSettings();
  if (!settings.apiKey) return {};

  const hostname = hostnameHint(details);
  const typed = await resolveFrom(details);
  const chosen = selectedAliasByTab.get(tab.id);
  const address = chosen || typed.address;
  const { snapshot } = await SLStore.getSnapshot({ hostname });
  const status = SLClassify.classify(address, snapshot, settings, chosen ? "" : typed.displayName);

  let alias = status.alias;

  // Failing here cancels the send — going out from the real mailbox is the leak being avoided.
  if (status.state === "will-create") {
    await render(tab.id, { ...status, state: "creating", label: "Creating", detail: `Creating ${address}...` });
    try {
      alias = await createFromCandidate(status.candidate, settings, hostname);
      await render(tab.id, {
        ...status, state: "created", alias, label: "Created",
        detail: `${alias.email} was created in SimpleLogin.`,
      });
    } catch (e) {
      // 409 means it was created between classification and now; adopt it and carry on.
      if (e.code === "duplicate") {
        const { snapshot: refreshed } = await SLStore.getSnapshot({ force: true, hostname });
        alias = (refreshed?.aliases || []).find((a) => String(a.email).toLowerCase() === address) || null;
      }
      if (!alias) {
        await render(tab.id, { ...status, state: "error", label: "Failed", detail: e.message });
        await notify("Send cancelled", `Could not create ${address}: ${e.message}`);
        return { cancel: true };
      }
    }
  }

  // From names an address on a SimpleLogin domain that doesn't exist; sending would put an
  // unowned From on a message leaving the real mailbox.
  if (!alias && (SLClassify.isCreatable(status.state) || status.state === "cannot-create")) {
    const why = status.state === "cannot-create"
      ? "SimpleLogin will not create more aliases on this account right now."
      : "Auto-create on send is off, so it was never created.";
    await render(tab.id, { ...status, state: "error", label: "Not created", detail: why });
    await notify("Send cancelled", `${address} does not exist as an alias. ${why}`);
    return { cancel: true };
  }

  // An ordinary address with nothing to do with SimpleLogin.
  if (!alias) return {};

  if (status.state === "alias-disabled") {
    await notify(
      "Sending from a disabled alias",
      `${alias.email} is disabled in SimpleLogin. Replies to it will be dropped until you re-enable it.`,
    );
  }

  if (settings.sendMode === "identity") {
    try {
      const accountId = await accountIdFor(details);
      const current = details.identityId ? await browser.identities.get(details.identityId) : null;
      const identity = await ensureIdentity(accountId, alias.email, current?.name || "");
      return { details: { identityId: identity.id } };
    } catch (e) {
      await notify("Send cancelled", `Could not use ${alias.email} as an identity: ${e.message}`);
      return { cancel: true };
    }
  }

  // Reverse-alias mode.
  let result;
  try {
    result = await buildReverseAliases(details, alias, settings);
  } catch (e) {
    await notify("Send cancelled", `Reverse-alias rewriting failed: ${e.message}`);
    return { cancel: true };
  }

  if (result.problems.length && settings.strictRewrite) {
    await render(tab.id, { ...status, state: "error", label: "Failed", detail: result.problems.join("\n") });
    await notify(
      "Send cancelled",
      `Some recipients could not be routed through ${alias.email}, and sending anyway would expose your real address:\n\n${result.problems.join("\n")}`,
    );
    return { cancel: true };
  }
  if (result.problems.length) {
    await notify("Sent with warnings", result.problems.join("\n"));
  }

  // Hand the From field back to the identity. SimpleLogin authorises the send on
  // the envelope sender, which follows the identity and not this header, so a
  // lingering alias in From buys nothing and risks the outgoing server rejecting
  // a message whose From it does not own.
  const identity = details.identityId ? await browser.identities.get(details.identityId).catch(() => null) : null;
  const identityAddress = SLClassify.parseAddress(identity?.email);

  // Left over from identity mode: the selected identity is itself an alias, so the envelope sender
  // would be too and SimpleLogin refuses the reverse-alias send. Only changing the identity fixes
  // it, so stop rather than let it bounce.
  if (identityAddress && (snapshot?.aliases || []).some((a) => String(a.email).toLowerCase() === identityAddress)) {
    await notify(
      "Send cancelled",
      `The selected identity (${identityAddress}) is itself a SimpleLogin alias. Reverse-alias sending has to leave from a real mailbox, so pick your normal identity in the From dropdown.`,
    );
    return { cancel: true };
  }
  // Snap the From field back to the identity when the user typed an alias into it.
  //
  // Two constraints meet here. Proton (via the hydroxide bridge) rejects any sender address the
  // account does not own - "transaction failed: unknown sender address" - so an alias must not be
  // left in From. But writing `from` to fix that calls Thunderbird's MakeFromFieldEditable(), which
  // throws on a null selectedItem and aborts the send outright.
  //
  // Setting identityId takes a different path: it assigns identityElement.selectedItem and calls
  // LoadIdentity(), which resets the From field and restores a valid selection without going near
  // setFromField. Only done when From actually differs, since LoadIdentity() re-applies the
  // identity's signature and is not worth running for nothing.
  if (identityAddress && typed.address && typed.address !== identityAddress) {
    result.patch.identityId = details.identityId;
  }


  // onAfterSend repairs the filed copy once Thunderbird has written it.
  rememberSentRewrite(tab.id, { originals: result.originals, aliasEmail: alias.email });

  await render(tab.id, {
    ...status, state: "created", alias, label: "Sent as alias",
    detail: `${result.rewritten} recipient(s) routed through ${alias.email}.`,
  });

  return { details: result.patch };
}));

// Original recipients per compose tab, captured in onBeforeSend for onAfterSend. Deliberately not
// cleared when a tab closes — sending closes the window, and racing that teardown would drop the
// entry onAfterSend is about to need. Bounded instead, so abandoned drafts can't pile up.
const pendingSentRewrite = new Map();
const MAX_PENDING_REWRITES = 50;

function rememberSentRewrite(tabId, entry) {
  pendingSentRewrite.set(tabId, entry);
  while (pendingSentRewrite.size > MAX_PENDING_REWRITES) {
    // Insertion order, so this drops the oldest.
    pendingSentRewrite.delete(pendingSentRewrite.keys().next().value);
  }
}

// Optional permissions, granted from the options page.
const REWRITE_PERMISSIONS = { permissions: ["messagesImport", "messagesDelete"] };

safeListen("compose.onAfterSend", () => browser.compose.onAfterSend.addListener(async (tab, sendInfo) => {
  const pending = pendingSentRewrite.get(tab.id);
  pendingSentRewrite.delete(tab.id);

  if (!pending || sendInfo.error) return;

  const settings = await SLPrefs.getSettings();
  if (!settings.restoreSentRecipients) return;

  if (!(await browser.permissions.contains(REWRITE_PERMISSIONS))) {
    await notify(
      "Sent copy left as-is",
      "Restoring the real recipients needs the message import and delete permissions. Grant them from the add-on's options.",
    );
    return;
  }

  const messages = sendInfo.messages || [];
  if (!messages.length) return;

  for (const message of messages) {
    try {
      await SLMessages.restoreSentRecipients(message.id, pending.originals);
    } catch (e) {
      // The message was sent; only the filed copy is imperfect. Don't retry against mail we may
      // have half-rewritten.
      await notify(
        "Sent copy left as-is",
        `${pending.aliasEmail} was sent correctly, but the copy in Sent still shows reverse-aliases: ${e.message}`,
      );
      return;
    }
  }
}));

const messageInfoByTab = new Map();

async function evaluateMessage(tabId) {
  const settings = await SLPrefs.getSettings();
  const paint = (text, colour, title) =>
    Promise.all([
      browser.messageDisplayAction.setBadgeText({ tabId, text }),
      browser.messageDisplayAction.setBadgeBackgroundColor({ tabId, color: colour }),
      browser.messageDisplayAction.setTitle({ tabId, title }),
    ]).catch(() => {/* tab closed */});

  if (!settings.apiKey) return null;
  // Withheld along with its permission; the panel explains that rather than showing a raw error.
  if (!browser.messageDisplay) return null;

  const list = await browser.messageDisplay.getDisplayedMessages(tabId).catch(() => null);
  const message = list?.messages?.[0];
  if (!message) {
    messageInfoByTab.delete(tabId);
    await paint("", null, "SimpleLogin");
    return null;
  }

  const { snapshot } = await SLStore.getSnapshot();
  const hit = await SLMessages.aliasForMessage(message.id, snapshot?.aliases);
  const info = { messageId: message.id, alias: hit?.alias || null, via: hit?.via || null };
  messageInfoByTab.set(tabId, info);

  if (!hit) {
    await paint("", null, "SimpleLogin - this message did not arrive at an alias");
  } else if (hit.alias.enabled) {
    await paint("✓", "#2ea043", `SimpleLogin\nArrived at ${hit.alias.email}`);
  } else {
    await paint("off", "#d29922", `SimpleLogin\nArrived at ${hit.alias.email}, which is disabled`);
  }
  return info;
}

safeListen("messageDisplay.onMessagesDisplayed", () =>
  browser.messageDisplay.onMessagesDisplayed.addListener((tab) => evaluateMessage(tab.id)));

safeListen("compose.onIdentityChanged", () =>
  browser.compose.onIdentityChanged.addListener((tab) => evaluate(tab.id, { recheck: true })));

safeListen("tabs.onRemoved", () => browser.tabs.onRemoved.addListener((tabId) => {
  statusByTab.delete(tabId);
  messageInfoByTab.delete(tabId);
  autoAliasHandled.delete(tabId);
  autoAliasNotice.delete(tabId);
  selectedAliasByTab.delete(tabId);
}));

const HANDLERS = {
  // Liveness probe. Also carries whatever failed to wire up at load, so a panel can report a
  // half-working add-on instead of a blank one.
  async "sl:ping"() {
    return { ok: true, startupProblems, missing: await missingPermissions() };
  },

  async "sl:tick"(_msg, sender) {
    if (!sender.tab) return null;
    lastComposeTabId = sender.tab.id;
    return evaluate(sender.tab.id);
  },

  // One round trip for a full popup render.
  async "sl:context"({ tabId }) {
    const id = tabId ?? lastComposeTabId;
    const status = id != null ? await evaluate(id) : null;
    const { snapshot, error, settings } = await SLStore.getSnapshot();
    return { tabId: id, status, snapshot, error, settings, startupProblems, missing: await missingPermissions() };
  },

  async "sl:refresh"({ tabId }) {
    const { snapshot, error } = await SLStore.getSnapshot({ force: true });
    const status = tabId != null ? await evaluate(tabId, { recheck: true }) : null;
    return { snapshot, error, status };
  },

  async "sl:apply"({ tabId, email }) {
    const result = await applyAliasToTab(tabId, email);
    return { ...result, status: await evaluate(tabId, { recheck: true }) };
  },

  // Without waiting for send.
  async "sl:create-current"({ tabId }) {
    const settings = await SLPrefs.getSettings();
    const status = statusByTab.get(tabId) || (await evaluate(tabId, { recheck: true }));
    if (!status || !SLClassify.isCreatable(status.state)) {
      return { ok: false, error: "The current From address is not creatable." };
    }

    const details = await browser.compose.getComposeDetails(tabId);
    await render(tabId, { ...status, state: "creating", label: "Creating", detail: `Creating ${status.address}...` });
    try {
      const alias = await createFromCandidate(status.candidate, settings, hostnameHint(details));
      return { ok: true, alias, status: await evaluate(tabId, { recheck: true }) };
    } catch (e) {
      await render(tabId, { ...status, state: "error", label: "Failed", detail: e.message });
      return { ok: false, error: e.message };
    }
  },

  async "sl:create"({ tabId, prefix, suffix, mailboxIds, note, name }) {
    const settings = await SLPrefs.getSettings();
    const details = tabId != null ? await browser.compose.getComposeDetails(tabId).catch(() => ({})) : {};
    try {
      const alias = await createFromCandidate(
        { prefix, suffix: { suffix }, name: name || "" },
        { ...settings, defaultMailboxIds: mailboxIds ?? settings.defaultMailboxIds, aliasNote: note ?? settings.aliasNote },
        hostnameHint(details),
      );
      return { ok: true, alias };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  // A throwaway, applied straight to the window.
  async "sl:create-random"({ tabId, mode }) {
    const settings = await SLPrefs.getSettings();
    const details = tabId != null ? await browser.compose.getComposeDetails(tabId).catch(() => ({})) : {};
    try {
      const alias = await SLApi.createRandomAlias(settings.apiKey, {
        mode: mode || "word",
        note: settings.aliasNote,
        hostname: hostnameHint(details),
      });
      await SLStore.addAlias(alias);
      if (tabId != null) await applyAliasToTab(tabId, alias.email);
      return { ok: true, alias, status: tabId != null ? await evaluate(tabId, { recheck: true }) : null };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  async "sl:toggle-alias"({ aliasId, tabId }) {
    const settings = await SLPrefs.getSettings();
    try {
      const res = await SLApi.toggleAlias(settings.apiKey, aliasId);
      await SLStore.patchAlias(aliasId, { enabled: res.enabled });
      if (tabId != null) await evaluate(tabId, { recheck: true });
      return { ok: true, enabled: res.enabled };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  // Irreversible; mail to the address bounces afterwards.
  async "sl:delete-alias"({ aliasId, tabId }) {
    const settings = await SLPrefs.getSettings();
    try {
      await SLApi.deleteAlias(settings.apiKey, aliasId);
      await SLStore.removeAlias(aliasId);
      if (tabId != null) await evaluate(tabId, { recheck: true });
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  async "sl:update-alias"({ aliasId, patch, tabId }) {
    const settings = await SLPrefs.getSettings();
    try {
      await SLApi.updateAlias(settings.apiKey, aliasId, patch);
      await SLStore.patchAlias(aliasId, patch);
      if (tabId != null) await evaluate(tabId, { recheck: true });
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  async "sl:message-context"({ tabId }) {
    const settings = await SLPrefs.getSettings();
    const info = (await evaluateMessage(tabId)) || messageInfoByTab.get(tabId) || null;
    const sender = info?.messageId != null ? await SLMessages.senderInfo(info.messageId) : null;

    // Without a reverse-alias to match, this is a paginated fetch for nothing.
    let contact = null;
    if (info?.alias && sender?.reverseAlias) {
      try {
        const { items } = await SLApi.listContacts(settings.apiKey, info.alias.id);
        contact = items.find(
          (c) => SLClassify.parseAddress(c.reverse_alias_address) === sender.reverseAlias,
        ) || null;
      } catch {
        /* the panel still works without the block button */
      }
    }

    return { tabId, info, sender, contact, settings, startupProblems, missing: await missingPermissions() };
  },

  // Per-contact: doesn't disturb the rest of the alias's traffic.
  async "sl:toggle-contact"({ contactId }) {
    const settings = await SLPrefs.getSettings();
    try {
      const res = await SLApi.toggleContact(settings.apiKey, contactId);
      return { ok: true, blocked: res.block_forward };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  async "sl:rewrite-permission"({ request }) {
    if (request) {
      // permissions.request() needs a user gesture, which the options page checkbox provides.
      const granted = await browser.permissions.request(REWRITE_PERMISSIONS).catch(() => false);
      return { granted };
    }
    return { granted: await browser.permissions.contains(REWRITE_PERMISSIONS) };
  },

  async "sl:test-key"({ apiKey }) {
    try {
      const user = await SLApi.userInfo(apiKey);
      return { ok: true, user };
    } catch (e) {
      return { ok: false, error: e.message };
    }
  },

  // For the cleanup button; only ever lists identities this add-on created.
  async "sl:list-identities"() {
    const { createdIdentityIds } = await SLPrefs.getState();
    const identities = [];
    for (const id of createdIdentityIds) {
      const identity = await browser.identities.get(id).catch(() => null);
      if (identity) identities.push(identity);
    }
    return { identities };
  },

  async "sl:delete-identity"({ identityId }) {
    const { createdIdentityIds } = await SLPrefs.getState();
    if (!createdIdentityIds.includes(identityId)) {
      return { ok: false, error: "That identity was not created by this add-on." };
    }
    try {
      await browser.identities.delete(identityId);
    } catch (e) {
      return { ok: false, error: e.message };
    }
    await SLPrefs.setState({ createdIdentityIds: createdIdentityIds.filter((i) => i !== identityId) });
    return { ok: true };
  },
};

// A settings change can flip every open window's verdict, so repaint them all. A change to `cache`
// alone is ignored: evaluate() writes the cache, so acting on it would loop back into evaluate().
safeListen("storage.onChanged", () => browser.storage.onChanged.addListener((changes, area) => {
  const keys = Object.keys(changes);
  if (area !== "local" || keys.every((key) => key === "cache")) return;
  for (const tabId of statusByTab.keys()) evaluate(tabId, { recheck: true });
}));
