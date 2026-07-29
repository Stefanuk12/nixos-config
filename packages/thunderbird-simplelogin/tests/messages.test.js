// The pure parts of lib/messages.js: the header surgery that puts real recipients back into the
// Sent copy, plus parseAddressList.
const fs = require("fs");
const path = require("path");

const dir = process.env.SRC_DIR ?? path.join(__dirname, "..", "src");
(0, eval)(fs.readFileSync(path.join(dir, "lib", "classify.js"), "utf8"));
(0, eval)(fs.readFileSync(path.join(dir, "lib", "messages.js"), "utf8"));
const C = globalThis.SLClassify;
const M = globalThis.SLMessages;

let failures = 0;
const eq = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failures++;
  console.log(`${ok ? "  ok " : "FAIL "}${label}${ok ? "" : `\n       got  ${JSON.stringify(got)}\n       want ${JSON.stringify(want)}`}`);
};

console.log("-- parseAddressList --");
eq("single", C.parseAddressList("a@b.c"), ["a@b.c"]);
eq("two plain", C.parseAddressList("a@b.c, x@y.z"), ["a@b.c", "x@y.z"]);
eq("named", C.parseAddressList("Stefan <a@b.c>, Other <x@y.z>"), ["a@b.c", "x@y.z"]);
// The whole reason for a real parser: a comma inside a quoted display name isn't a separator.
eq("comma inside quotes", C.parseAddressList('"Doe, John" <a@b.c>, x@y.z'), ["a@b.c", "x@y.z"]);
eq("escaped quote", C.parseAddressList('"Say \\"hi\\"" <a@b.c>'), ["a@b.c"]);
eq("empty", C.parseAddressList(""), []);
eq("trailing comma ignored", C.parseAddressList("a@b.c,"), ["a@b.c"]);

console.log("-- headerValues (case-insensitive) --");
const headers = { "X-SimpleLogin-Envelope-To": ["alias@d.com"], to: ["me@d.com"] };
eq("mixed case key", M.headerValues(headers, "x-simplelogin-envelope-to"), ["alias@d.com"]);
eq("lowercase key", M.headerValues(headers, "TO"), ["me@d.com"]);
eq("missing", M.headerValues(headers, "cc"), []);

console.log("-- formatRecipient --");
eq("bare", M.formatRecipient("a@b.c"), "a@b.c");
eq("plain name", M.formatRecipient("Stefan <a@b.c>"), "Stefan <a@b.c>");
eq("comma name gets quoted", M.formatRecipient("Doe, John <a@b.c>"), '"Doe, John" <a@b.c>');
eq("non-ascii encoded", M.formatRecipient("Ström <a@b.c>"), "=?UTF-8?B?U3Ryw7Zt?= <a@b.c>");
eq("garbage drops", M.formatRecipient("nonsense"), null);

console.log("-- setHeader --");
const lines = ["From: me@d.com", "To: reply+abc@sl.co", "Subject: hi", "X-Other: 1"];
eq("replace", M.setHeader(lines, "To", "real@d.com"),
  ["From: me@d.com", "To: real@d.com", "Subject: hi", "X-Other: 1"]);
eq("remove with null", M.setHeader(lines, "To", null),
  ["From: me@d.com", "Subject: hi", "X-Other: 1"]);
eq("append when absent", M.setHeader(lines, "Cc", "c@d.com"),
  [...lines, "Cc: c@d.com"]);
eq("case-insensitive match", M.setHeader(["to: old@d.com"], "To", "new@d.com"), ["To: new@d.com"]);
// A folded header's continuation lines belong to it; leaving them behind breaks the mail.
eq("folded header removed whole",
  M.setHeader(["To: a@d.com,", " b@d.com", "Subject: hi"], "To", "real@d.com"),
  ["To: real@d.com", "Subject: hi"]);

console.log("-- rewriteRecipientHeaders --");
const raw = [
  "From: me@proton.me",
  "To: reply+xyz@simplelogin.co",
  "Subject: Hello",
  "",
  "body stays untouched",
].join("\r\n");

const fixed = M.rewriteRecipientHeaders(raw, { To: ["Real Person <real@example.com>"], Cc: [] });
eq("To restored", fixed.includes("To: Real Person <real@example.com>"), true);
eq("reverse-alias gone", fixed.includes("reply+xyz@simplelogin.co"), false);
eq("body preserved", fixed.endsWith("\r\nbody stays untouched"), true);
eq("CRLF preserved", fixed.includes("\r\n"), true);
eq("empty Cc removes nothing that wasn't there", fixed.includes("Cc:"), false);

// LF-only messages must not be converted, or every line ending in the stored copy changes.
const lf = "From: me@d.com\nTo: reply+x@sl.co\n\nbody";
const lfFixed = M.rewriteRecipientHeaders(lf, { To: ["real@d.com"] });
eq("LF-only preserved", lfFixed.includes("\r"), false);
eq("LF-only rewritten", lfFixed, "From: me@d.com\nTo: real@d.com\n\nbody");

// A body containing a blank line must not be mistaken for the header boundary.
const multi = "To: reply+x@sl.co\n\nfirst para\n\nsecond para";
eq("only the first blank line splits",
  M.rewriteRecipientHeaders(multi, { To: ["r@d.com"] }),
  "To: r@d.com\n\nfirst para\n\nsecond para");

console.log("-- foldHeader --");
eq("short stays one line", M.foldHeader("To: a@b.c"), ["To: a@b.c"]);
const long = M.foldHeader(`To: ${Array.from({ length: 12 }, (_, i) => `person${i}@example.com,`).join(" ")}`);
eq("long folds", long.length > 1, true);
eq("continuations are indented", long.slice(1).every((l) => l.startsWith(" ")), true);

console.log(failures ? `\n${failures} FAILURE(S)` : "\nall passed");
process.exit(failures ? 1 : 0);
