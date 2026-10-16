#!/bin/bash
# release.sh — Build, sign, and publish a new Hone (FG Version) release
# Usage: ./scripts/release.sh 1.2

set -e

VERSION=${1:?"Usage: $0 <version>  e.g. $0 1.2"}
SCHEME="Hone (FG Version)"
ARCHIVE_PATH="/tmp/HoneFG-${VERSION}.xcarchive"
EXPORT_PATH="/tmp/HoneFG-${VERSION}-export"
APP_NAME="Hone (FG Version).app"
ZIP_NAME="Hone-FG-${VERSION}.zip"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

INFO_PLIST="${REPO_DIR}/Hone (FG Version)/Info.plist"

# ── 1. Bump version + build number directly in Info.plist ───────────────────
# Written BEFORE the archive so the shipped binary actually carries them.
# agvtool was unreliable here: it silently left CFBundleVersion stale, which
# shipped 1.3.14 as build 9 while the appcast advertised 18 and put every
# user in a permanent Sparkle update loop.
echo "→ Bumping to ${VERSION}..."

CURRENT_BUILD=$(plutil -extract CFBundleVersion raw "${INFO_PLIST}")
if ! [[ "${CURRENT_BUILD}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: CFBundleVersion in Info.plist is not a number: '${CURRENT_BUILD}'"
  exit 1
fi
BUILD=$((CURRENT_BUILD + 1))

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${INFO_PLIST}"
plutil -replace CFBundleVersion            -string "${BUILD}"   "${INFO_PLIST}"

echo "  Marketing version: ${VERSION}"
echo "  Build number:      ${BUILD}"

# ── 2. Archive ───────────────────────────────────────────────────────────────
echo "→ Archiving..."
xcodebuild archive \
  -scheme "${SCHEME}" \
  -archivePath "${ARCHIVE_PATH}" \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  | xcpretty 2>/dev/null || true

# ── 3. Export (Direct Distribution / Developer ID) ───────────────────────────
echo "→ Exporting..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${REPO_DIR}/scripts/ExportOptions.plist"

# ── 3b. Verify the EXPORTED app matches what we'll advertise ────────────────
# Sparkle compares the installed CFBundleVersion against <sparkle:version>.
# If they disagree, every user gets offered the same update forever, and each
# reinstall changes the ad-hoc signature, which revokes Accessibility access.
EXPORTED_PLIST="${EXPORT_PATH}/${APP_NAME}/Contents/Info.plist"
EXPORTED_SHORT=$(plutil -extract CFBundleShortVersionString raw "${EXPORTED_PLIST}")
EXPORTED_BUILD=$(plutil -extract CFBundleVersion raw "${EXPORTED_PLIST}")

echo "→ Verifying exported app..."
echo "  shipped short version: ${EXPORTED_SHORT} (expected ${VERSION})"
echo "  shipped build number:  ${EXPORTED_BUILD} (expected ${BUILD})"

if [ "${EXPORTED_SHORT}" != "${VERSION}" ] || [ "${EXPORTED_BUILD}" != "${BUILD}" ]; then
  echo ""
  echo "ERROR: exported app does not match the version being released."
  echo "Publishing this would put users in a permanent Sparkle update loop."
  exit 1
fi

# ── 4. Zip the app ───────────────────────────────────────────────────────────
echo "→ Zipping..."
cd "${EXPORT_PATH}"
zip -r --symlinks "${ZIP_NAME}" "${APP_NAME}"
cd "${REPO_DIR}"

# ── 5. Sign the update with Sparkle ─────────────────────────────────────────
echo "→ Signing update..."
SPARKLE_BIN=$(find ~/Library/Developer/Xcode -path "*/Sparkle/bin/sign_update" 2>/dev/null | head -1)
if [ -z "$SPARKLE_BIN" ]; then
  echo "ERROR: sign_update not found. Make sure Sparkle is added via SPM."
  exit 1
fi

# sign_update prints the whole attribute string, e.g.
#   sparkle:edSignature="abc123==" length="1799008"
# Extract just the signature value so the generated XML isn't double-quoted.
SIGN_OUTPUT=$("${SPARKLE_BIN}" "${EXPORT_PATH}/${ZIP_NAME}" 2>/dev/null)
SIGNATURE=$(echo "${SIGN_OUTPUT}" | sed -E 's/.*edSignature="([^"]*)".*/\1/')
FILE_SIZE=$(stat -f%z "${EXPORT_PATH}/${ZIP_NAME}")

if [ -z "${SIGNATURE}" ] || [ "${SIGNATURE}" = "${SIGN_OUTPUT}" ]; then
  echo "ERROR: could not parse signature from sign_update output: ${SIGN_OUTPUT}"
  exit 1
fi

echo ""
echo "  Signature: ${SIGNATURE}"
echo "  File size: ${FILE_SIZE}"

# ── 6. Generate appcast entry ────────────────────────────────────────────────
PUBDATE=$(date -R)
DOWNLOAD_URL="https://github.com/kailey-batman/hone-fg/releases/download/v${VERSION}/${ZIP_NAME}"

cat <<EOF

────────────────────────────────────────────────────────
Add this <item> block to your appcast.xml, then commit:

    <item>
        <title>Version ${VERSION}</title>
        <pubDate>${PUBDATE}</pubDate>
        <sparkle:version>${BUILD}</sparkle:version>
        <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
        <enclosure
            url="${DOWNLOAD_URL}"
            sparkle:edSignature="${SIGNATURE}"
            length="${FILE_SIZE}"
            type="application/octet-stream" />
    </item>

────────────────────────────────────────────────────────
Next steps:
  1. Upload ${EXPORT_PATH}/${ZIP_NAME} to GitHub Releases as v${VERSION}
  2. Paste the <item> above into appcast.xml
  3. Commit and push appcast.xml — users will get the update prompt automatically
EOF
