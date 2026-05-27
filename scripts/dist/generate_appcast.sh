#!/bin/bash
# Generate Sparkle appcast.xml for the Day Journal fork.
# Run this after building and signing the DMG.
#
# Usage:
#   VERSION=0.6.0-journal.3 DMG_PATH=dist/MacParakeet.dmg scripts/dist/generate_appcast.sh
#
# Output: dist/appcast.xml — upload alongside the DMG release asset.

set -euo pipefail

VERSION="${VERSION:?required}"
DMG_PATH="${DMG_PATH:?required}"
REPO="iannellomarco/macparakeet-dayjournal"
FEED_URL="https://raw.githubusercontent.com/${REPO}/main/appcast.xml"
DOWNLOAD_BASE="https://github.com/${REPO}/releases/download/v${VERSION}"

DMG_NAME="MacParakeet-${VERSION}.dmg"
DMG_URL="${DOWNLOAD_BASE}/${DMG_NAME}"

# Generate Sparkle signature for the DMG
SIGNATURE=$("${SPARKLE_SIGN_UPDATE:-.build/artifacts/sparkle/Sparkle/bin/sign_update}" "$DMG_PATH" 2>/dev/null | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')

if [ -z "$SIGNATURE" ]; then
    echo "Warning: Could not generate Sparkle signature. sign_update may not be built."
    echo "Build it first: swift build --product sign_update"
    SIGNATURE="PLACEHOLDER"
fi

# Get DMG size
SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH" 2>/dev/null)

# Get current date in RFC 2822 format
PUBDATE=$(date -R)

cat > dist/appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>MacParakeet Day Journal</title>
    <description>Fork of MacParakeet with Day Journal feature — periodic screen capture + AI-driven daily second-brain</description>
    <language>en</language>
    <link>https://github.com/${REPO}</link>
    <item>
      <title>MacParakeet Day Journal ${VERSION}</title>
      <description>Day Journal update — see release notes at https://github.com/${REPO}/releases/tag/v${VERSION}</description>
      <pubDate>${PUBDATE}</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.2</sparkle:minimumSystemVersion>
      <enclosure
        url="${DMG_URL}"
        sparkle:edSignature="${SIGNATURE}"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        length="${SIZE}"
        type="application/x-apple-diskimage"
      />
    </item>
  </channel>
</rss>
EOF

echo "Generated dist/appcast.xml"
echo "Upload this file to the repo root and push to main."
echo "Then set SU_FEED_URL=${FEED_URL} when building."
