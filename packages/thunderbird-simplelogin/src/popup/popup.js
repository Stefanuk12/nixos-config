"use strict";

// The compose-window panel. Every decision is made in the background page; this only renders the
// answer and sends intents back, so the badge and the panel can't disagree.
(() => {
  const $ = (id) => document.getElementById(id);
  const send = (type, payload = {}) => browser.runtime.sendMessage({ type, ...payload });

  // Populated once per open, then patched in place as actions complete.
  let ctx = { tabId: null, status: null, snapshot: null, settings: null };

  // Just the words; the banner's colour comes from a `state-*` class.
  const PILL = {
    "no-key": "Setup",
    stale: "No data",
    loading: "…",
    "not-alias": "Not an alias",
    alias: "Alias",
    "alias-disabled": "Disabled",
    "will-create": "Will create",
    "can-create": "Creatable",
    "cannot-create": "Blocked",
    creating: "Creating…",
    created: "Created",
    error: "Error",
  };

  function showNotice(message, kind = "error") {
    const el = $("notice");
    el.textContent = message;
    el.className = `notice ${kind === "info" ? "info" : ""}`;
    el.hidden = !message;
  }

  function renderBanner() {
    const status = ctx.status;
    const state = status?.state || "loading";
    const banner = $("banner");

    banner.className = `banner state-${state}`;
    $("banner-pill").textContent = PILL[state] || state;
    $("banner-address").textContent = status?.address || "(no From address)";
    $("banner-detail").textContent = status?.detail || "";

    // The badge only carries three characters, so the full send-time promise lives here.
    $("banner-plan").textContent = planText(status, ctx.settings);

    const actions = $("banner-actions");
    actions.replaceChildren();

    if (state === "no-key") {
      actions.append(button("Open options", "primary", () => browser.runtime.openOptionsPage()));
    }
    if (SLClassify.isCreatable(state)) {
      actions.append(button(`Create ${status.address} now`, "primary", createCurrent));
    }
    if (state === "error" || state === "stale") {
      actions.append(button("Retry", "primary", refresh));
    }
    // Stops a second alias being made for a site that already has one.
    if (status?.suggestion) {
      actions.append(button(`Use ${status.suggestion.alias}`, "primary", () => apply(status.suggestion.alias)));
    }
    actions.hidden = !actions.childElementCount;
  }

  function planText(status, settings) {
    if (!status || !settings) return "";
    const reverse = settings.sendMode === "reverse-alias";

    // First: the one case where the compose window shows an address nobody typed.
    const prefix = status.autoApplied ? `${status.autoApplied} ` : "";
    return prefix + sendPlan(status, reverse);
  }

  function sendPlan(status, reverse) {
    switch (status.state) {
      case "will-create":
        return reverse
          ? "On send: the alias is created, recipients are swapped for its reverse-aliases, and From returns to your mailbox."
          : "On send: the alias is created and a Thunderbird identity for it is used to send.";
      case "alias":
      case "created":
        return reverse
          ? "On send: recipients are swapped for this alias's reverse-aliases, and From returns to your mailbox."
          : "On send: a Thunderbird identity for this alias is used to send.";
      case "alias-disabled":
        return "This alias is disabled - re-enable it in SimpleLogin or replies will be dropped.";
      case "can-create":
        return "Auto-create on send is off, so nothing is created until you press the button above.";
      default:
        return "";
    }
  }

  function button(label, className, onClick) {
    const el = document.createElement("button");
    el.textContent = label;
    el.className = className;
    el.addEventListener("click", onClick);
    return el;
  }

  function renderAliases() {
    const list = $("aliases");
    const aliases = ctx.snapshot?.aliases || [];
    const needle = $("search").value.trim().toLowerCase();
    const current = ctx.status?.address;

    const matches = needle
      ? aliases.filter((a) =>
          `${a.email} ${a.name || ""} ${a.note || ""}`.toLowerCase().includes(needle))
      : aliases;

    list.replaceChildren(...matches.map((alias) => row(alias, current)));

    const empty = $("empty");
    if (matches.length) {
      empty.hidden = true;
    } else {
      empty.hidden = false;
      empty.textContent = aliases.length
        ? "No alias matches that filter."
        : "No aliases on this account yet.";
    }

    // Never imply the list is complete when it isn't.
    if (ctx.snapshot?.truncated) {
      showNotice(`Showing the first ${aliases.length} aliases; the account has more.`, "info");
    }
  }

  function row(alias, current) {
    const li = document.createElement("li");
    li.className = "alias-row";
    if (current && alias.email.toLowerCase() === current) li.classList.add("current");

    const top = document.createElement("div");
    top.className = "alias-top";

    const main = document.createElement("div");
    main.className = "alias-main";

    const email = document.createElement("div");
    email.className = `alias-email${alias.enabled ? "" : " off"}`;
    email.textContent = alias.email;

    const meta = document.createElement("div");
    meta.className = "alias-meta";
    meta.textContent = [
      alias.name || alias.note || "",
      `${alias.nb_forward} fwd`,
      `${alias.nb_reply} reply`,
      `${alias.nb_block} blocked`,
      (alias.mailboxes || []).map((m) => m.email).join(", "),
    ].filter(Boolean).join(" · ");

    main.append(email, meta);

    // Behind a disclosure: the list is mostly used for picking, and a Delete button on every row
    // is a hazard.
    const tools = buildTools(alias);
    const more = button("⋯", "ghost more", () => {
      tools.hidden = !tools.hidden;
      more.setAttribute("aria-expanded", String(!tools.hidden));
    });
    more.title = "Manage this alias";
    more.setAttribute("aria-expanded", "false");

    top.append(main, button("Use", "ghost", () => apply(alias.email)), more);
    li.append(top, tools);
    return li;
  }

  function buildTools(alias) {
    const tools = document.createElement("div");
    tools.className = "alias-tools";
    tools.hidden = true;

    const name = document.createElement("input");
    name.type = "text";
    name.value = alias.name || "";
    name.placeholder = "Display name";

    const note = document.createElement("input");
    note.type = "text";
    note.value = alias.note || "";
    note.placeholder = "Note";

    const save = button("Save", "", (e) =>
      run(e.target, () => send("sl:update-alias", {
        tabId: ctx.tabId,
        aliasId: alias.id,
        patch: { name: name.value.trim() || null, note: note.value.trim() },
      })));

    const toggle = button(alias.enabled ? "Disable" : "Enable", "", (e) =>
      run(e.target, () => send("sl:toggle-alias", { tabId: ctx.tabId, aliasId: alias.id })));

    const remove = button("Delete", "danger", (e) => {
      if (!window.confirm(`Delete ${alias.email}?\n\nThis cannot be undone and mail sent to it will bounce afterwards. Disabling is reversible.`)) return;
      run(e.target, () => send("sl:delete-alias", { tabId: ctx.tabId, aliasId: alias.id }));
    });

    tools.append(name, note, save, toggle, remove);
    return tools;
  }

  // Re-renders from whatever the server settled on.
  async function run(el, work) {
    showNotice("");
    el.disabled = true;
    const res = await work();
    if (!res?.ok) {
      showNotice(res?.error || "That did not work.");
      el.disabled = false;
      return;
    }
    await load();
  }

  function renderCreateForm() {
    const suffixes = ctx.snapshot?.options?.suffixes || [];
    const premium = ctx.snapshot?.isPremium !== false;

    const suffixSelect = $("new-suffix");
    suffixSelect.replaceChildren(
      ...suffixes
        .filter((s) => premium || !s.is_premium)
        .map((s) => new Option(s.suffix, s.suffix)),
    );

    const mailboxSelect = $("new-mailbox");
    mailboxSelect.replaceChildren(
      ...(ctx.snapshot?.mailboxes || []).map((m) => {
        const option = new Option(m.email + (m.default ? " (default)" : ""), String(m.id));
        option.selected = ctx.settings?.defaultMailboxIds?.length
          ? ctx.settings.defaultMailboxIds.includes(m.id)
          : Boolean(m.default);
        return option;
      }),
    );

    if (!$("new-note").value) $("new-note").value = ctx.settings?.aliasNote || "";
    if (!$("new-prefix").value) {
      $("new-prefix").value = ctx.snapshot?.options?.prefix_suggestion || "";
    }
    // Seeded from the From field, so the form agrees with what create-on-send would have done.
    if (!$("new-name").value) $("new-name").value = ctx.status?.displayName || "";
    renderPreview();
  }

  function renderPreview() {
    const prefix = $("new-prefix").value.trim().toLowerCase();
    const suffix = $("new-suffix").value;
    const name = $("new-name").value.trim();
    const preview = $("create-preview");
    const valid = prefix && SLClassify.PREFIX_RE.test(prefix) && suffix;

    // Rendered as the recipient will see it, so an unintended display name shows up before the
    // alias is created.
    preview.textContent = prefix
      ? valid
        ? name ? `${name} <${prefix}${suffix}>` : `${prefix}${suffix}`
        : "Prefix may only contain a-z, 0-9, dot, dash and underscore."
      : "";
    preview.classList.toggle("invalid", Boolean(prefix) && !valid);
    $("create-submit").disabled = !valid;
  }

  async function apply(email) {
    showNotice("");
    const res = await send("sl:apply", { tabId: ctx.tabId, email });
    if (res?.warning) {
      showNotice(`From was set, but no identity was created: ${res.warning}`, "info");
    }
    if (res?.status) ctx.status = res.status;
    renderBanner();
    renderAliases();
  }

  async function createCurrent() {
    showNotice("");
    ctx.status = { ...ctx.status, state: "creating", detail: "Talking to SimpleLogin…" };
    renderBanner();

    const res = await send("sl:create-current", { tabId: ctx.tabId });
    if (!res?.ok) {
      showNotice(res?.error || "Could not create the alias.");
      await load();
      return;
    }
    await load();
  }

  async function createFromForm() {
    showNotice("");
    $("create-submit").disabled = true;

    const mailboxIds = [...$("new-mailbox").selectedOptions].map((o) => Number(o.value));
    const res = await send("sl:create", {
      tabId: ctx.tabId,
      prefix: $("new-prefix").value.trim().toLowerCase(),
      suffix: $("new-suffix").value,
      mailboxIds,
      note: $("new-note").value.trim(),
      name: $("new-name").value.trim(),
    });

    if (!res?.ok) {
      showNotice(res?.error || "Could not create the alias.");
      $("create-submit").disabled = false;
      return;
    }

    await apply(res.alias.email);
    await refresh();
    $("create-box").open = false;
    $("new-prefix").value = "";
    $("new-name").value = "";
  }

  async function refresh() {
    showNotice("");
    const res = await send("sl:refresh", { tabId: ctx.tabId });
    if (res?.error) showNotice(res.error.message);
    if (res?.snapshot) ctx.snapshot = res.snapshot;
    if (res?.status) ctx.status = res.status;
    renderAll();
  }

  function renderAll() {
    renderBanner();
    renderAliases();
    renderCreateForm();
    $("synced").textContent = ctx.snapshot?.fetchedAt
      ? `Synced ${new Date(ctx.snapshot.fetchedAt).toLocaleTimeString()}`
      : "Not synced";
  }

  async function load() {
    // A popup owned by a compose window doesn't always turn up in a tabs.query, hence the
    // background page's last-seen tab as a fallback.
    let tabId = null;
    try {
      const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
      tabId = tab?.id ?? null;
    } catch {
      /* fall back to the background page's view */
    }

    const res = await send("sl:context", { tabId });
    ctx = { ...ctx, ...res, tabId: res.tabId ?? tabId };
    if (res?.error) showNotice(res.error.message);
    renderAll();
  }

  async function createRandom(e) {
    showNotice("");
    e.target.disabled = true;
    const res = await send("sl:create-random", { tabId: ctx.tabId, mode: "word" });
    e.target.disabled = false;
    if (!res?.ok) return showNotice(res?.error || "Could not create a random alias.");
    showNotice(`Created ${res.alias.email} and set it as From.`, "info");
    await refresh();
  }

  $("search").addEventListener("input", renderAliases);
  $("random").addEventListener("click", createRandom);
  $("refresh").addEventListener("click", refresh);
  $("new-prefix").addEventListener("input", renderPreview);
  $("new-name").addEventListener("input", renderPreview);
  $("new-suffix").addEventListener("change", renderPreview);
  $("create-submit").addEventListener("click", createFromForm);
  $("open-options").addEventListener("click", () => browser.runtime.openOptionsPage());

  load();
})();
