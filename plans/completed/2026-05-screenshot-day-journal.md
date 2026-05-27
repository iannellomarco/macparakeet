# Screenshot Day Journal — Second Brain

Status: **ACTIVE**
Owner: Core app team
Updated: 2026-05-27
Related ADRs: `spec/adr/002-local-only.md`, `spec/adr/011-llm-cloud-and-local-providers.md`, `spec/adr/013-prompt-library-multi-summary.md`, `spec/adr/022-transforms-system-wide-rewrite.md`
Related specs: `spec/00-vision.md`, `spec/01-data-model.md`, `spec/03-architecture.md`, `spec/11-llm-integration.md`, `spec/12-processing-layer.md`, `spec/13-agent-workflows.md`
Discovery report: inline (Phase 1 discovery completed 2026-05-27)

## Decision

MacParakeet should add an opt-in **Day Journal** mode — a fourth capture surface
alongside dictation, file transcription, and meeting recording. It periodically
captures screenshots, extracts visible text on-device via the Vision framework,
batches that text to the user's configured AI provider for analysis and question
generation, and surfaces an end-of-day review chat where the AI asks
clarifications before a final day snapshot is saved.

This stays text-first (OCR → LLM) so it works with **every** existing provider
including local-only (Ollama, LM Studio) and CLI subprocess tools. No bundled
vision model. No default provider. Strictly opt-in.

## Product Thesis

1. **Passive capture.** Unlike dictation/meeting recording (user-initiated),
   journaling runs in the background. The user starts it in the morning and
   stops it when the workday ends.
2. **Second brain, not surveillance.** The AI analyzes what's on screen to build
   a narrative of the day's work. It asks clarifying questions so the user can
   fill in context the screenshots missed. The output is a human-readable day
   summary, not a raw log.
3. **Text-first analysis.** Screenshots are OCR'd on-device. Only extracted text
   goes to the AI provider. Images stay local as a verification record the user
   can browse. This follows the same privacy boundary as transcript → LLM.
4. **Chat-driven finalization.** The end-of-day review is a conversation with
   the AI, not a static report. The AI presents observations and asks questions;
   the user clarifies; the AI merges everything into a final snapshot.
5. **Simplicity over power.** One start button, one stop button, one chat at the
   end. No per-app capture rules, no tagging, no search in v1.

## Rationale

MacParakeet already captures speech and meetings. Screenshots cover the
remaining work activity — reading code, browsing research, writing documents,
designing in Figma — that speech alone cannot capture. The three existing
modes plus journaling give the user a complete picture of their workday.

The text-first approach is a deliberate constraint:

- It keeps the feature working with every provider including local-only setups.
- It avoids the privacy cliff of sending screenshots to cloud AI.
- It follows the existing architecture: on-device processing (OCR = STT
  equivalent) → user's BYO provider for intelligence.
- It keeps API costs negligible. OCR text is ~200-500 tokens per screenshot;
  batched at 30min intervals, a full workday costs pennies even on cloud models.

## Scope

### In scope (v1)

- Periodic screenshot capture at configurable intervals (30s / 1m / 2m / 5m / 10m)
- On-device OCR via Vision framework (`VNRecognizeTextRequest`)
- Batch AI analysis at configurable intervals (15m / 30m / 60m) + on-demand
- Running day summary updated by AI each batch
- AI-generated clarification questions accumulated throughout the day
- End-of-day chat panel (following meeting Ask tab pattern) for review
- Final day snapshot saved as a journal entry in the library
- Menu bar recording indicator (following meeting pill pattern)
- Settings: capture interval, analysis interval, idle-skip toggle, storage retention
- Screenshot storage in `~/Library/Application Support/MacParakeet/journal/{sessionId}/`
- Feature gate via `AppFeatures.journalingEnabled` (default `false`)
- New database tables for sessions, screenshots, analysis runs, questions
- Built-in "Daily Journal Analysis" prompt in the Prompt Library

### Out of scope (v1)

- Sending actual screenshots to AI providers (vision model path)
- Per-app capture exclusion list (e.g., skip 1Password)
- Screen-change-based capture (only capture when screen content changes)
- Adaptive interval (dynamic timing based on activity)
- Journal search / full-text search across entries
- Export formats for journal entries
- Calendar integration (auto-start journal at workday start)
- iOS companion
- CLI commands for journaling
- Multiple session merging / cross-day analytics

### Invariants (must not change)

- No bundled LLM runtime (ADR-011). Journaling uses the existing BYO-provider
  pipeline exclusively.
- `MacParakeetCore` stays free of SwiftUI views. New services/models/repos
  in Core; ViewModels in ViewModels; views in MacParakeet.
- Audio/STT pipelines are untouched. Journaling is an independent feature.
- Database migration is additive only. No schema changes to existing tables.
- Telemetry never includes screenshots, OCR text, or journal content.
- Privacy model: screenshots are user data. Never deleted without explicit
  confirmation. OCR text treated the same as transcript text per ADR-002.
- Existing capture modes (dictation, file transcription, meeting recording)
  continue to function correctly while journaling is active.
- `swift test` must remain green and deterministic.

## Discovery Summary

See the Phase 1 discovery report for full details. Key findings:

- No existing screenshot infrastructure anywhere in the codebase.
- No active or completed plans overlap with screenshot journaling.
- `spec/13-agent-workflows.md` (PROPOSAL) and `2026-05-voice-command-agent-mode.md`
  (PROPOSED) are the closest related work but are speech-centric, not visual.
- `ScreenCaptureKit` is already in the dependency tree for meeting audio capture.
- The `LLMService` already supports chat, streaming, system prompts, and
  template variables (`{{userNotes}}`, `{{transcript}}`).
- Prompt Library (`prompts` table) + PromptResult (`summaries` table) provide
  the template and output storage patterns.
- `AppFeatures` pattern (from `AppFeatures.calendarEnabled`) is the established
  feature-gating mechanism.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Capture API | `SCScreenshotManager` primary, `CGDisplayCreateImage` fallback | Modern API, already in dep tree, clean CGImage output. Fallback for pre-14.4 macOS. |
| Capture timing | Fixed configurable interval + optional idle skip | Simple, predictable. Activity-gating and change-detection are future optimizations. |
| AI input | OCR-extracted text only (Vision framework, on-device) | Works with every provider. Privacy-aligned. Cheaper. Follows transcript→LLM pattern. |
| AI analysis timing | Configurable periodic batch (15m/30m/60m) + on-demand | Balances freshness with API cost. ~8-16 runs/workday. |
| Data model | 4 new tables: `journal_sessions`, `journal_screenshots`, `journal_analysis_runs`, `journal_questions` | Follows GRDB one-entity-per-table pattern. Questions separate from analysis for structured tracking. |
| End-of-day UX | Chat panel (NSPanel, following meeting Ask tab) → save final snapshot | Reuses proven patterns from ADR-018/ADR-020. |
| Feature gating | `AppFeatures.journalingEnabled = false` (default) | Follows `AppFeatures.calendarEnabled` pattern. Off by default, feature flag in specs. |
| Storage format | JPEG at quality 0.7, ~200-500KB per 5K screenshot | Balances file size and readability. |
| Storage retention | Configurable: 7d / 30d / 90d / forever | Default 30 days. Auto-cleanup at session end. |
| Prompt system | New built-in prompt: category `.journal`, template variables `{{ocrText}}`, `{{runningSummary}}`, `{{pendingQuestions}}` | Extends existing `Prompt.Category` and `PromptTemplateRenderer`. |
| Prompt category | New `Prompt.Category.journal` (stored as `"journal"`) | Follows `.summary` / `.transform` pattern from ADR-013/ADR-022. |
| Idle detection | CGEventSource `secondsSinceLastEventType`, configurable threshold (30s/60s/120s) | Simple, no permission needed. Stops capture when user isn't interacting. |

## Architecture Shape

```
Sources/
  MacParakeetCore/
    Services/
      Journal/
        JournalService.swift              -- actor, orchestrates full lifecycle
        ScreenshotCaptureService.swift    -- SCScreenshotManager + CGDisplay fallback
        ScreenshotOCRService.swift        -- Vision framework VNRecognizeTextRequest
        JournalBatchAnalyzer.swift        -- periodic batch orchestration + LLM calls
        JournalQuestionTracker.swift      -- accumulate, persist, resolve AI questions
    Models/
        JournalSession.swift              -- GRDB model
        JournalScreenshot.swift           -- GRDB model
        JournalAnalysisRun.swift          -- GRDB model
        JournalQuestion.swift             -- GRDB model
    Database/
        JournalSessionRepository.swift
        JournalScreenshotRepository.swift
        JournalAnalysisRunRepository.swift
        JournalQuestionRepository.swift
  MacParakeetViewModels/
    Journal/
      JournalControlViewModel.swift       -- start/stop, state observation
      JournalChatViewModel.swift          -- end-of-day chat (reuses TranscriptChatViewModel pattern)
      JournalSettingsViewModel.swift      -- interval config, storage, idle skip
      JournalLibraryViewModel.swift       -- browse saved day entries
  MacParakeet/
    Views/
      Journal/
        JournalControlView.swift          -- menu bar item + transcribe tile
        JournalChatPanel.swift            -- end-of-day NSPanel chat
        JournalLibraryView.swift          -- date-grouped list like Meetings
        JournalDayDetailView.swift        -- read a past day entry
        JournalSettingsSection.swift      -- settings UI
Tests/
  MacParakeetTests/
    Services/
      Journal/
        JournalServiceTests.swift
        ScreenshotCaptureServiceTests.swift
        ScreenshotOCRServiceTests.swift
        JournalBatchAnalyzerTests.swift
        JournalQuestionTrackerTests.swift
    Database/
        JournalSessionRepositoryTests.swift
        JournalScreenshotRepositoryTests.swift
        JournalAnalysisRunRepositoryTests.swift
        JournalQuestionRepositoryTests.swift
    ViewModels/
      Journal/
        JournalControlViewModelTests.swift
        JournalChatViewModelTests.swift
```

## New Files

| File | Target | Purpose |
|------|--------|---------|
| `Sources/MacParakeetCore/Models/JournalSession.swift` | Core | Session model (GRDB) |
| `Sources/MacParakeetCore/Models/JournalScreenshot.swift` | Core | Screenshot model (GRDB) |
| `Sources/MacParakeetCore/Models/JournalAnalysisRun.swift` | Core | Analysis batch model (GRDB) |
| `Sources/MacParakeetCore/Models/JournalQuestion.swift` | Core | Question model (GRDB) |
| `Sources/MacParakeetCore/Database/JournalSessionRepository.swift` | Core | Session CRUD |
| `Sources/MacParakeetCore/Database/JournalScreenshotRepository.swift` | Core | Screenshot CRUD |
| `Sources/MacParakeetCore/Database/JournalAnalysisRunRepository.swift` | Core | Analysis run CRUD |
| `Sources/MacParakeetCore/Database/JournalQuestionRepository.swift` | Core | Question CRUD |
| `Sources/MacParakeetCore/Services/Journal/JournalService.swift` | Core | Lifecycle orchestration actor |
| `Sources/MacParakeetCore/Services/Journal/ScreenshotCaptureService.swift` | Core | `SCScreenshotManager` + fallback |
| `Sources/MacParakeetCore/Services/Journal/ScreenshotOCRService.swift` | Core | Vision framework OCR |
| `Sources/MacParakeetCore/Services/Journal/JournalBatchAnalyzer.swift` | Core | Periodic batch + LLM |
| `Sources/MacParakeetCore/Services/Journal/JournalQuestionTracker.swift` | Core | Question lifecycle |
| `Sources/MacParakeetCore/Services/Journal/JournalIdleDetector.swift` | Core | CGEventSource activity check |
| `Sources/MacParakeetCore/Services/Journal/JournalStorageManager.swift` | Core | Retention cleanup, disk budget |
| `Sources/MacParakeetViewModels/Journal/JournalControlViewModel.swift` | ViewModels | Start/stop/state |
| `Sources/MacParakeetViewModels/Journal/JournalChatViewModel.swift` | ViewModels | End-of-day chat |
| `Sources/MacParakeetViewModels/Journal/JournalSettingsViewModel.swift` | ViewModels | Configuration |
| `Sources/MacParakeetViewModels/Journal/JournalLibraryViewModel.swift` | ViewModels | Browse saved entries |
| `Sources/MacParakeet/Views/Journal/JournalControlView.swift` | GUI | Menu bar + tile |
| `Sources/MacParakeet/Views/Journal/JournalChatPanel.swift` | GUI | NSPanel chat |
| `Sources/MacParakeet/Views/Journal/JournalLibraryView.swift` | GUI | Date-grouped list |
| `Sources/MacParakeet/Views/Journal/JournalDayDetailView.swift` | GUI | Read past entry |
| `Sources/MacParakeet/Views/Journal/JournalSettingsSection.swift` | GUI | Settings |
| `Tests/MacParakeetTests/Services/Journal/JournalServiceTests.swift` | Tests | Orchestration |
| `Tests/MacParakeetTests/Services/Journal/ScreenshotCaptureServiceTests.swift` | Tests | Capture with mock |
| `Tests/MacParakeetTests/Services/Journal/ScreenshotOCRServiceTests.swift` | Tests | OCR with fixture images |
| `Tests/MacParakeetTests/Services/Journal/JournalBatchAnalyzerTests.swift` | Tests | Batch + LLM mock |
| `Tests/MacParakeetTests/Services/Journal/JournalQuestionTrackerTests.swift` | Tests | Question CRUD |
| `Tests/MacParakeetTests/Database/JournalSessionRepositoryTests.swift` | Tests | Session CRUD |
| `Tests/MacParakeetTests/Database/JournalScreenshotRepositoryTests.swift` | Tests | Screenshot CRUD |
| `Tests/MacParakeetTests/Database/JournalAnalysisRunRepositoryTests.swift` | Tests | Analysis run CRUD |
| `Tests/MacParakeetTests/Database/JournalQuestionRepositoryTests.swift` | Tests | Question CRUD |
| `Tests/MacParakeetTests/ViewModels/Journal/JournalControlViewModelTests.swift` | Tests | ViewModel logic |
| `Tests/MacParakeetTests/ViewModels/Journal/JournalChatViewModelTests.swift` | Tests | Chat logic |

## Modified Files

| File | Change |
|------|--------|
| `Sources/MacParakeetCore/AppFeatures.swift` | Add `journalingEnabled: Bool = false` |
| `Sources/MacParakeetCore/Models/Prompt.swift` | Add `.journal` to `Category` enum (stored as `"journal"`) |
| `Sources/MacParakeetCore/Models/PromptTemplateRenderer.swift` | Register `{{ocrText}}`, `{{runningSummary}}`, `{{pendingQuestions}}` variables |
| `Sources/MacParakeetCore/Database/DatabaseManager.swift` | v0.20 migration: create 4 journal tables + seed journal built-in prompt |
| `Sources/MacParakeet/App/AppEnvironment.swift` | Create journal repositories, pass to ViewModels |
| `Sources/MacParakeet/App/AppEnvironmentConfigurer.swift` | Wire `JournalService` if `journalingEnabled` |
| `Sources/MacParakeet/App/AppDelegate.swift` | Menu bar journal state indicator |
| `Sources/MacParakeet/Views/MainWindowView.swift` | Add Journal to sidebar |
| `Sources/MacParakeet/Views/Transcription/TranscribeView.swift` | Add Journal tile (like Meeting Recording tile) |
| `Sources/MacParakeet/Views/Settings/SettingsView.swift` | Add Journal settings section |
| `Sources/MacParakeetViewModels/SettingsViewModel.swift` | Journal settings state |
| `Sources/MacParakeetViewModels/SettingsSearchIndex.swift` | Journal search entries (gated by `journalingEnabled`) |
| `Sources/MacParakeetCore/Services/System/PermissionService.swift` | Journal Screen Recording permission hook |
| `spec/01-data-model.md` | Document new journal tables |
| `spec/02-features.md` | Add v0.7 journaling feature entry |
| `spec/03-architecture.md` | Add JournalService to architecture diagram |
| `spec/kernel/requirements.yaml` | Add `REQ-JRNL-*` requirement IDs |
| `spec/kernel/traceability.md` | Map journal sources + tests |

## Database Schema

```sql
-- Active journal session (one at a time)
CREATE TABLE journal_sessions (
    id                TEXT PRIMARY KEY,
    createdAt         TEXT NOT NULL,
    endedAt           TEXT,
    status            TEXT NOT NULL DEFAULT 'recording',
    title             TEXT,
    runningSummary    TEXT,
    finalSnapshot     TEXT,
    userNotes         TEXT,
    screenshotCount   INTEGER NOT NULL DEFAULT 0,
    totalStorageBytes INTEGER NOT NULL DEFAULT 0,
    captureIntervalSecs INTEGER NOT NULL,
    analysisIntervalMins INTEGER NOT NULL,
    updatedAt         TEXT NOT NULL
);

-- Individual screenshots
CREATE TABLE journal_screenshots (
    id              TEXT PRIMARY KEY,
    sessionId       TEXT NOT NULL REFERENCES journal_sessions(id) ON DELETE CASCADE,
    capturedAt      TEXT NOT NULL,
    filePath        TEXT NOT NULL,
    ocrText         TEXT,
    ocrConfidence   REAL,
    fileSizeBytes   INTEGER,
    displayName     TEXT,
    displayWidth    INTEGER,
    displayHeight   INTEGER,
    isDiscarded     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_journal_screenshots_session
    ON journal_screenshots(sessionId, capturedAt);

-- Periodic AI analysis batches
CREATE TABLE journal_analysis_runs (
    id                TEXT PRIMARY KEY,
    sessionId         TEXT NOT NULL REFERENCES journal_sessions(id) ON DELETE CASCADE,
    runAt             TEXT NOT NULL,
    screenshotCount   INTEGER NOT NULL,
    ocrTextInput      TEXT NOT NULL,
    analysis          TEXT NOT NULL,
    questionsJSON     TEXT,
    providerModel     TEXT,
    latencyMs         INTEGER,
    wasUsed           INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX idx_journal_analysis_runs_session
    ON journal_analysis_runs(sessionId, runAt);

-- AI-generated clarification questions
CREATE TABLE journal_questions (
    id              TEXT PRIMARY KEY,
    sessionId       TEXT NOT NULL REFERENCES journal_sessions(id) ON DELETE CASCADE,
    analysisRunId   TEXT REFERENCES journal_analysis_runs(id) ON DELETE SET NULL,
    question        TEXT NOT NULL,
    userAnswer      TEXT,
    answeredAt      TEXT,
    status          TEXT NOT NULL DEFAULT 'pending',
    createdAt       TEXT NOT NULL
);
CREATE INDEX idx_journal_questions_session
    ON journal_questions(sessionId, status);
```

## Prompt Template Variables

The built-in "Daily Journal Analysis" prompt supports these template variables
(via `PromptTemplateRenderer`, following ADR-020 pattern):

| Variable | Source | Description |
|----------|--------|-------------|
| `{{ocrText}}` | New screenshots since last batch | Fresh OCR text to analyze |
| `{{runningSummary}}` | `journal_sessions.runningSummary` | AI's running day narrative so far |
| `{{pendingQuestions}}` | Unanswered `journal_questions` | Questions the AI asked earlier that the user hasn't answered yet |
| `{{timeOfDay}}` | `Date.now` | Current time for context |
| `{{screenshotCount}}` | Batch count | How many new screenshots in this batch |

## Built-in Journal Prompt

Seeded in the `prompts` table during the migration. Category = `.journal`,
`isBuiltIn = true`, `isVisible = true`, `isAutoRun = true` (auto-applied to
each batch analysis).

```text
You are a thoughtful workday observer helping the user build a "second brain"
journal of their day. You receive OCR-extracted text from periodic screenshots
of the user's screen.

Context:
- Current time: {{timeOfDay}}
- Screenshots in this batch: {{screenshotCount}}

Running day summary so far:
{{runningSummary}}

Pending questions you previously asked (not yet answered):
{{pendingQuestions}}

New screen content to analyze:
{{ocrText}}

Your task:

1. **Update the running summary.** Integrate the new observations into the
   running day narrative. Keep it concise but detailed — mention specific apps,
   documents, tasks the user appears to be working on. Use past tense for
   completed observations, present for ongoing work.

2. **Note unanswered observations.** If you see something you don't fully
   understand — an unfamiliar app, a cryptic document title, an ambiguous
   context — note it as a pending question. Be curious, not interrogative.
   Example: "At 2:15pm you were editing a spreadsheet called 'Q3 Budget
   Projections'. Was that for the Finance review on Friday?"

3. **Don't over-narrate repetition.** If the user stays in the same app doing
   the same thing for multiple batches, note it once and move on. Don't repeat
   "still in VS Code" every cycle.

4. **Be privacy-aware.** The OCR text captures what's visible on screen. If
   you detect sensitive content (passwords, personal financial details,
   private messages), do NOT reproduce it verbatim. Instead, describe the
   activity generically (e.g., "was reading personal messages" not "was reading
   message from Sarah about her medical results").

Output format:
---
## Updated Running Summary
(concise narrative updated with new batch)

## New Observations
- bullet list of specific new things noticed

## Pending Questions
- bullet list of clarification questions (add new ones, keep old ones that are
  still unanswered, remove any that look resolved by this batch)
---
```

The AI's raw analysis is stored in `journal_analysis_runs.analysis`. The
`runningSummary` field in `journal_sessions` is updated by extracting the
"Updated Running Summary" section. Questions are parsed from "Pending Questions"
and upserted into `journal_questions`.

## Implementation Steps

Execute in order. After each step, build and run `swift test` to catch breakage
early.

### Phase A — Foundation (data model + capture)

#### Step A1: Models

Create `Sources/MacParakeetCore/Models/JournalSession.swift`:

- Struct with `id`, `createdAt`, `endedAt`, `status` (enum: `.recording`,
  `.reviewing`, `.completed`, `.cancelled`), `title`, `runningSummary`,
  `finalSnapshot`, `userNotes`, `screenshotCount`, `totalStorageBytes`,
  `captureIntervalSecs`, `analysisIntervalMins`, `updatedAt`
- GRDB conformances: `Codable`, `FetchableRecord`, `PersistableRecord`,
  `Identifiable`, `Sendable`
- `databaseTableName = "journal_sessions"`
- `Columns` enum for GRDB filtering

Create `Sources/MacParakeetCore/Models/JournalScreenshot.swift`:

- Struct with `id`, `sessionId`, `capturedAt`, `filePath`, `ocrText`,
  `ocrConfidence`, `fileSizeBytes`, `displayName`, `displayWidth`,
  `displayHeight`, `isDiscarded`
- Same GRDB conformances
- `databaseTableName = "journal_screenshots"`

Create `Sources/MacParakeetCore/Models/JournalAnalysisRun.swift`:

- Struct with `id`, `sessionId`, `runAt`, `screenshotCount`, `ocrTextInput`,
  `analysis`, `questionsJSON`, `providerModel`, `latencyMs`, `wasUsed`
- Same GRDB conformances
- `databaseTableName = "journal_analysis_runs"`

Create `Sources/MacParakeetCore/Models/JournalQuestion.swift`:

- Struct with `id`, `sessionId`, `analysisRunId`, `question`, `userAnswer`,
  `answeredAt`, `status` (enum: `.pending`, `.answered`, `.dismissed`),
  `createdAt`
- Same GRDB conformances
- `databaseTableName = "journal_questions"`

#### Step A2: Repositories

Create `Sources/MacParakeetCore/Database/JournalSessionRepository.swift`:

- `JournalSessionRepositoryProtocol`: `save`, `fetch(id:)`, `fetchActive()`,
  `fetchAll(limit:)`, `updateStatus(id:status:)`, `updateRunningSummary(id:text:)`,
  `updateFinalSnapshot(id:text:userNotes:)`, `delete(id:)`
- Concrete `JournalSessionRepository` wrapping `DatabaseQueue`
- `fetchActive` returns the most recent session with `status = 'recording'`
  (at most one active session)
- `fetchAll` sorted by `createdAt` descending

Create `Sources/MacParakeetCore/Database/JournalScreenshotRepository.swift`:

- `JournalScreenshotRepositoryProtocol`: `save`, `fetch(id:)`,
  `fetchAll(sessionId:limit:)`, `fetchUnanalyzed(sessionId:since:)`,
  `markAnalyzed(ids:)`, `fetchCount(sessionId:)`, `fetchTotalStorage(sessionId:)`,
  `discardOlderThan(sessionId:before:)`, `deleteAll(sessionId:)`, `delete(id:)`
- `fetchUnanalyzed` returns screenshots whose `ocrText` is non-null and haven't
  been included in an analysis run yet (handled via tracking in
  `JournalBatchAnalyzer`, not an isAnalyzed column)
- `discardOlderThan` sets `isDiscarded = 1` for screenshots past retention

Create `Sources/MacParakeetCore/Database/JournalAnalysisRunRepository.swift`:

- `JournalAnalysisRunRepositoryProtocol`: `save`, `fetchAll(sessionId:)`,
  `fetchLatest(sessionId:)`, `markUnused(id:)`, `delete(id:)`
- `fetchAll` sorted by `runAt` ascending

Create `Sources/MacParakeetCore/Database/JournalQuestionRepository.swift`:

- `JournalQuestionRepositoryProtocol`: `save`, `fetchAll(sessionId:)`,
  `fetchPending(sessionId:)`, `answer(id:answer:)`, `dismiss(id:)`,
  `upsert(questions:sessionId:analysisRunId:)`, `delete(id:)`
- `upsert` matches by `question` text (case-insensitive) within the same
  session to avoid duplicates; new questions are inserted, unchanged ones
  are left alone, removed ones are deleted

#### Step A3: Migration

Add to `Sources/MacParakeetCore/Database/DatabaseManager.swift`:

```swift
// v0.20 — Day Journal
migrator.registerMigration("v0.20-journal-tables") { db in
    try db.create(table: "journal_sessions") { t in
        t.column("id", .text).primaryKey()
        t.column("createdAt", .text).notNull()
        t.column("endedAt", .text)
        t.column("status", .text).notNull().defaults(to: "recording")
        t.column("title", .text)
        t.column("runningSummary", .text)
        t.column("finalSnapshot", .text)
        t.column("userNotes", .text)
        t.column("screenshotCount", .integer).notNull().defaults(to: 0)
        t.column("totalStorageBytes", .integer).notNull().defaults(to: 0)
        t.column("captureIntervalSecs", .integer).notNull()
        t.column("analysisIntervalMins", .integer).notNull()
        t.column("updatedAt", .text).notNull()
    }

    try db.create(table: "journal_screenshots") { t in
        t.column("id", .text).primaryKey()
        t.column("sessionId", .text).notNull()
            .references("journal_sessions", onDelete: .cascade)
        t.column("capturedAt", .text).notNull()
        t.column("filePath", .text).notNull()
        t.column("ocrText", .text)
        t.column("ocrConfidence", .double)
        t.column("fileSizeBytes", .integer)
        t.column("displayName", .text)
        t.column("displayWidth", .integer)
        t.column("displayHeight", .integer)
        t.column("isDiscarded", .boolean).notNull().defaults(to: false)
    }
    try db.execute(sql: """
        CREATE INDEX idx_journal_screenshots_session
        ON journal_screenshots(sessionId, capturedAt)
    """)

    try db.create(table: "journal_analysis_runs") { t in
        t.column("id", .text).primaryKey()
        t.column("sessionId", .text).notNull()
            .references("journal_sessions", onDelete: .cascade)
        t.column("runAt", .text).notNull()
        t.column("screenshotCount", .integer).notNull()
        t.column("ocrTextInput", .text).notNull()
        t.column("analysis", .text).notNull()
        t.column("questionsJSON", .text)
        t.column("providerModel", .text)
        t.column("latencyMs", .integer)
        t.column("wasUsed", .boolean).notNull().defaults(to: true)
    }
    try db.execute(sql: """
        CREATE INDEX idx_journal_analysis_runs_session
        ON journal_analysis_runs(sessionId, runAt)
    """)

    try db.create(table: "journal_questions") { t in
        t.column("id", .text).primaryKey()
        t.column("sessionId", .text).notNull()
            .references("journal_sessions", onDelete: .cascade)
        t.column("analysisRunId", .text)
            .references("journal_analysis_runs", onDelete: .setNull)
        t.column("question", .text).notNull()
        t.column("userAnswer", .text)
        t.column("answeredAt", .text)
        t.column("status", .text).notNull().defaults(to: "pending")
        t.column("createdAt", .text).notNull()
    }
    try db.execute(sql: """
        CREATE INDEX idx_journal_questions_session
        ON journal_questions(sessionId, status)
    """)

    // Seed the built-in Daily Journal Analysis prompt
    try db.execute(sql: """
        INSERT INTO prompts (id, name, content, category, isBuiltIn, isVisible,
                            isAutoRun, sortOrder, createdAt, updatedAt)
        VALUES (
            '\(UUID().uuidString)',
            'Daily Journal Analysis',
            '<prompt content from §Built-in Journal Prompt above>',
            'journal',
            1,
            1,
            1,
            0,
            '\(ISO8601DateFormatter().string(from: Date()))',
            '\(ISO8601DateFormatter().string(from: Date()))'
        )
    """)
}
```

Add `.journal` to `Prompt.Category` enum in `Sources/MacParakeetCore/Models/Prompt.swift`:

```swift
public enum Category: String, Codable, Sendable {
    case result = "summary"
    case transform
    case journal
}
```

#### Step A4: Screenshot Capture Service

Create `Sources/MacParakeetCore/Services/Journal/ScreenshotCaptureService.swift`:

- Protocol `ScreenshotCaptureServiceProtocol`: `func captureAllDisplays() async throws -> [CapturedScreenshot]`
- Concrete `ScreenshotCaptureService`:
  - Uses `SCScreenshotManager` (macOS 14.4+) to capture all displays
  - Falls back to `CGDisplayCreateImage` for each active display on <14.4
  - Returns `CapturedScreenshot` struct: `cgImage`, `displayName`, `displayWidth`, `displayHeight`
  - Saves as JPEG (quality 0.7) to temp dir or journal folder
  - Request Screen Recording permission via existing `PermissionService`
  - If no Screen Recording permission, service returns empty array (no crash)
- `CapturedScreenshot` struct (not a DB model): `id: UUID`, `imageData: Data`,
  `displayName: String`, `displayWidth: Int`, `displayHeight: Int`,
  `capturedAt: Date`

Design notes:
- `@available(macOS 14.4, *)` guard on `SCScreenshotManager` path
- `CGDisplayCreateImage` returns `CGImage?` — nil means display is asleep/mirrored
- JPEG compression via `NSBitmapImageRep` or `CGImageDestination`

#### Step A5: Screenshot OCR Service

Create `Sources/MacParakeetCore/Services/Journal/ScreenshotOCRService.swift`:

- Protocol `ScreenshotOCRServiceProtocol`: `func extractText(from imageData: Data) async throws -> OCRResult`
- Concrete `ScreenshotOCRService`:
  - Uses `VNRecognizeTextRequest` with `.accurate` recognition level
  - Runs on a background `DispatchQueue` (not MainActor)
  - Returns `OCRResult`: `text: String`, `confidence: Float`
  - Handles empty/blank screenshots gracefully (returns empty text, 0.0 confidence)
- `OCRResult` struct: `text: String`, `confidence: Float`

Design notes:
- Vision requests are synchronous; wrap in `CheckedContinuation` for async/await
- Recognition level `.accurate` is ~2-3x slower than `.fast` but needed for
  code and dense text
- Revision 4+ of `VNRecognizeTextRequest` supports language correction toggle
  — use `recognitionLanguages = ["en"]` to bias English but don't restrict

#### Step A6: Idle Detector

Create `Sources/MacParakeetCore/Services/Journal/JournalIdleDetector.swift`:

- Protocol `JournalIdleDetectorProtocol`: `func isUserIdle(thresholdSeconds: Int) -> Bool`
- Concrete `JournalIdleDetector`:
  - Uses `CGEventSource.secondsSinceLastEventType(.combinedSessionState)` from
    `CoreGraphics`
  - Compares against configurable threshold
  - Pure function, no state — call each capture cycle

#### Step A7: Storage Manager

Create `Sources/MacParakeetCore/Services/Journal/JournalStorageManager.swift`:

- Protocol `JournalStorageManagerProtocol`:
  - `func saveScreenshot(id: UUID, imageData: Data, sessionId: UUID) throws -> URL`
  - `func deleteSessionFolder(sessionId: UUID) throws`
  - `func enforceRetention(retentionDays: Int, sessionId: UUID) throws`
  - `func storageUsedBytes(sessionId: UUID) throws -> Int64`
- Concrete `JournalStorageManager`:
  - Screenshot path: `journal/{sessionId}/screenshot_{id}.jpg`
  - Base path: `~/Library/Application Support/MacParakeet/journal/`
  - JPEG write via `Data.write(to:)`
  - Retention: `discardOlderThan` on screenshots + file deletion

### Phase B — Analysis Engine

#### Step B1: Question Tracker

Create `Sources/MacParakeetCore/Services/Journal/JournalQuestionTracker.swift`:

- Protocol `JournalQuestionTrackerProtocol`:
  - `func extractQuestions(from analysisText: String) -> [String]`
  - `func syncQuestions(sessionId: UUID, analysisRunId: UUID, questions: [String]) async throws`
  - `func fetchPending(sessionId: UUID) async throws -> [JournalQuestion]`
  - `func answer(questionId: UUID, answer: String) async throws`
  - `func dismiss(questionId: UUID) async throws`
- Extraction logic:
  - Parse the "## Pending Questions" section from the AI's analysis output
  - Match bullet points (lines starting with `-` or `*` after the header)
  - Fallback: if header not found, return empty array (no questions is valid)
- `syncQuestions` calls `JournalQuestionRepository.upsert` with the parsed list

#### Step B2: Batch Analyzer

Create `Sources/MacParakeetCore/Services/Journal/JournalBatchAnalyzer.swift`:

- Protocol `JournalBatchAnalyzerProtocol`:
  - `func analyzeBatch(sessionId: UUID) async throws -> JournalAnalysisRun`
  - `func schedulePeriodicAnalysis(sessionId: UUID, intervalMins: Int) -> AsyncStream<JournalAnalysisRun>`
- Concrete `JournalBatchAnalyzer`:
  - Depends on: `LLMServiceProtocol`, `JournalScreenshotRepository`,
    `JournalAnalysisRunRepository`, `JournalQuestionTracker`,
    `PromptTemplateRenderer`
  - Workflow:
    1. Fetch unanalyzed screenshots for this session
    2. Concatenate OCR text from each (capped at `cloudContextBudget` / `localContextBudget`)
    3. Render built-in journal prompt with template variables
    4. Call `LLMService.chat(user:transcript:userNotes:history:source:)` or
       `generatePromptResult(transcript:systemPrompt:)`
    5. Parse analysis output (running summary section, observations, questions)
    6. Save `JournalAnalysisRun` row
    7. Update `journal_sessions.runningSummary` with extracted summary
    8. Sync questions via `JournalQuestionTracker.syncQuestions`
    9. Emit analysis run to the periodic stream
- `schedulePeriodicAnalysis` uses `Task.sleep` loop, cancellable via
  `withTaskCancellationHandler`

Design notes:
- The "batch" concept: analysis always includes ALL unanalyzed screenshots since
  last analysis, not per-screenshot calls.
- Context budget: use `LLMService.cloudContextBudget` / `.localContextBudget`
  based on whether the provider is local. Cap OCR text at 80% of budget to leave
  room for prompt + response.
- Analysis prompt uses `LLMService.generatePromptResult` (system prompt) path
  — the journal prompt IS the system prompt.

#### Step B3: Orchestration Service

Create `Sources/MacParakeetCore/Services/Journal/JournalService.swift`:

- `actor JournalService`:
  - Depends on: `ScreenshotCaptureService`, `ScreenshotOCRService`,
    `JournalBatchAnalyzer`, `JournalIdleDetector`, `JournalStorageManager`,
    `JournalSessionRepository`, `JournalScreenshotRepository`,
    `JournalAnalysisRunRepository`, `JournalQuestionRepository`
  - State enum: `.idle`, `.recording(sessionId: UUID)`, `.reviewing(sessionId: UUID)`
  - Public API:
    - `func startSession(captureIntervalSecs: Int, analysisIntervalMins: Int, idleSkipEnabled: Bool, idleThresholdSecs: Int) async throws -> JournalSession`
    - `func stopSession() async throws -> JournalSession`
    - `func cancelSession() async throws`
    - `func finalizeSession(userNotes: String) async throws -> JournalSession`
    - `func startReview() async throws -> JournalSession`
    - `var currentState: JournalState { get }`
  - Internal loop (while `.recording`):
    1. Check idle detector (skip if idle and `idleSkipEnabled`)
    2. `ScreenshotCaptureService.captureAllDisplays()`
    3. For each capture: `ScreenshotOCRService.extractText(from:)`
    4. Save `JournalScreenshot` row to DB
    5. Save image to disk via `JournalStorageManager`
    6. If analysis interval has elapsed: `JournalBatchAnalyzer.analyzeBatch(sessionId:)`
    7. Sleep for `captureIntervalSecs`
  - On stop:
    - Cancel capture loop
    - Run a final batch analysis (catch up on remaining screenshots)
    - Transition to `.reviewing`
  - On finalize:
    - Generate final day snapshot via LLM
    - Save to `journal_sessions.finalSnapshot`
    - Set `endedAt`, status → `.completed`
  - Telemetry: `journal_session_started`, `journal_session_completed`,
    `journal_analysis_run` events. Never includes OCR text or screenshot data.

Journal service telemetry events (following `TelemetryEvent` pattern):

```
- journal_session_started: sessionId, captureIntervalSecs, analysisIntervalMins, idleSkipEnabled
- journal_session_ended: sessionId, durationSecs, screenshotCount, analysisRunCount
- journal_session_cancelled: sessionId, durationSecs, screenshotCount
- journal_analysis_run: sessionId, screenshotCount, inputChars, outputChars, latencyMs, provider
```

### Phase C — UI

#### Step C1: Feature Gate

Edit `Sources/MacParakeetCore/AppFeatures.swift`:

```swift
public struct AppFeatures {
    public static let calendarEnabled: Bool = true
    public static let transformsEnabled: Bool = true
    public static let journalingEnabled: Bool = false  // NEW — opt-in, off by default
}
```

All journal UI and service wiring is gated behind `AppFeatures.journalingEnabled`.

#### Step C2: ViewModels

Create `Sources/MacParakeetViewModels/Journal/JournalControlViewModel.swift`:

- `@MainActor @Observable final class JournalControlViewModel`:
  - `var isJournaling: Bool` — observed by menu bar and tile
  - `var isReviewing: Bool` — end-of-day panel state
  - `var activeSessionId: UUID?`
  - `var screenshotCount: Int` — updated via timer during recording
  - `var lastAnalysisAt: Date?`
  - `func startJournaling(captureIntervalSecs: Int, analysisIntervalMins: Int)`
  - `func stopJournaling()`
  - `func cancelJournaling()`
  - `func startReview()`
  - Observes `JournalService` state

Create `Sources/MacParakeetViewModels/Journal/JournalChatViewModel.swift`:

- `@MainActor @Observable final class JournalChatViewModel`:
  - `var messages: [ChatMessage]` — chat history
  - `var isStreaming: Bool`
  - `var currentInput: String`
  - `var canFinalize: Bool`
  - `func loadReview(sessionId: UUID)` — initializes chat with AI's observations + questions
  - `func sendMessage(_ text: String)` — sends user response, gets AI follow-up
  - `func finalizeSession()` — triggers final snapshot generation
  - Reuses `LLMService.chatStream()` pattern from `TranscriptChatViewModel`

Create `Sources/MacParakeetViewModels/Journal/JournalSettingsViewModel.swift`:

- `@MainActor @Observable final class JournalSettingsViewModel`:
  - `var captureInterval: JournalCaptureInterval` — persisted to UserDefaults
  - `var analysisInterval: JournalAnalysisInterval` — persisted to UserDefaults
  - `var idleSkipEnabled: Bool` — persisted to UserDefaults
  - `var idleThresholdSecs: Int` — persisted to UserDefaults
  - `var retentionDays: Int` — persisted to UserDefaults
  - `var hasScreenRecordingPermission: Bool`

Create `Sources/MacParakeetViewModels/Journal/JournalLibraryViewModel.swift`:

- `@MainActor @Observable final class JournalLibraryViewModel`:
  - `var sessions: [JournalSession]` — sorted by date descending
  - `func loadSessions()`
  - `func deleteSession(id: UUID)`
  - Follows `TranscriptionLibraryViewModel` pattern

#### Step C3: SwiftUI Views

Create `Sources/MacParakeet/Views/Journal/JournalControlView.swift`:

- Small tile on Transcribe tab (like Meeting Recording tile) when journaling
  is enabled but not active
- Shows "Start Day Journal" with subtitle "Capture your workday for later review"
- During recording: shows elapsed time + screenshot count + last analysis time
- During reviewing: shows "Review your day" with chat prompt

Create `Sources/MacParakeet/Views/Journal/JournalChatPanel.swift`:

- `NSPanel` with `.nonactivatingPanel` behavior
- Following meeting panel pattern (`MeetingRecordingPanelView`)
- Chat interface with message bubbles
- AI messages: observations + questions displayed as structured cards
- User input: text field at bottom
- "Save Day Snapshot" button (finalize)
- "Discard" button (cancel)

Create `Sources/MacParakeet/Views/Journal/JournalLibraryView.swift`:

- Date-grouped list (Today, Yesterday, specific dates)
- Each row: date title, screenshot count, AI summary snippet
- Click opens `JournalDayDetailView`
- Right-click: Delete
- Follows Meetings library list pattern (`MeetingRowCard`/`MeetingDateGroupHeader`)

Create `Sources/MacParakeet/Views/Journal/JournalDayDetailView.swift`:

- Read-only view of a past day entry
- Shows: title, date, duration, screenshot count
- Full AI final snapshot text (scrollable)
- Screenshot gallery (grid of thumbnails, click to enlarge)
- User's notes from the review chat

Create `Sources/MacParakeet/Views/Journal/JournalSettingsSection.swift`:

- Section in Settings → Modes (or new Journal tab)
- Capture interval picker: 30s / 1m / 2m / 5m / 10m
- Analysis interval picker: 15m / 30m / 60m
- Idle skip toggle + threshold: 30s / 60s / 120s
- Storage retention picker: 7d / 30d / 90d / forever
- Current storage used display
- "Clear all journal data" button with confirmation
- Screen Recording permission status

#### Step C4: Menu Bar Integration

Edit `Sources/MacParakeet/App/AppDelegate.swift`:

- Add journal state to menu bar icon priority (meeting > journal > dictation >
  file-transcription > idle)
- Journal recording indicator: distinct icon or color change
- Menu item: "Start Day Journal" / "Stop Day Journal" / "Review Day"
- Gated behind `AppFeatures.journalingEnabled`

#### Step C5: App Wiring

Edit `Sources/MacParakeet/App/AppEnvironment.swift`:

- Add journal repositories as lazy vars, gated by `journalingEnabled`
- Add `JournalService` as lazy var, wired with dependencies

Edit `Sources/MacParakeet/App/AppEnvironmentConfigurer.swift`:

- Wire journal service into environment when `journalingEnabled`

Edit `Sources/MacParakeet/Views/MainWindowView.swift`:

- Add "Journal" to sidebar (between Library and Dictations), gated by
  `journalingEnabled`
- Content: `JournalLibraryView` when Journal is selected

### Phase D — Polish

#### Step D1: Prompt Template Variables

Edit `Sources/MacParakeetCore/Models/PromptTemplateRenderer.swift`:

- Register `{{ocrText}}` → replaced with current batch OCR text
- Register `{{runningSummary}}` → replaced with `journal_sessions.runningSummary`
- Register `{{pendingQuestions}}` → replaced with formatted pending question list
- Register `{{timeOfDay}}` → replaced with current time string
- Register `{{screenshotCount}}` → replaced with batch screenshot count

#### Step D2: Final Day Snapshot Generation

When user clicks "Save Day Snapshot" in the chat panel:

1. Compile all context:
   - Full running summary
   - All answered questions (Q&A pairs)
   - User's final notes from chat
   - Dismissed questions (noted as "user chose not to answer")
2. Send to LLM with a "Final Day Snapshot" system prompt:
   ```
   Create a detailed, narrative description of the user's workday.
   Include: apps used, tasks worked on, decisions made, context about
   why things were done (from the user's answers to your questions).
   Format as a well-written journal entry.
   ```
3. Store result in `journal_sessions.finalSnapshot` + `userNotes`
4. Set status → `.completed`

#### Step D3: Screenshot Gallery

In `JournalDayDetailView`:

- Grid of thumbnail images (3-4 per row)
- Click to open full-size in QuickLook or NSWindow
- Filter by hour with a timeline scrubber
- Each thumbnail shows timestamp overlay

#### Step D4: Spec Updates

- `spec/01-data-model.md`: Add journal tables section
- `spec/02-features.md`: Add v0.7 Journal entry
- `spec/03-architecture.md`: Add Journal to component diagram
- `spec/00-vision.md`: Add Journal to mode list (as Mode 5 or passive capture)
- `spec/kernel/requirements.yaml`: Add `REQ-JRNL-*` requirements
- `spec/kernel/traceability.md`: Map journal sources + tests
- `CLAUDE.md`: Add journal runtime paths to File Locations table

### Verifications

After each phase, verify:

```
Phase A: swift build → models + repos + migration compile
         Run JournalSessionRepositoryTests
Phase B: swift build → services compile
         Run JournalBatchAnalyzerTests with mock LLMService
Phase C: Build app, verify menu bar item appears (gated)
         Verify sidebar entry appears when journalingEnabled = true
Phase D: Full swift test → all pass
         Manual smoke test: start journal, wait for screenshots,
         stop, review chat, save snapshot, browse library
```

## Context Zone

### Governing ADRs
- ADR-002: Local-first. OCR text treated like transcript text. Screenshots stay
  on-device.
- ADR-011: No bundled LLM. Journal analysis uses existing BYO-provider path.
- ADR-013: Prompt Library foundation. Journal prompt is a Prompt row; final
  snapshot is a PromptResult row.
- ADR-022: System-wide capture pattern. Journal follows AX-first / SC-first
  capture ethos.

### Target Requirement IDs
- `REQ-JRNL-001`: Periodic screenshot capture with configurable interval
- `REQ-JRNL-002`: On-device OCR text extraction from screenshots
- `REQ-JRNL-003`: Periodic batch AI analysis of accumulated OCR text
- `REQ-JRNL-004`: AI-generated clarification questions accumulated during session
- `REQ-JRNL-005`: End-of-day chat panel for review and clarification
- `REQ-JRNL-006`: Final day snapshot generation and persistence
- `REQ-JRNL-007`: Journal library (date-grouped list, detail view, delete)
- `REQ-JRNL-008`: Menu bar recording indicator and controls
- `REQ-JRNL-009`: Settings (intervals, idle skip, storage retention)
- `REQ-JRNL-010`: Feature gate via `AppFeatures.journalingEnabled`

### Out-of-Zone Behavior (must be escalated to ADR/spec update)
- Sending actual screenshots to AI providers (vision model)
- Bundling a local vision model
- Auto-starting journal via calendar
- Per-app capture exclusion
- Cross-session analytics / trends

## Testing Strategy

Follow `spec/09-testing.md` — test ViewModels and services, skip SwiftUI views.

| Layer | What | How |
|-------|------|-----|
| Database | Repository CRUD, migrations, upsert dedup | In-memory SQLite, deterministic |
| Services | Capture, OCR, analysis, questions | Protocol mocks for `LLMServiceProtocol`, fixture screenshots for OCR |
| ViewModels | State transitions, chat logic, settings | `@MainActor`, mock service protocols |

Key test scenarios:

1. **JournalSessionRepository**: create session, fetch active, update status,
   cascade delete → screenshots + analysis runs + questions deleted
2. **JournalScreenshotRepository**: save, fetch by session, fetch unanalyzed
3. **JournalQuestionTracker**: parse questions from analysis text, sync/upsert
   dedup, answer and dismiss
4. **ScreenshotOCRService**: fixture images with known text, verify extraction
5. **JournalBatchAnalyzer**: mock LLMService returning known analysis text,
   verify summary extraction, question parsing, DB writes
6. **JournalService**: start/stop lifecycle, idle skip, state transitions,
   final snapshot generation
7. **JournalChatViewModel**: load review, send messages, finalize flow

## Rollout Strategy

1. Ship behind `AppFeatures.journalingEnabled = false` on `main`
2. Internal team dogfooding with `journalingEnabled = true` in dev builds
3. Gather feedback on:
   - Capture interval that feels right
   - OCR quality on typical workflows
   - AI analysis signal-to-noise ratio
   - Storage usage in practice
4. Tune defaults based on dogfooding
5. Flip `journalingEnabled = true` when ready for public opt-in
