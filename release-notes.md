# MacParakeet Day Journal v0.6.0-journal.2

Fork of [moona3k/macparakeet](https://github.com/moona3k/macparakeet) with the **Day Journal** feature.

## Changes in v0.6.0-journal.2 (hotfix)

- **LLM-powered final snapshot** — the "Save Day Snapshot" step now calls your AI provider to generate a proper narrative from the day's observations, instead of just concatenating raw text
- **Library auto-refresh** — journal library now updates immediately after saving a session
- **Empty-state guidance** — when no AI provider is configured, the journal entry now tells you "Make sure an AI provider is configured in Settings → AI Provider" instead of showing a blank page
- **Running summary fallback** — if the final snapshot is empty, the detail view now shows the raw running summary so you always see something

## What's New (v0.6.0-journal.1)

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

## Verify

```bash
# SHA-256
shasum -a 256 MacParakeet.dmg
# 5338d7debc2b6afb7b9413ecfbc41c67b15788bfa24b15a8cfe49cd7516f9de1

# Gatekeeper
spctl --assess --verbose --type install MacParakeet.dmg
```

## Requirements

- macOS 14.2+, Apple Silicon only
- Screen Recording permission (for screenshot capture)
- An AI provider configured in Settings (for analysis)
