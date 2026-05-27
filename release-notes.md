# MacParakeet Day Journal v0.6.0-journal.4

## Changes in v0.6.0-journal.4

- **Dedicated `analyzeJournal` LLM method** — the journal pipeline now uses a purpose-built method on `LLMServiceProtocol` instead of abusing the transcript summary API. Cleaner separation, proper system/user prompt structure.
- **Fork update channel** — auto-updates now point to this fork's appcast instead of upstream MacParakeet. Set via `SU_FEED_URL` in the build.
- **All v0.6.0-journal.3 fixes included** — clickable journal entries, calendar navigation, loading indicators, meeting context integration

## Verify

```bash
# SHA-256
shasum -a 256 MacParakeet.dmg
# ef84f736e9641b7cc9994133905aca172a34caf08bb59fefd549ecdde5ada6a1

# Gatekeeper
spctl --assess --verbose --type install MacParakeet.dmg
```

## Requirements

- macOS 14.2+, Apple Silicon only
- Screen Recording permission
- AI provider configured in Settings
