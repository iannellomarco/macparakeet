# MacParakeet Day Journal — Project Context

> Drop this into a new Claude window to continue development seamlessly.
> Last updated: 2026-05-27 @ 20:20 UTC

## What this project is

A fork of [moona3k/macparakeet](https://github.com/moona3k/macparakeet) — the fast, private, local-first voice app for macOS — with a **Day Journal** feature added as a fourth capture mode. Periodically captures screenshots, extracts text on-device via Apple Vision OCR, sends text to the user's configured AI provider for batch analysis, and builds a "second brain" journal of the workday. Cross-references meeting transcripts.

**Repo:** https://github.com/iannellomarco/macparakeet-dayjournal (public)
**Pages:** https://iannellomarco.github.io/macparakeet-dayjournal/
**Latest release:** v0.6.1
**License:** GPL-3.0

## Tech stack

| Layer | Choice |
|-------|--------|
| Platform | macOS 14.2+, Apple Silicon only |
| Language | Swift 6.0 + SwiftUI |
| Database | SQLite via GRDB |
| STT | Parakeet TDT via FluidAudio CoreML (default) + optional WhisperKit |
| AI providers | Anthropic, OpenAI, Gemini, OpenRouter, Ollama, LM Studio, Local CLI |
| Updates | Sparkle 2, EdDSA-signed appcast on GitHub Pages |
| Screenshots | CGDisplayCreateImage → Vision framework OCR → LLMService.analyzeJournal() |

## Architecture

```
Sources/
  MacParakeetCore/           — Pure Swift library (no SwiftUI)
    Services/Journal/        — 7 new services
      JournalService.swift           — actor orchestrating capture + analysis loops
      ScreenshotCaptureService.swift — CGDisplayCreateImage + JPEG
      ScreenshotOCRService.swift     — VNRecognizeTextRequest
      JournalBatchAnalyzer.swift     — batch OCR → LLMService.analyzeJournal()
      JournalQuestionTracker.swift   — parse AI output for questions
      JournalIdleDetector.swift      — CGEventSource activity check
      JournalStorageManager.swift    — file I/O + retention
    Models/                  — JournalSession, JournalScreenshot, JournalAnalysisRun, JournalQuestion
    Database/                — 4 repositories (one per table)
    Services/LLM/LLMService.swift   — added analyzeJournal() method

  MacParakeetViewModels/Journal/  — 4 ViewModels
    JournalControlViewModel.swift    — start/stop/cancel/finalize, elapsed timer
    JournalChatViewModel.swift       — streaming end-of-day chat
    JournalSettingsViewModel.swift   — intervals, idle skip, retention
    JournalLibraryViewModel.swift    — browse past sessions

  MacParakeet/Views/Journal/    — 6 views + 1 controller
    JournalControlView.swift         — Transcribe tab tile
    JournalChatPanel.swift           — end-of-day NSPanel chat
    JournalChatPanelController.swift — NSPanel lifecycle
    JournalLibraryView.swift         — week calendar + timeline list
    JournalDayDetailView.swift       — stats card + Markdown journal
    JournalSettingsSection.swift     — compact settings

  MacParakeet/App/
    JournalFlowCoordinator.swift     — wires ViewModel callbacks → NSPanel
    AppEnvironment.swift             — creates JournalService + repos
    AppEnvironmentConfigurer.swift   — wires journal ViewModels
    AppWindowCoordinator.swift       — passes journal VMs to MainWindowView
    AppDelegate.swift                — owns journal VMs, creates JournalFlowCoordinator
```

## Database (GRDB)

Four new tables in `macparakeet.db`:

| Table | Purpose |
|-------|---------|
| `journal_sessions` | One row per session. Status: recording → reviewing → completed/cancelled |
| `journal_screenshots` | Individual captures with OCR text, confidence, display metadata |
| `journal_analysis_runs` | Periodic batch analysis. Links OCR input → AI output → questions |
| `journal_questions` | AI-generated questions with answer/dismiss tracking |

Migrations: `v0.20-journal-tables` (create), `v0.21-drop-legacy-screenshot-entries` (cleanup from prior experiment).

Screenshots stored in `~/Library/Application Support/MacParakeet/journal/{sessionId}/`.

## LLM integration

Dedicated method on `LLMServiceProtocol`:

```swift
func analyzeJournal(
    ocrText: String,
    runningSummary: String,
    meetingContext: String,
    pendingQuestions: String,
    screenshotCount: Int
) async throws -> LLMResult
```

Also: same-day meeting transcripts fetched from `TranscriptionRepository` and included in both batch analysis and final snapshot generation.

## Feature flow

```
Start → screenshots every 2 min → on-device OCR → batch AI analysis every 30 min
→ running summary + questions → Stop & Review → chat panel → Save → journal entry
```

Settings: capture interval, analysis interval, idle pause, storage retention.

## Update channel

**Appcast:** `https://iannellomarco.github.io/macparakeet-dayjournal/appcast.xml`
**EdDSA public key:** `N/L9A3Dq0CVwDIlibInW1J7EW4ctRc6TyzidwwLH/PE=`
**Private key:** macOS Keychain (generated with `generate_keys`)

Release flow documented in `RELEASE.md`.

## Verification

- **Build:** `swift build` — clean
- **Tests:** `swift test` — 3045 tests, 0 failures
- **Dev run:** `scripts/dev/run_app.sh`
- **Gatekeeper:** `spctl --assess --verbose --type install dist/MacParakeet.dmg`

## Key files to know

| File | Why |
|------|-----|
| `CLAUDE.md` | Full project context for coding agents |
| `AGENTS.md` | Cross-agent guide |
| `RELEASE.md` | Step-by-step release workflow |
| `spec/adr/023-day-journal-screenshot-second-brain.md` | Architecture decision record |
| `plans/completed/2026-05-screenshot-day-journal.md` | Original implementation plan |
| `scripts/dist/build_app_bundle.sh` | Build + SUFeedURL + SUPublicEDKey |
| `scripts/dist/sign_notarize.sh` | Sign + notarize + DMG |
| `scripts/dist/generate_appcast.sh` | Appcast XML generator |

## Current state

- Feature is **production-ready**, enabled by default (`AppFeatures.journalingEnabled = true`)
- UI overhaul done: animated recording indicator, Markdown rendering, calendar grid, stats cards
- 5 releases shipped: v0.6.0-journal.1 through v0.6.1
- Update channel verified working with EdDSA

## What might need work

1. **Per-app exclusion** — skip screenshots when specific apps are frontmost (1Password, banking)
2. **Screenshot gallery** — browse captured images within a journal entry
3. **CLI commands** — `macparakeet-cli journal` for headless journal management
4. **Vision model path** — optionally send actual screenshots to vision-capable AI providers
5. **Export formats** — export journal entries as Markdown, PDF
6. **Better error handling** — surface AI provider failures in the UI, not just logs
7. **Integration tests** — for JournalService with mock dependencies
