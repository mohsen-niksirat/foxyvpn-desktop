// API relay for the VPN client, as a Cloudflare Worker.
//
// When Mozilla's sign-in, Guardian, or server list cannot be reached from
// your network, the client can send those requests (never the VPN traffic)
// through this relay: set its URL in Settings > Advanced > "Relay for
// Mozilla's services", for example https://relay.NAME.workers.dev/?key=SECRET
//
// The client asks for /?url=<target>; the relay sends the same method,
// headers, and body to the target and answers with its response. Only the
// hosts below are relayed, so the relay is not an open proxy for others.
//
// Deploy: Cloudflare dashboard > Workers & Pages > Create > Worker, paste
// this file, set KEY, Deploy.

// A secret only your client knows; the relay URL then ends in ?key=SECRET.
// Leave empty for no key (anyone who finds the URL could use your relay,
// for these hosts only).
const KEY = "";

const ALLOWED = [
  "mozilla.org", "mozilla.com", "firefox.com", // accounts, Guardian, server list
  "github.com", "githubusercontent.com", "jsdelivr.net", // geo files, flags
];

// Headers that describe this hop, not the request.
const DROP = ["host", "connection", "content-length", "x-forwarded-for", "x-forwarded-proto", "x-forwarded-host", "x-real-ip"];

function fail(status, why) {
  return new Response(why, { status, headers: { "X-Relay-Error": why, "Content-Type": "text/plain" } });
}

export default {
  async fetch(request) {
    const here = new URL(request.url);
    if (KEY && here.searchParams.get("key") !== KEY) return fail(403, "wrong key");
    let target;
    try {
      target = new URL(here.searchParams.get("url") || "");
    } catch {
      return fail(400, "url must be an https URL");
    }
    if (target.protocol !== "https:") return fail(400, "url must be an https URL");
    const host = target.hostname.toLowerCase();
    if (!ALLOWED.some((domain) => host === domain || host.endsWith("." + domain))) {
      return fail(403, `host not allowed: ${host}`);
    }
    const headers = new Headers();
    for (const [name, value] of request.headers) {
      const lower = name.toLowerCase();
      if (DROP.includes(lower) || lower.startsWith("cf-")) continue;
      headers.set(name, value);
    }
    // The client's requests are small (sign-in, tokens): read whole.
    const hasBody = request.method !== "GET" && request.method !== "HEAD";
    const body = hasBody ? await request.arrayBuffer() : undefined;
    // Redirects go back to the client, which follows them through the relay.
    return fetch(target, { method: request.method, headers, body, redirect: "manual" });
  },
};
