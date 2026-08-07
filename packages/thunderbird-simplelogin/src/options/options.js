"use strict";

// Saves on change rather than behind a Save button: every field is independent, and the background
// page repaints open compose windows from storage.onChanged.
(() => {
  const $ = (id) => document.getElementById(id);
  const send = (type, payload = {}) => SLIpc.send(type, payload);

  const CHECKBOXES = [
    "autoCreateOnSend", "strictRewrite", "expandMailingLists",
    "autoAliasOnReply", "suggestByRecipient",
  ];
  const TEXTS = ["aliasNote"];

  let savedTimer = null;

  function flashSaved() {
    const el = $("saved");
    el.hidden = false;
    clearTimeout(savedTimer);
    savedTimer = setTimeout(() => { el.hidden = true; }, 1200);
  }

  async function save(patch) {
    await SLPrefs.setSettings(patch);
    flashSaved();
  }

  function setStatus(message, kind = "") {
    const el = $("account-status");
    el.textContent = message;
    el.className = `status ${kind}`;
  }

  // From the cached snapshot, so opening this page costs no network call; the popup's Refresh is
  // what keeps it current.
  async function renderMailboxes(selectedIds) {
    const cache = await SLPrefs.getCache();
    const select = $("defaultMailboxIds");
    const mailboxes = cache?.mailboxes || [];

    if (!mailboxes.length) {
      select.replaceChildren(new Option("Test your API key to load mailboxes", "", true, true));
      select.disabled = true;
      return;
    }

    select.disabled = false;
    select.replaceChildren(
      ...mailboxes.map((m) => {
        const option = new Option(m.email + (m.default ? " (default)" : ""), String(m.id));
        option.selected = selectedIds.includes(m.id);
        return option;
      }),
    );
  }

  async function renderIdentities(sendMode) {
    $("identities-section").hidden = sendMode !== "identity";
    if (sendMode !== "identity") return;

    const res = await send("sl:list-identities");
    const identities = res?.identities || [];
    const list = $("identities");

    if (!identities.length) {
      const li = document.createElement("li");
      li.textContent = "None yet.";
      list.replaceChildren(li);
      return;
    }

    list.replaceChildren(...identities.map((identity) => {
      const li = document.createElement("li");
      const label = document.createElement("span");
      label.textContent = identity.email;

      const remove = document.createElement("button");
      remove.textContent = "Remove";
      remove.className = "danger";
      remove.addEventListener("click", async () => {
        remove.disabled = true;
        const res = await send("sl:delete-identity", { identityId: identity.id });
        if (!res.ok) {
          remove.disabled = false;
          setStatus(res.error, "bad");
          return;
        }
        await renderIdentities(sendMode);
      });

      li.append(label, remove);
      return li;
    }));
  }

  // The setting can be on while the permissions are missing (revoked later, or a profile copied
  // between machines), and silently doing nothing would be worse than saying so.
  async function renderRewritePermission(enabled) {
    const status = $("rewrite-permission");
    if (!enabled) {
      status.textContent = "";
      status.className = "status";
      return;
    }
    const { granted } = await send("sl:rewrite-permission", { request: false });
    status.textContent = granted
      ? "Permissions granted."
      : "Waiting on the message import and delete permissions — untick and retick to be asked again.";
    status.className = `status ${granted ? "ok" : "bad"}`;
  }

  async function onRestoreSentChanged(e) {
    const wanted = e.target.checked;

    // Only from this click: permissions.request is rejected outside a user gesture.
    if (wanted) {
      const { granted } = await send("sl:rewrite-permission", { request: true });
      if (!granted) {
        e.target.checked = false;
        await save({ restoreSentRecipients: false });
        await renderRewritePermission(false);
        setStatus("Sent-folder repair needs the message import and delete permissions.", "bad");
        return;
      }
    }

    await save({ restoreSentRecipients: wanted });
    await renderRewritePermission(wanted);
  }

  async function load() {
    const settings = await SLPrefs.getSettings();

    $("apiKey").value = settings.apiKey;
    $("apiKey").readOnly = settings.apiKeyIsManaged;
    $("managed-note").hidden = !settings.apiKeyIsManaged;
    for (const id of CHECKBOXES) $(id).checked = settings[id];
    for (const id of TEXTS) $(id).value = settings[id];
    $("restoreSentRecipients").checked = settings.restoreSentRecipients;
    await renderRewritePermission(settings.restoreSentRecipients);
    $("pollIntervalMs").value = settings.pollIntervalMs;
    $("cacheTtlSec").value = Math.round(settings.cacheTtlMs / 1000);

    const radio = document.querySelector(`input[name="sendMode"][value="${settings.sendMode}"]`);
    if (radio) radio.checked = true;

    await renderMailboxes(settings.defaultMailboxIds);
    await renderIdentities(settings.sendMode);
  }

  $("restoreSentRecipients").addEventListener("change", onRestoreSentChanged);

  $("apiKey").addEventListener("change", async (e) => {
    if (e.target.readOnly) return;
    await save({ apiKey: e.target.value.trim() });
    setStatus("");
  });

  $("reveal").addEventListener("click", () => {
    const input = $("apiKey");
    const hidden = input.type === "password";
    input.type = hidden ? "text" : "password";
    $("reveal").textContent = hidden ? "Hide" : "Show";
  });

  $("test").addEventListener("click", async () => {
    const apiKey = $("apiKey").value.trim();
    if (!apiKey) return setStatus("Enter a key first.", "bad");

    setStatus("Checking…");
    // Save first, so a successful check populates the mailbox list from the same key the rest of
    // the add-on will use.
    await save({ apiKey });
    const res = await send("sl:test-key", { apiKey });

    if (!res.ok) return setStatus(res.error, "bad");
    const plan = res.user.is_premium ? "premium" : res.user.in_trial ? "trial" : "free";
    setStatus(`Connected as ${res.user.email} (${plan}).`, "ok");

    // So mailboxes and suffixes are available here and in the panel without a compose window.
    await send("sl:refresh", {});
    const settings = await SLPrefs.getSettings();
    await renderMailboxes(settings.defaultMailboxIds);
  });

  for (const id of CHECKBOXES) {
    $(id).addEventListener("change", (e) => save({ [id]: e.target.checked }));
  }
  for (const id of TEXTS) {
    $(id).addEventListener("change", (e) => save({ [id]: e.target.value }));
  }

  for (const radio of document.querySelectorAll('input[name="sendMode"]')) {
    radio.addEventListener("change", async (e) => {
      if (!e.target.checked) return;
      await save({ sendMode: e.target.value });
      await renderIdentities(e.target.value);
    });
  }

  $("defaultMailboxIds").addEventListener("change", (e) => {
    save({ defaultMailboxIds: [...e.target.selectedOptions].map((o) => Number(o.value)) });
  });

  $("pollIntervalMs").addEventListener("change", (e) => {
    const value = Math.max(250, Number(e.target.value) || SLPrefs.DEFAULTS.pollIntervalMs);
    e.target.value = value;
    save({ pollIntervalMs: value });
  });

  $("cacheTtlSec").addEventListener("change", (e) => {
    const seconds = Math.max(10, Number(e.target.value) || SLPrefs.DEFAULTS.cacheTtlMs / 1000);
    e.target.value = seconds;
    save({ cacheTtlMs: seconds * 1000 });
  });

  load();
})();
