// Routes gh.petrovic.foo to either the self-hosted Forgejo or github.com.
//
// The probe asks Forgejo "do you have this repo?" rather than asking GitHub,
// because GitHub answers 401 — not 404 — to anonymous callers for both private
// repos *and* every git-receive-pack advertisement, including public ones. A
// GitHub-side probe therefore reads "401" on every push and misroutes it to the
// self-host. Probing Forgejo and defaulting to GitHub makes the unknown case
// fall through to GitHub, which then authenticates the client normally.

const GITHUB = "https://github.com";
const FORGEJO = "https://git.petrovic.foo";

const GIT_SUFFIX = /\/(?:info\/refs|git-upload-pack|git-receive-pack|info\/lfs\/.*)$/;
const REPO_PATH = /^\/([^/]+)\/([^/]+?)(?:\.git)?$/;

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const repo = REPO_PATH.exec(url.pathname.replace(GIT_SUFFIX, ""));

    let target = FORGEJO;
    let probe = "skipped";
    if (repo) {
      probe = await probeForgejo(repo[1], repo[2], ctx);
      target = probe === 200 || probe === 401 ? FORGEJO : GITHUB;
    }

    // 307, not 302: git-lfs POSTs to /info/lfs/objects/batch and follows the
    // redirect itself, and a 302 would downgrade that POST to a GET.
    return new Response(null, {
      status: 307,
      headers: {
        location: target + url.pathname + url.search,
        "cache-control": "no-store",
        "x-router-probe": String(probe),
      },
    });
  },
};

async function probeForgejo(owner, name, ctx) {
  const probeUrl =
    `${FORGEJO}/${encodeURIComponent(owner)}/${encodeURIComponent(name)}` +
    `.git/info/refs?service=git-upload-pack`;
  const key = new Request(probeUrl, { method: "GET" });

  const hit = await caches.default.match(key);
  if (hit) return Number(hit.headers.get("x-probe-status"));

  let status;
  try {
    status = (await fetch(probeUrl, { redirect: "manual" })).status;
  } catch {
    return 0; // Forgejo unreachable — fall through to GitHub rather than 5xx.
  }

  ctx.waitUntil(
    caches.default.put(
      key,
      new Response(null, {
        headers: { "cache-control": "max-age=300", "x-probe-status": String(status) },
      }),
    ),
  );
  return status;
}
