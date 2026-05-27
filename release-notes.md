# MacParakeet Day Journal v0.6.0-journal.3

## Changes in v0.6.0-journal.3

- **Fixed AI prompt structure** — the journal analysis prompt is now properly split into system instructions + user content. The AI no longer responds with "please provide the transcript" and correctly analyzes the day's activity.
- **Clickable journal entries** — click any journal item in the library to open its full detail view
- **Calendar navigation** — date picker lets you jump to any day to see its journal
- **Loading indicators** — "Computing..." spinner shown during stop and finalize transitions so you know the AI is working
- **Meeting context integration** — same-day meeting transcripts are now included in both batch analysis and final snapshots, so the AI can cross-reference what was discussed with what was on screen

## Verify

```bash
# SHA-256
shasum -a 256 MacParakeet.dmg
# 07ff2cc15224060faf52fce0f11d3251618a8a7637cea86fae57bf7d564f10d0

# Gatekeeper
spctl --assess --verbose --type install MacParakeet.dmg
```

## Requirements

- macOS 14.2+, Apple Silicon only
- Screen Recording permission
- AI provider configured in Settings
