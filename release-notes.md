# MacParakeet Day Journal v0.6.0-journal.1

Fork of [moona3k/macparakeet](https://github.com/moona3k/macparakeet) with the **Day Journal** feature — a fourth capture mode for building a "second brain" from your workday.

## What's New

### Day Journal (ADR-023)
- **Periodic screenshot capture** at configurable intervals (30s–10min), with idle detection
- **On-device OCR** via Vision framework — extracts text from screenshots locally
- **AI-driven analysis** — periodic batch analysis (15–60min) builds a running day narrative
- **Clarification questions** — the AI notes things it doesn't understand and asks you at the end of the day
- **End-of-day chat panel** — review your day with the AI, answer its questions, add your own notes
- **Day snapshot** — final journal entry saved to your library
- **Journal library** — browse past day entries with full detail view
- **Text-first privacy** — only OCR-extracted text goes to your AI provider, screenshots stay on-device
- **BYO-provider** — works with all existing LLM providers (cloud, local Ollama/LM Studio, CLI tools)

### Settings
- Screenshot interval, analysis interval, idle skip toggle, storage retention (7d/30d/90d/forever)
- Screen Recording permission management

## Technical Details

- 4 new database tables in the existing `macparakeet.db`
- 29 new files, 16 modified
- 30 new tests, all 3045 tests passing
- Uses existing `LLMService` / `RoutingLLMClient` provider architecture
- Screenshots stored in `~/Library/Application Support/MacParakeet/journal/`

## Verify

```bash
# SHA-256
shasum -a 256 MacParakeet.dmg
# 3d58bd013fc173b25f6c386833cb93aa62793d43e4741654870a15ed6f792c99

# Gatekeeper
spctl --assess --verbose --type execute MacParakeet.dmg
```

## Requirements

- macOS 14.2+, Apple Silicon only
- Screen Recording permission (for screenshot capture)
- An AI provider configured in Settings (for analysis)
