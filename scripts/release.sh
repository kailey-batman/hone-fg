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

# ── 1. Bump version in xcodeproj ────────────────────────────────────────────
echo "→ Bumping MARKETING_VERSION to ${VERSION}..."
xcrun agvtool new-marketing-version "${VERSION}"

BUILD=$(xcrun agvtool next-version -all | tail -1)
echo "  Build number: ${BUILD}"

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

SIGNATURE=$("${SPARKLE_BIN}" "${EXPORT_PATH}/${ZIP_NAME}" 2>/dev/null)
FILE_SIZE=$(stat -f%z "${EXPORT_PATH}/${ZIP_NAME}")

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
