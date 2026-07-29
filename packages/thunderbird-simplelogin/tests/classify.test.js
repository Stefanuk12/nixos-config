// lib/classify.js against a synthetic account.
const fs = require("fs");
const path = process.env.CLASSIFY_JS ?? require("path").join(__dirname, "..", "src", "lib", "classify.js");
(0, eval)(fs.readFileSync(path, "utf8"));
const C = globalThis.SLClassify;

let failures = 0;
const eq = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failures++;
  console.log(`${ok ? "  ok " : "FAIL "}${label}${ok ? "" : `\n       got  ${JSON.stringify(got)}\n       want ${JSON.stringify(want)}`}`);
};

console.log("-- parseAddress --");
eq("bare", C.parseAddress("A@B.Com"), "a@b.com");
eq("angled", C.parseAddress("Stefan <s@ex.com>"), "s@ex.com");
eq("quoted comma name", C.parseAddress('"Last, First" <lf@ex.com>'), "lf@ex.com");
eq("mailto", C.parseAddress("mailto:x@y.z"), "x@y.z");
eq("garbage", C.parseAddress("not an address"), "");
eq("empty", C.parseAddress(""), "");

console.log("-- parseDisplayName --");
eq("name", C.parseDisplayName("Stefan <s@ex.com>"), "Stefan");
eq("quoted", C.parseDisplayName('"Last, First" <lf@ex.com>'), "Last, First");
eq("bare has none", C.parseDisplayName("s@ex.com"), "");

console.log("-- isReverseAlias --");
eq("ra+", C.isReverseAlias("ra+abc@simplelogin.co"), true);
eq("reply+", C.isReverseAlias("reply+abc@sl.co"), true);
eq("normal", C.isReverseAlias("hello@example.com"), false);

console.log("-- matchSuffix --");
const suffixes = [
  { suffix: "@mydomain.com", signed_suffix: "@mydomain.com.SIG", is_custom: true, is_premium: false },
  { suffix: ".foo@mydomain.com", signed_suffix: ".foo@mydomain.com.SIG", is_custom: true, is_premium: false },
  { suffix: ".cat@simplelogin.co", signed_suffix: ".cat@simplelogin.co.SIG", is_custom: false, is_premium: false },
  { suffix: "@premium.com", signed_suffix: "@premium.com.SIG", is_custom: true, is_premium: true },
];
eq("simple custom domain", C.matchSuffix("netflix@mydomain.com", suffixes)?.prefix, "netflix");
// Longest suffix wins: bar.foo@mydomain.com resolves against ".foo@", not "@".
const longest = C.matchSuffix("bar.foo@mydomain.com", suffixes);
eq("longest suffix wins", [longest.prefix, longest.suffix.suffix], ["bar", ".foo@mydomain.com"]);
eq("unknown domain", C.matchSuffix("x@nope.com", suffixes), null);
eq("SL random-word suffix not typeable", C.matchSuffix("netflix@simplelogin.co", suffixes), null);
eq("bad prefix char", C.matchSuffix("net flix@mydomain.com", suffixes), null);
eq("uppercase rejected (caller lowercases)", C.matchSuffix("Netflix@mydomain.com", suffixes), null);
eq("empty prefix", C.matchSuffix("@mydomain.com", suffixes), null);
eq("premium skipped on free", C.matchSuffix("x@premium.com", suffixes, { isPremium: false }), null);
eq("premium allowed on paid", C.matchSuffix("x@premium.com", suffixes, { isPremium: true })?.prefix, "x");

console.log("-- classify --");
const snapshot = {
  aliases: [
    { id: 1, email: "existing@mydomain.com", enabled: true },
    { id: 2, email: "OFF@mydomain.com", enabled: false },
  ],
  options: { can_create: true, suffixes },
  isPremium: true,
};
const on = { apiKey: "k", autoCreateOnSend: true };
const off = { apiKey: "k", autoCreateOnSend: false };

eq("no key", C.classify("a@b.c", snapshot, { apiKey: "" }).state, "no-key");
eq("no snapshot", C.classify("a@b.c", null, on).state, "stale");
eq("empty address", C.classify("", snapshot, on).state, "not-alias");
eq("existing alias", C.classify("existing@mydomain.com", snapshot, on).state, "alias");
eq("existing is case-insensitive", C.classify("off@mydomain.com", snapshot, on).state, "alias-disabled");
eq("creatable, auto on", C.classify("netflix@mydomain.com", snapshot, on).state, "will-create");
eq("creatable, auto off", C.classify("netflix@mydomain.com", snapshot, off).state, "can-create");
eq("foreign domain", C.classify("someone@gmail.com", snapshot, on).state, "not-alias");
eq("own proton address", C.classify("stefanukpadd@protonmail.com", snapshot, on).state, "not-alias");
eq(
  "quota exhausted",
  C.classify("netflix@mydomain.com", { ...snapshot, options: { ...snapshot.options, can_create: false } }, on).state,
  "cannot-create",
);
eq("candidate carries signed suffix",
  C.classify("netflix@mydomain.com", snapshot, on).candidate.suffix.signed_suffix, "@mydomain.com.SIG");

console.log("-- alias display name --");
// From is the source of the alias name: `hello <addr>` names it "hello", a bare address doesn't.
const named = (from) => {
  const address = C.parseAddress(from);
  return C.classify(address, snapshot, on, C.parseDisplayName(from));
};
eq("named From sets alias name", named("hello <netflix@mydomain.com>").candidate.name, "hello");
eq("bare From leaves alias unnamed", named("netflix@mydomain.com").candidate.name, "");
eq("quoted name with comma", named('"Doe, John" <netflix@mydomain.com>').candidate.name, "Doe, John");
eq("name is echoed in the detail",
  named("hello <netflix@mydomain.com>").detail.includes('display name "hello"'), true);
eq("unnamed says so in the detail",
  named("netflix@mydomain.com").detail.includes("no display name"), true);
eq("displayName surfaces on the status", named("hello <netflix@mydomain.com>").displayName, "hello");

console.log(failures ? `\n${failures} FAILURE(S)` : "\nall passed");
process.exit(failures ? 1 : 0);
