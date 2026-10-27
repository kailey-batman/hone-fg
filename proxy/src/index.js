// Hone FG proxy — holds the Anthropic key server side so it never ships in the app.
//
// The app sends its shared team token in x-hone-token. This Worker checks that
// token, sanity-checks the request, then forwards to Anthropic using HONE_ANTHROPIC_KEY
// (a Worker secret). If the team token ever leaks, rotating it is a wrangler command
// and an app release — the Anthropic key itself is never exposed and never needs
// revoking.

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";

// Only models Hone actually uses. Stops a leaked token being spent on Opus.
const ALLOWED_MODELS = new Set(["claude-haiku-4-5"]);

const MAX_TOKENS_CEILING = 2048;
const MAX_BODY_BYTES = 256 * 1024;

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") {
      return json({ error: { message: "POST only" } }, 405);
    }

    const url = new URL(request.url);
    if (url.pathname !== "/v1/messages") {
      return json({ error: { message: "Not found" } }, 404);
    }

    // ── Team token ────────────────────────────────────────────────────────────
    const token = request.headers.get("x-hone-token") || "";
    if (!env.HONE_TEAM_TOKEN || !timingSafeEqual(token, env.HONE_TEAM_TOKEN)) {
      return json({ error: { message: "Unauthorized" } }, 401);
    }

    // ── Rate limit ────────────────────────────────────────────────────────────
    // Keyed per client IP so one machine stuck in a loop can't drain the budget.
    // Fails open: a rate limiter outage shouldn't take rewriting down.
    if (env.HONE_RATE_LIMIT) {
      try {
        const ip = request.headers.get("cf-connecting-ip") || "unknown";
        const { success } = await env.HONE_RATE_LIMIT.limit({ key: ip });
        if (!success) {
          return json(
            { error: { message: "Rate limit exceeded. Wait a moment and try again." } },
            429
          );
        }
      } catch (_) {
        // fail open
      }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    const raw = await request.text();
    if (raw.length > MAX_BODY_BYTES) {
      return json({ error: { message: "Request too large" } }, 413);
    }

    let body;
    try {
      body = JSON.parse(raw);
    } catch (_) {
      return json({ error: { message: "Invalid JSON" } }, 400);
    }

    if (!ALLOWED_MODELS.has(body.model)) {
      return json({ error: { message: `Model not allowed: ${body.model}` } }, 400);
    }

    if (typeof body.max_tokens !== "number" || body.max_tokens > MAX_TOKENS_CEILING) {
      body.max_tokens = MAX_TOKENS_CEILING;
    }

    // Drop anything the app doesn't send. Keeps a leaked token from reaching
    // features (tools, long-running requests) that carry a different cost profile.
    const forwarded = {
      model: body.model,
      max_tokens: body.max_tokens,
      system: body.system,
      messages: body.messages,
    };

    // ── Forward ───────────────────────────────────────────────────────────────
    const upstream = await fetch(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.HONE_ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(forwarded),
    });

    // Pass the response straight through so the app's existing parsing and its
    // error surfacing both keep working unchanged.
    return new Response(upstream.body, {
      status: upstream.status,
      headers: { "content-type": "application/json" },
    });
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Constant-time compare so the token can't be recovered by timing the 401.
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
