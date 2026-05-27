# MacParakeet Day Journal — Release Workflow

## Prerequisites

- Apple Developer ID certificate in Keychain: `Developer ID Application: Marco Iannello (HX54PKUTV6)`
- Notary profile in Keychain: `macparascreen-notary` (Apple ID: `iannello.marco10@gmail.com`, Team: `HX54PKUTV6`)
- Sparkle EdDSA private key in Keychain (generated once, survives reboots)
- `gh` CLI authenticated as `iannellomarco`

## Keys

| Key | Value |
|-----|-------|
| **Signing identity** | `Developer ID Application: Marco Iannello (HX54PKUTV6)` |
| **Sparkle public key** | `N/L9A3Dq0CVwDIlibInW1J7EW4ctRc6TyzidwwLH/PE=` |
| **Notary profile** | `macparascreen-notary` |

## Release Flow

```bash
# 1. Set version
VERSION=0.6.0-journal.7

# 2. Build app bundle
VERSION=$VERSION scripts/dist/build_app_bundle.sh

# 3. Sign + notarize + create DMG
SIGN_IDENTITY="Developer ID Application: Marco Iannello (HX54PKUTV6)" \
  NOTARYTOOL_PROFILE="macparascreen-notary" \
  CREATE_DMG=1 \
  scripts/dist/sign_notarize.sh

# 4. Get SHA-256
shasum -a 256 dist/MacParakeet.dmg

# 5. Sign DMG with Sparkle EdDSA
.build/artifacts/sparkle/Sparkle/bin/sign_update dist/MacParakeet.dmg
# → outputs: sparkle:edSignature="..." length="..."

# 6. Create GitHub release
python3 -c "
import json
payload = {
    'tag_name': f'v$VERSION',
    'name': f'v$VERSION',
    'body': 'Release notes here...',
    'draft': False,
    'prerelease': False
}
json.dump(payload, open('/tmp/release-payload.json','w'))
" && gh api -X POST /repos/iannellomarco/macparakeet-dayjournal/releases --input /tmp/release-payload.json
# → outputs: {"id": 123456789, ...}

# 7. Upload DMG to release
RELEASE_ID=123456789  # from step 6
gh api --method POST \
  "https://uploads.github.com/repos/iannellomarco/macparakeet-dayjournal/releases/$RELEASE_ID/assets?name=MacParakeet-$VERSION.dmg" \
  -H "Content-Type: application/x-apple-diskimage" \
  --input dist/MacParakeet.dmg

# 8. Update appcast.xml with new:
#    - <sparkle:version> and <sparkle:shortVersionString>
#    - enclosure url (pointing to the new release download URL)
#    - sparkle:edSignature (from step 5)
#    - length (from step 5)
#    - <pubDate> (run: date -R)

# 9. Commit and push
git add appcast.xml
git commit -m "appcast v$VERSION"
git push origin main

# 10. Verify
curl -sI "https://iannellomarco.github.io/macparakeet-dayjournal/appcast.xml"
spctl --assess --verbose --type install dist/MacParakeet.dmg
```

## After release

- Pages auto-deploys on push to main (~30 seconds)
- Verify appcast: `curl -s "https://iannellomarco.github.io/macparakeet-dayjournal/appcast.xml"`
- Test update: install previous version, Sparkle should detect new version within a few hours

## Revoke credentials when done

- App-specific password: [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords
