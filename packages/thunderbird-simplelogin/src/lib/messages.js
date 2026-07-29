"use strict";

// Reading stored mail: working out which alias a message arrived at, and putting
// the real recipients back into the copy saved in Sent.
globalThis.SLMessages = (() => {
  // getFull() returns headers keyed by name, but the casing isn't reliable, and a miss here would
  // silently read as "this message did not come from SimpleLogin".
  function headerValues(headers, name) {
    if (!headers) return [];
    const wanted = name.toLowerCase();
    for (const [key, values] of Object.entries(headers)) {
      if (key.toLowerCase() === wanted) return Array.isArray(values) ? values : [values];
    }
    return [];
  }

  // Best source first: X-SimpleLogin-Envelope-To is stamped by SimpleLogin and names the alias
  // outright; the rest are fallbacks for mail routed differently or filed before it existed.
  const ALIAS_HEADERS = ["x-simplelogin-envelope-to", "delivered-to", "x-original-to", "to", "cc"];

  async function aliasForMessage(messageId, aliases) {
    const full = await browser.messages.getFull(messageId).catch(() => null);
    if (!full) return null;

    const byEmail = new Map((aliases || []).map((a) => [String(a.email).toLowerCase(), a]));

    for (const name of ALIAS_HEADERS) {
      for (const value of headerValues(full.headers, name)) {
        for (const address of SLClassify.parseAddressList(value)) {
          const alias = byEmail.get(address);
          if (alias) return { alias, via: name };
        }
      }
    }
    return null;
  }

  // SimpleLogin rewrites From to the reverse-alias so replies route back through it, and records
  // the true sender in X-SimpleLogin-Envelope-From.
  async function senderInfo(messageId) {
    const full = await browser.messages.getFull(messageId).catch(() => null);
    if (!full) return null;

    const from = SLClassify.parseAddress(headerValues(full.headers, "from")[0]);
    const envelopeFrom = SLClassify.parseAddress(headerValues(full.headers, "x-simplelogin-envelope-from")[0]);

    return {
      from,
      envelopeFrom,
      reverseAlias: SLClassify.isReverseAlias(from) ? from : null,
      // The true sender when SimpleLogin told us, otherwise whatever is in From.
      display: envelopeFrom || from,
    };
  }

  // RFC 2047 encoded-word, for display names that aren't plain ASCII.
  function encodeWord(text) {
    const bytes = new TextEncoder().encode(text);
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return `=?UTF-8?B?${btoa(binary)}?=`;
  }

  function formatRecipient(raw) {
    const address = SLClassify.parseAddress(raw);
    if (!address) return null;

    const name = SLClassify.parseDisplayName(raw);
    if (!name) return address;
    if (!/^[\x20-\x7E]*$/.test(name)) return `${encodeWord(name)} <${address}>`;
    // RFC 5322 "specials" force the quoted form; the comma is the one that bites, since it would
    // otherwise read as another recipient.
    if (/[()<>@,;:\\".[\]]/.test(name)) return `"${name.replace(/(["\\])/g, "\\$1")}" <${address}>`;
    return `${name} <${address}>`;
  }

  function foldHeader(line, limit = 78) {
    const out = [];
    let current = "";
    for (const word of line.split(" ")) {
      if (current && `${current} ${word}`.length > limit) {
        out.push(current);
        current = ` ${word}`;
      } else {
        current = current ? `${current} ${word}` : word;
      }
    }
    if (current) out.push(current);
    return out;
  }

  // Removal takes the whole run: continuation lines belong to the header above them, and dropping
  // only the first would leave them behind as broken headers. value = null removes.
  function setHeader(lines, name, value) {
    const wanted = name.toLowerCase();
    const kept = [];
    let dropping = false;
    let insertAt = -1;

    for (const line of lines) {
      if (!/^[ \t]/.test(line)) {
        const match = line.match(/^([^:]+):/);
        dropping = Boolean(match) && match[1].trim().toLowerCase() === wanted;
        if (dropping && insertAt < 0) insertAt = kept.length;
      }
      if (!dropping) kept.push(line);
    }

    if (value == null) return kept;
    const folded = foldHeader(`${name}: ${value}`);
    if (insertAt < 0) kept.push(...folded);
    else kept.splice(insertAt, 0, ...folded);
    return kept;
  }

  // Kept free of Thunderbird APIs so it can be tested directly — this is string surgery on stored
  // mail, and getting it wrong corrupts the copy in Sent.
  function rewriteRecipientHeaders(raw, originals) {
    const eol = raw.includes("\r\n") ? "\r\n" : "\n";
    const boundary = raw.indexOf(eol + eol);
    if (boundary < 0) throw new Error("no header/body boundary in the raw message");

    let lines = raw.slice(0, boundary).split(eol);
    const body = raw.slice(boundary + eol.length * 2);

    for (const [name, values] of Object.entries(originals)) {
      const rendered = (values || []).map(formatRecipient).filter(Boolean);
      lines = setHeader(lines, name, rendered.length ? rendered.join(", ") : null);
    }

    return lines.join(eol) + eol + eol + body;
  }

  // Replace a saved Sent copy with one whose To/Cc are the people actually written to, not the
  // reverse-aliases. Import first, delete only on success, so a failed import loses nothing.
  async function restoreSentRecipients(messageId, originals) {
    const header = await browser.messages.get(messageId);
    const folderId = header.folderId ?? header.folder?.id ?? header.folder;
    if (!folderId) throw new Error("could not determine the folder of the sent copy");

    const file = await browser.messages.getRaw(messageId, { data_format: "File" });
    const rebuilt = rewriteRecipientHeaders(await file.text(), originals);

    const imported = await browser.messages.import(
      new File([rebuilt], "sent.eml", { type: "message/rfc822" }),
      folderId,
      { read: true },
    );

    // Permanent: this is a corrected duplicate, so Trash would just leave the broken copy around.
    await browser.messages.delete([messageId], { deletePermanently: true });
    return imported;
  }

  return {
    headerValues, aliasForMessage, senderInfo,
    formatRecipient, foldHeader, setHeader, rewriteRecipientHeaders, restoreSentRecipients,
  };
})();
