#!/bin/bash
# deploy.sh — stand up (or redeploy) the Hone proxy and point the app at it.
# Safe to re-run. Reads both secrets from .dev.vars so nothing is typed by hand.

set -e
# Without pipefail, `wrangler deploy | tee` reports tee's exit status, so a failed
# deploy reads as success and the script marches on to test a Worker that was never
# uploaded. That happened on the first run.
set -o pipefail
cd "$(dirname "$0")"

CONFIG="../Hone (FG Version)/Config.swift"

if [ ! -f .dev.vars ]; then
  echo "ERROR: .dev.vars is missing. It must hold HONE_ANTHROPIC_KEY and HONE_TEAM_TOKEN."
  exit 1
fi

ANTHROPIC_KEY=$(grep '^HONE_ANTHROPIC_KEY=' .dev.vars | cut -d= -f2-)
TEAM_TOKEN=$(grep '^HONE_TEAM_TOKEN=' .dev.vars | cut -d= -f2-)

if [ -z "${ANTHROPIC_KEY}" ] || [ -z "${TEAM_TOKEN}" ]; then
  echo "ERROR: .dev.vars is missing one of the two secrets."
  exit 1
fi

# ── 1. Auth ──────────────────────────────────────────────────────────────────
if ! npx wrangler whoami >/dev/null 2>&1; then
  echo "→ Signing in to Cloudflare. A browser tab will open, click Allow."
  npx wrangler login
fi
echo "→ Signed in as:"
npx wrangler whoami 2>/dev/null | grep -i "email\|account" | head -3

# ── 2. workers.dev subdomain ─────────────────────────────────────────────────
# A fresh Cloudflare account has none, and without one `wrangler deploy` aborts
# with an interactive prompt it can't ask here. Register it over the API instead.
ACCOUNT_ID=$(npx wrangler whoami 2>/dev/null | grep -oE '[0-9a-f]{32}' | head -1)
OAUTH=$(grep -E '^oauth_token' ~/Library/Preferences/.wrangler/config/default.toml 2>/dev/null | sed -E 's/.*= *"(.*)"/\1/')

if [ -n "${ACCOUNT_ID}" ] && [ -n "${OAUTH}" ]; then
  HAS_SUB=$(curl -s "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/workers/subdomain" \
    -H "Authorization: Bearer ${OAUTH}" | grep -c '"success":true' || true)
  if [ "${HAS_SUB}" = "0" ]; then
    WANT=$(echo "${ACCOUNT_ID}" | cut -c1-12)
    echo "→ No workers.dev subdomain on this account, registering '${WANT}'..."
    curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/workers/subdomain" \
      -H "Authorization: Bearer ${OAUTH}" -H "Content-Type: application/json" \
      -d "{\"subdomain\":\"${WANT}\"}" >/dev/null
  fi
fi

# ── 3. Deploy ────────────────────────────────────────────────────────────────
# The rate limit binding is nice to have, not load bearing. If this account or
# plan rejects it, drop it and deploy anyway rather than leaving the team broken.
echo "→ Deploying..."
if ! npx wrangler deploy 2>&1 | tee /tmp/hone-deploy.log; then
  if grep -qi "ratelimit\|unsafe" /tmp/hone-deploy.log; then
    echo "→ Rate limit binding rejected, retrying without it."
    cp wrangler.toml wrangler.toml.bak
    sed -i '' '/\[\[unsafe.bindings\]\]/,$d' wrangler.toml
    npx wrangler deploy 2>&1 | tee /tmp/hone-deploy.log
  else
    echo "ERROR: deploy failed. See /tmp/hone-deploy.log"
    exit 1
  fi
fi

# ── 3. Secrets ───────────────────────────────────────────────────────────────
echo "→ Uploading secrets..."
printf '%s' "${ANTHROPIC_KEY}" | npx wrangler secret put HONE_ANTHROPIC_KEY
printf '%s' "${TEAM_TOKEN}"    | npx wrangler secret put HONE_TEAM_TOKEN

# ── 4. Point the app at the real URL ─────────────────────────────────────────
# The workers.dev subdomain belongs to the account, so it is only knowable after
# the first deploy. Patch Config.swift rather than trusting the guess that is in there.
DEPLOYED_URL=$(grep -oE 'https://[a-z0-9.-]*hone-proxy[a-z0-9.-]*\.workers\.dev' /tmp/hone-deploy.log | head -1)

if [ -z "${DEPLOYED_URL}" ]; then
  echo ""
  echo "WARNING: could not read the deployed URL out of the deploy output."
  echo "Find it in the Cloudflare dashboard and set proxyBaseURL in Config.swift by hand."
else
  echo "→ Worker is live at ${DEPLOYED_URL}"
  CURRENT=$(grep 'proxyBaseURL' "${CONFIG}" | sed -E 's/.*"(.*)".*/\1/')
  if [ "${CURRENT}" != "${DEPLOYED_URL}" ]; then
    echo "  Updating Config.swift (was ${CURRENT})"
    sed -i '' -E "s|static let proxyBaseURL = \".*\"|static let proxyBaseURL = \"${DEPLOYED_URL}\"|" "${CONFIG}"
  fi
fi

# ── 5. Prove it works end to end ─────────────────────────────────────────────
# A brand new workers.dev hostname can take a few minutes to resolve, and the
# machine may cache an IPv6-only answer in the meantime. Retry rather than
# reporting a working Worker as broken.
echo "→ Testing the live Worker (may take a minute on a first deploy)..."
STATUS=000
for attempt in $(seq 1 30); do
  STATUS=$(curl -s -o /tmp/hone-proxy-test.json -w "%{http_code}" --max-time 20 \
    "${DEPLOYED_URL}/v1/messages" \
    -H "x-hone-token: ${TEAM_TOKEN}" \
    -H 'content-type: application/json' \
    -d '{"model":"claude-haiku-4-5","max_tokens":32,"messages":[{"role":"user","content":"say OK"}]}' || echo 000)
  [ "${STATUS}" != "000" ] && break
  [ "${attempt}" = "5" ] && dscacheutil -flushcache 2>/dev/null
  sleep 10
done

echo ""
if [ "${STATUS}" = "200" ]; then
  echo "✅ Proxy is live and answering. Rebuild and ship Hone whenever you're ready."
else
  echo "❌ Proxy returned HTTP ${STATUS}:"
  cat /tmp/hone-proxy-test.json
  echo ""
  echo "401 means the token secret did not take. 500 means the Anthropic key did not."
fi
