"use strict";

// The message-reading panel: which alias did this arrive at, and what can be done about it
// without opening the SimpleLogin website.
(() => {
  const $ = (id) => document.getElementById(id);

  // SLIpc retries while the suspended event page restarts, and always resolves - a total failure
  // arrives as { ok: false, unreachable: true } rather than null, so no caller can leave the panel
  // frozen on the markup's placeholder text.
  const send = (type, payload = {}) => SLIpc.send(type, payload);

  let ctx = { tabId: null, info: null, sender: null, contact: null, settings: null };

  // A permission declared in the manifest but never granted means its whole API namespace is
  // undefined. Thunderbird only re-evaluates the granted set on a version change, so the fix is an
  // upgrade plus a restart - not something the user could guess from "browser.X is undefined".
  const permissionAdvice = (missing) =>
    `Thunderbird has not granted this add-on: ${missing.join(", ")}. Restart Thunderbird to pick up the update; if that does not clear it, remove and re-add the add-on.`;

  function showNotice(message, kind = "error") {
    const el = $("notice");
    el.textContent = message;
    el.className = `notice ${kind === "info" ? "info" : ""}`;
    el.hidden = !message;
  }

  function button(label, className, onClick) {
    const el = document.createElement("button");
    el.textContent = label;
    el.className = className;
    el.addEventListener("click", onClick);
    return el;
  }

  // Keeps the button disabled until the action settles.
  async function act(el, work, { confirm: needsConfirm = null } = {}) {
    if (needsConfirm && !window.confirm(needsConfirm)) return;
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

  function render() {
    const alias = ctx.info?.alias;
    const banner = $("banner");

    if (!ctx.settings?.apiKey) {
      banner.className = "banner state-no-key";
      $("banner-pill").textContent = "Setup";
      $("banner-address").textContent = "No API key";
      $("banner-detail").textContent = "Add your SimpleLogin API key in the add-on options.";
      $("facts").hidden = true;
      $("actions").hidden = true;
      $("edit-box").hidden = true;
      return;
    }

    // Without messagesRead this panel cannot see the message at all, so lead with that rather
    // than reporting the resulting blank as "not an alias".
    if (ctx.missing?.length) {
      banner.className = "banner state-error";
      $("banner-pill").textContent = "Permission";
      $("banner-address").textContent = "Cannot read messages";
      $("banner-detail").textContent = permissionAdvice(ctx.missing);
      $("facts").hidden = true;
      $("actions").hidden = true;
      $("edit-box").hidden = true;
      return;
    }

    if (!alias) {
      banner.className = "banner state-not-alias";
      $("banner-pill").textContent = "Not an alias";
      $("banner-address").textContent = "";
      $("banner-detail").textContent =
        "This message did not arrive at one of your SimpleLogin aliases. If you expected it to, refresh the alias list from the compose panel - a newly created alias will not be recognised until then.";
      $("facts").hidden = true;
      $("actions").hidden = true;
      $("edit-box").hidden = true;
      return;
    }

    banner.className = `banner state-${alias.enabled ? "alias" : "alias-disabled"}`;
    $("banner-pill").textContent = alias.enabled ? "Alias" : "Disabled";
    $("banner-address").textContent = alias.email;
    $("banner-detail").textContent = alias.enabled
      ? "This message was delivered to that alias."
      : "This alias is disabled: SimpleLogin is dropping new mail sent to it.";

    // An alias inferred from an ordinary header rather than SimpleLogin's own stamp can be wrong.
    if (ctx.info.via && ctx.info.via !== "x-simplelogin-envelope-to") {
      showNotice(`Matched on the ${ctx.info.via} header rather than SimpleLogin's own, so this is a best guess.`, "info");
    }

    $("facts").hidden = false;
    $("fact-sender").textContent = ctx.sender?.display || "(unknown)";
    $("fact-activity").textContent =
      `${alias.nb_forward} forwarded · ${alias.nb_reply} replies · ${alias.nb_block} blocked`;
    $("fact-mailboxes").textContent = (alias.mailboxes || []).map((m) => m.email).join(", ") || "(default)";

    renderActions(alias);

    $("edit-box").hidden = false;
    $("edit-name").value = alias.name || "";
    $("edit-note").value = alias.note || "";
  }

  function renderActions(alias) {
    const actions = $("actions");
    actions.hidden = false;
    actions.replaceChildren();

    actions.append(
      button(alias.enabled ? "Disable alias" : "Enable alias", "", (e) =>
        act(e.target, () => send("sl:toggle-alias", { aliasId: alias.id }))),
    );

    // Blocking needs the contact SimpleLogin minted for this sender; without a reverse-alias in
    // From there's nothing to match it to.
    if (ctx.contact) {
      const blocked = ctx.contact.block_forward;
      actions.append(
        button(blocked ? "Unblock sender" : "Block sender", "", (e) =>
          act(e.target, () => send("sl:toggle-contact", { contactId: ctx.contact.id }))),
      );
    }

    actions.append(
      button("Delete alias", "danger", (e) =>
        act(e.target, () => send("sl:delete-alias", { aliasId: alias.id }), {
          confirm: `Delete ${alias.email}?\n\nThis cannot be undone, and mail sent to it afterwards will bounce. Disabling it instead is reversible.`,
        })),
    );

    $("footer-note").textContent = ctx.contact?.block_forward ? "Sender blocked" : "";
  }

  async function saveEdits(e) {
    const alias = ctx.info?.alias;
    if (!alias) return;
    await act(e.target, () =>
      send("sl:update-alias", {
        aliasId: alias.id,
        patch: { name: $("edit-name").value.trim() || null, note: $("edit-note").value.trim() },
      }));
  }

  async function load() {
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true }).catch(() => []);
    const res = await send("sl:message-context", { tabId: tab?.id ?? null });
    if (res.unreachable) return renderUnreachable(res.error);
    ctx = { ...ctx, ...res };
    render();
    if (res.missing?.length) showNotice(permissionAdvice(res.missing));
    else if (res.startupProblems?.length) {
      showNotice(`Some features did not start: ${res.startupProblems.join("; ")}`);
    }
  }

  function renderUnreachable(detail) {
    $("banner").className = "banner state-error";
    $("banner-pill").textContent = "Error";
    $("banner-address").textContent = "Add-on error";
    $("banner-detail").textContent = detail;
    $("facts").hidden = true;
    $("actions").hidden = true;
    $("edit-box").hidden = true;
  }

  $("edit-save").addEventListener("click", saveEdits);
  $("open-options").addEventListener("click", () => browser.runtime.openOptionsPage());

  load();
})();
