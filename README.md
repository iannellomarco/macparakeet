<p align="center">
  <img src="Assets/AppIcon-1024x1024.png" width="96" height="96" alt="MacParakeet icon">
</p>

<h1 align="center">MacParakeet Day Journal</h1>

<p align="center">
  <strong>Your AI second brain for macOS.</strong><br>
  Captures your screen throughout the day, extracts what you're working on,<br>
  and builds a rich journal of your workday — cross-referenced with your meetings.
</p>

<p align="center">
  <a href="https://github.com/iannellomarco/macparakeet-dayjournal/releases/latest"><img src="https://img.shields.io/badge/Download-DMG-E86B3B.svg?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="GPL-3.0">
  <img src="https://img.shields.io/badge/macOS-14.2%2B-000000.svg" alt="macOS 14.2+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20only-333333.svg" alt="Apple Silicon">
</p>

---

## What it does

**Day Journal captures your workday, analyzes it with AI, and builds a narrative you can review, question, and save.**

It takes periodic screenshots, extracts text on-device using Apple Vision, and sends only the text to your AI provider for analysis. The AI tracks what apps you use, what documents you edit, what you research — and cross-references it all with your meeting transcripts from the same day.

At the end of the day, you chat with the AI: it shows you what it observed, asks clarifying questions, and together you build a detailed journal entry.

### How it works

```
Screenshots (every 2 min)
    │
    ▼
On-device OCR (Vision framework) ── nothing leaves your Mac
    │
    ▼
AI batch analysis (every 30 min) ── your configured provider
    │
    ▼
Running day summary + questions
    │
    ▼
End-of-day chat panel ── you review, answer, clarify
    │
    ▼
Final journal saved ── with meeting context cross-referenced
```

### Privacy by design

- **Screenshots stay on your Mac.** Only OCR-extracted text goes to your AI provider.
- **On-device OCR** via Apple Vision framework — no cloud, no accounts.
- **YOU choose the AI provider** — cloud (Anthropic, OpenAI, Gemini), local (Ollama, LM Studio), or CLI tools.
- **Same privacy model as MacParakeet upstream** — no telemetry on journal content, no accounts.

### Built on MacParakeet

This is a fork of [moona3k/macparakeet](https://github.com/moona3k/macparakeet) — the fast, private, local-first voice app for Mac. All upstream features are included: dictation, file transcription, meeting recording, WhisperKit multilingual STT, Transforms, and more. Day Journal is added as a fourth capture mode.

---

## Day Journal UI

### Transcribe tab — Start Journaling

The journal tile lives on the Transcribe tab alongside dictation and meeting recording.

**Idle state:** Shows what the feature does with clean bullet points. One click to start.

**Recording state:** Pulsing red indicator, elapsed timer, live capture count. Prominent Stop & Review and Discard buttons.

**Computing state:** Spinner with contextual message — "The AI is writing your day narrative" or "Analyzing your latest screen captures."

### End-of-day chat panel

When you stop journaling, an NSPanel opens with the AI's observations.

**AI message cards:** Structured with avatar, content area, and streaming dots. Markdown rendering for formatted content — headers, bold, lists render natively.

**Chat input:** Text field with send button. Collapsible notes section for adding personal context to your journal entry.

**Actions:** "Save Journal" and "Discard" buttons in a bottom bar with clear visual hierarchy. Escape key closes.

### Journal library — browse past days

Reachable from the sidebar. A **week calendar grid** at the top shows which days have entries with subtle blue dots. Click a day to see its journal.

**Timeline list:** Each entry shows time, duration, a content preview, and metadata (screenshot count). Click to open full detail.

**Day detail view:** Stats card at top (captures, duration, meetings), followed by the full journal narrative in Markdown. User notes section below if present. All text is selectable.

### Settings

Compact settings in the Modes tab: screenshot interval, analysis interval, idle pause toggle, storage retention. All with contextual help text. No redundant permission section — Screen Recording permission is already managed in the main Settings.

---

## Get it

**[Download the latest DMG](https://github.com/iannellomarco/macparakeet-dayjournal/releases/latest)**

Drag to `/Applications`. First launch downloads the speech model (~6 GB). Day Journal requires Screen Recording permission (requested in Settings or on first journaling start) and an AI provider configured in Settings → AI Provider.

Auto-updates via Sparkle from our [GitHub Pages appcast](https://iannellomarco.github.io/macparakeet-dayjournal/appcast.xml) — EdDSA signed.

### Build from source

```bash
git clone https://github.com/iannellomarco/macparakeet-dayjournal.git
cd macparakeet-dayjournal
swift test
scripts/dev/run_app.sh
```

---

## Settings reference

| Setting | Options | Default |
|---------|---------|---------|
| Screenshot interval | 30s / 1m / 2m / 5m / 10m | 2 min |
| Analysis interval | 15m / 30m / 60m | 30 min |
| Pause when idle | On/Off + threshold (30s/60s/120s) | Off |
| Keep screenshots | 7d / 30d / 90d / Forever | 30 days |

---

## Architecture

```
JournalService (actor)
  ├── Capture loop: CGDisplayCreateImage → Vision OCR → save to DB + disk
  ├── Analysis loop: batch OCR text → LLMService.analyzeJournal()
  │   → extract running summary + questions → update DB
  └── Lifecycle: start / stop / cancel / finalize

JournalFlowCoordinator
  └── JournalChatPanelController (NSPanel)
      └── JournalChatPanel (SwiftUI) — multi-turn chat with AI
```

See [ADR-023](spec/adr/023-day-journal-screenshot-second-brain.md) for the full architectural decision record.

---

## License

GPL-3.0. Forked from [moona3k/macparakeet](https://github.com/moona3k/macparakeet).
