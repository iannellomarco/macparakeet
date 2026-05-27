# ADR-023: Day Journal — Screenshot Capture + AI-Driven Second Brain

> Status: **Accepted**  
> Date: 2026-05-27

## Context

MacParakeet captures speech (dictation, file transcription, meeting recording)
but has no way to capture the user's screen activity — reading code, browsing
research, writing documents, designing in Figma. A "second brain" feature that
periodically captures screenshots, extracts visible text on-device, and uses the
configured AI provider to build a day narrative would make MacParakeet a
complete workday-capture tool.

## Decision

Add a **Day Journal** feature as a fourth capture mode alongside dictation,
file transcription, and meeting recording. It is:

1. **Opt-in** — gated behind `AppFeatures.journalingEnabled`, defaults to `true`
   (opt-in via UI toggle in Settings).
2. **Passive** — user starts it in the morning, stops when the workday ends.
   Runs in background capturing screenshots at configurable intervals.
3. **Text-first** — screenshots are OCR'd on-device via the Vision framework.
   Only extracted text goes to the AI provider. Images stay local.
4. **Batch-analyzed** — periodic AI analysis (15-60 min intervals) builds a
   running day summary and generates clarification questions.
5. **Chat-driven finalization** — end-of-day chat panel where the AI presents
   observations and asks questions, the user clarifies, and a final day snapshot
   is saved.
6. **BYO-provider** — uses the existing `LLMService` / `RoutingLLMClient`
   provider architecture. Works with cloud, local (Ollama, LM Studio), and CLI
   subprocess providers. No bundled vision model.

## Rationale

- **Completes the capture picture.** Speech + screen = complete workday context
  without surveillance. The user controls start/stop.
- **Privacy by architecture.** Screenshots stay on-device. Only OCR-extracted
  text goes to the user's explicitly configured AI provider. Follows the same
  privacy boundary as transcript → LLM.
- **Simplicity.** One start button, one stop button, one chat at the end.
  No per-app rules, no tagging, no search in v1.
- **Reuses existing infrastructure.** Prompt Library, LLMService, ScreenCaptureKit
  (already imported for meeting audio), AppFeatures gating pattern.

## Data Model

Four new tables in the existing `macparakeet.db`:

| Table | Purpose |
|-------|---------|
| `journal_sessions` | One row per day/journal session. Status: recording → reviewing → completed/cancelled. |
| `journal_screenshots` | Individual captures with OCR text, confidence, display metadata. Cascade-deletes with session. |
| `journal_analysis_runs` | Periodic batch analysis records. Links OCR input → AI output → extracted questions. |
| `journal_questions` | AI-generated clarification questions with answer/dismiss tracking. |

Migration `v0.20-journal-tables` creates these. Migration `v0.21-drop-legacy-screenshot-entries`
cleans up a vestigial `screenshot_entries` table from a prior experiment.

Screenshot files stored in `~/Library/Application Support/MacParakeet/journal/{sessionId}/`.

## Architecture

```
JournalService (actor)
  ├── capture loop: CGDisplayCreateImage → OCR (Vision) → save to DB + disk
  ├── analysis loop: batch OCR text → LLMService.generatePromptResultDetailed()
  │   → extract running summary + questions → update DB
  └── lifecycle: start / stop / cancel / finalize

JournalFlowCoordinator
  └── JournalChatPanelController (NSPanel)
      └── JournalChatPanel (SwiftUI) — multi-turn chat with AI
```

New Core services:
- `ScreenshotCaptureService` — `CGDisplayCreateImage` + JPEG encoding
- `ScreenshotOCRService` — `VNRecognizeTextRequest` with `.accurate` level
- `JournalIdleDetector` — `CGEventSource.secondsSinceLastEventType`
- `JournalStorageManager` — file I/O, retention enforcement
- `JournalQuestionTracker` — parse AI output for questions, sync with DB
- `JournalBatchAnalyzer` — batch OCR → LLM → summary + questions
- `JournalService` — actor orchestrating all of the above

New ViewModels:
- `JournalControlViewModel` — start/stop/cancel/finalize, elapsed timer
- `JournalChatViewModel` — streaming end-of-day chat
- `JournalSettingsViewModel` — intervals, idle skip, retention
- `JournalLibraryViewModel` — browse past sessions

New Views:
- `JournalControlView` — Transcribe tab tile (idle/recording/reviewing states)
- `JournalChatPanel` — end-of-day NSPanel chat interface
- `JournalChatPanelController` — NSPanel lifecycle management
- `JournalLibraryView` — date-grouped list of past entries
- `JournalDayDetailView` — read-only detail for a past entry
- `JournalSettingsSection` — settings controls in Modes tab
- `JournalFlowCoordinator` — wires ViewModel callbacks to panel lifecycle

Built-in prompt "Daily Journal Analysis" (category `.journal`) seeded via the
existing `Prompt.builtInPrompts()` reconciler.

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Screenshot interval | 30s / 1m / 2m / 5m / 10m | 2 min |
| Analysis interval | 15m / 30m / 60m | 30 min |
| Idle skip | On/Off + threshold (30s/60s/120s) | Off |
| Storage retention | 7d / 30d / 90d / Forever | 30 days |

## Privacy & Security

- Screenshots are user data. Never deleted without explicit confirmation.
- OCR text treated identically to transcript text per ADR-002.
- Telemetry never includes screenshots, OCR text, or journal content.
- Feature is opt-in. Recording indicator in menu bar when active.
- Screen Recording permission required (same permission as meeting recording).

## Consequences

- Four new database tables in the single `macparakeet.db` file.
- ~72 MB/day storage at 2-minute intervals with JPEG quality 0.7.
- LLM API cost: ~$0.01-0.02/day with batch analysis (negligible).
- No new external dependencies. All frameworks (Vision, CoreGraphics,
  ScreenCaptureKit) already in the dependency tree.
- Journaling runs concurrently with dictation and meeting recording without
  conflicts (separate pipelines, no STT contention).
