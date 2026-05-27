# MacParakeet Day Journal v0.6.0-journal.5

## Changes
- **Public repo** — repository is now public at [github.com/iannellomarco/macparakeet-dayjournal](https://github.com/iannellomarco/macparakeet-dayjournal)
- **GitHub Pages update channel** — auto-updates served from [iannellomarco.github.io/macparakeet-dayjournal/appcast.xml](https://iannellomarco.github.io/macparakeet-dayjournal/appcast.xml)
- **Dedicated `analyzeJournal` LLM method** on `LLMServiceProtocol`
- **Clickable journal entries** with calendar date navigation
- **Meeting transcript integration** — same-day meeting transcripts cross-referenced with screen activity
- **Loading indicators** during computing transitions

## Verify
```bash
shasum -a 256 MacParakeet.dmg
# fe6eb13668c28b3855342b460ec4d4920a77be1b79e275a414b4c594cf6025c9
spctl --assess --verbose --type install MacParakeet.dmg
```

## Requirements
- macOS 14.2+, Apple Silicon only
- Screen Recording permission
- AI provider configured in Settings
