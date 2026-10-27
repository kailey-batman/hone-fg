# Hone proxy

Holds the Anthropic key so it never ships inside the app.

## Why this exists

The FG build used to carry the Anthropic key as a plaintext string in
`Hone (FG Version)/Config.swift`. That file was never committed, but Xcode compiles
the string into the binary, and the binary goes up as a public GitHub release asset.
`strings` pulls the key straight back out, scrapers find it, and Anthropic revokes it.
That happened twice.

Now the app ships a **team token** instead. The token only opens this Worker. The
Worker holds the Anthropic key as a secret and forwards the request.

| | Old | Now |
|---|---|---|
| What ships in the app | Anthropic key | Team token |
| If it leaks | Anthropic revokes the key, everyone breaks, new build needed | Rotate the token, new build, Anthropic key untouched |
| Blast radius | Full API access on your account | 60 req/min/IP, haiku only, capped tokens |
| Billing | One account | One account (unchanged) |

## What it enforces

- `x-hone-token` must match `HONE_TEAM_TOKEN` (constant-time compare)
- Model allowlist: `claude-haiku-4-5` only
- `max_tokens` clamped to 2048
- Body capped at 256 KB
- 60 requests per minute per IP, fails open
- Only `POST /v1/messages`; everything else is 404/405
- Request fields are rebuilt from scratch, so nothing unexpected reaches Anthropic

## Secrets

Never in `wrangler.toml`. Two of them:

| Secret | What it is |
|---|---|
| `HONE_ANTHROPIC_KEY` | The real Anthropic key. Only lives here. |
| `HONE_TEAM_TOKEN` | What the app sends. Must match `Config.builtInAPIKey`. |

## Deploy

```bash
cd proxy
npx wrangler deploy
```

## Rotate the team token

Do this if a teammate leaves, or if you think the token is out.

```bash
cd proxy
python3 -c "import secrets; print('hone_' + secrets.token_urlsafe(32))"
npx wrangler secret put HONE_TEAM_TOKEN      # paste the new one
```

Then put the same value in `Hone (FG Version)/Config.swift` as `builtInAPIKey` and
ship a release. Old builds get 401 until people update. The Anthropic key is not
involved and does not need revoking.

## Rotate the Anthropic key

```bash
npx wrangler secret put HONE_ANTHROPIC_KEY
```

That is the whole job. No app release, nobody notices.

## Local testing

`.dev.vars` holds both secrets for `wrangler dev`. It is gitignored. Never commit it.

```bash
npx wrangler dev --port 8799 --local
curl -s http://localhost:8799/v1/messages \
  -H "x-hone-token: $(grep '^HONE_TEAM_TOKEN=' .dev.vars | cut -d= -f2-)" \
  -H 'content-type: application/json' \
  -d '{"model":"claude-haiku-4-5","max_tokens":64,"messages":[{"role":"user","content":"say OK"}]}'
```

## Watching spend

The backstop is a spend limit on the Anthropic account, not anything in this Worker.
Set it at console.anthropic.com under Billing. A leaked token can cost money up to
that limit; it can never cost you the key.
