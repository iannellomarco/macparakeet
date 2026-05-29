# MacParakeet Day Journal — Project Context

> Drop this into a new Claude/ChatGPT/Codex window to continue development seamlessly.
> Last updated: 2026-05-29

## Repository

| Item | Value |
|------|-------|
| **Fork** | `iannellomarco/macparakeet` (official GitHub fork of `moona3k/macparakeet`) |
| **URL** | https://github.com/iannellomarco/macparakeet |
| **Visibility** | Public |
| **Upstream** | https://github.com/moona3k/macparakeet |
| **Transition repo** | `iannellomarco/macparakeet-dayjournal` (public, only appcast — no code) |
| **GitHub Pages** | https://iannellomarco.github.io/macparakeet/ |
| **Appcast** | https://iannellomarco.github.io/macparakeet/appcast.xml |

## Working directories

```bash
# Primary — the official fork (USE THIS for all development)
/Users/marcoiannello/Desktop/macPara2/macparakeet-fork

# Legacy — stripped transition repo (only appcast, no code)
/Users/marcoiannello/Desktop/macPara2/macparakeet
```

### Git remotes on the fork

```bash
cd /Users/marcoiannello/Desktop/macPara2/macparakeet-fork
git remote -v
# origin    https://github.com/iannellomarco/macparakeet.git (fetch/push)
# upstream  https://github.com/moona3k/macparakeet.git (fetch)
```

### Syncing with upstream

```bash
cd /Users/marcoiannello/Desktop/macPara2/macparakeet-fork
git fetch upstream
git merge upstream/main
# Resolve conflicts → swift build → swift test → git push origin main
```

## What this is

A fork of MacParakeet (fast, private, local-first voice app for macOS) with a **Day Journal** feature added as a fourth capture mode.

- Periodically captures screenshots at configurable intervals
- Extracts text on-device via Apple Vision OCR
- Sends only text to the user's configured AI provider for batch analysis
- Builds a running day narrative with clarification questions
- End-of-day chat panel for review and finalization
- Cross-references same-day meeting transcripts

## Tech stack

| Layer | Choice |
|-------|--------|
| Platform | macOS 14.2+, Apple Silicon only |
| Language | Swift 6.0 + SwiftUI |
| Database | SQLite via GRDB (single file: `~/Library/Application Support/MacParakeet/macparakeet.db`) |
| STT | Parakeet TDT via FluidAudio CoreML (default) + optional WhisperKit |
| AI providers | Anthropic, OpenAI, Gemini, OpenRouter, Ollama, LM Studio, Local CLI |
| Updates | Sparkle 2, EdDSA-signed appcast on GitHub Pages |
| Screenshots | CGDisplayCreateImage → Vision framework OCR → LLMService.analyzeJournal() |
| Build | `swift build`, `scripts/dev/run_app.sh` |

## Architecture

```
Sources/
  MacParakeetCore/           — Pure Swift library (no SwiftUI)
    Services/Journal/        — 7 new services
      JournalService.swift           — actor orchestrating capture + analysis loops
      ScreenshotCaptureService.swift — CGDisplayCreateImage + JPEG encoding
      ScreenshotOCRService.swift     — VNRecognizeTextRequest on VNEngine
      JournalBatchAnalyzer.swift     — batch OCR → LLMService.analyzeJournal()
      JournalQuestionTracker.swift   — parse AI output for questions, sync with DB
      JournalIdleDetector.swift      — CGEventSource activity detection
      JournalStorageManager.swift    — file I/O, retention enforcement
    Models/                  — JournalSession, JournalScreenshot, JournalAnalysisRun, JournalQuestion
    Database/                — 4 repositories (one per GRDB table)
    Services/LLM/LLMService.swift   — added analyzeJournal(ocrText:runningSummary:meetingContext:pendingQuestions:screenshotCount:) method

  MacParakeetViewModels/Journal/  — 4 ViewModels
    JournalControlViewModel.swift    — start/stop/cancel/finalize, elapsed timer, state callbacks
    JournalChatViewModel.swift       — streaming end-of-day chat with AI
    JournalSettingsViewModel.swift   — intervals, idle skip, retention, permissions
    JournalLibraryViewModel.swift    — browse past sessions, load/delete

  MacParakeet/Views/Journal/    — 6 views + 1 controller
    JournalControlView.swift         — Transcribe tab tile (idle/recording/reviewing/computing)
    JournalChatPanel.swift           — end-of-day NSPanel chat with Markdown rendering
    JournalChatPanelController.swift — NSPanel lifecycle management
    JournalLibraryView.swift         — week calendar grid + timeline list
    JournalDayDetailView.swift       — stats card + Markdown journal entry
    JournalSettingsSection.swift     — compact inline settings

  MacParakeet/App/
    JournalFlowCoordinator.swift     — wires ViewModel callbacks → NSPanel lifecycle
    AppEnvironment.swift             — creates JournalService + 4 repos
    AppEnvironmentConfigurer.swift   — wires journal ViewModels, sets up callbacks
    AppWindowCoordinator.swift       — passes journal VMs to MainWindowView
    AppDelegate.swift                — owns journal VMs, creates JournalFlowCoordinator
```

## Database (GRDB migrations)

Four new tables in `macparakeet.db`:

| Migration | Table | Purpose |
|-----------|-------|---------|
| v0.20-prompt-applies-to-sources | `prompts.appliesToSources` | Upstream — source-scoped auto-run |
| v0.22-journal-tables | `journal_sessions` | One row per session. Status: recording → reviewing → completed/cancelled |
| v0.22-journal-tables | `journal_screenshots` | Individual captures with OCR text, confidence, display metadata |
| v0.22-journal-tables | `journal_analysis_runs` | Periodic batch analysis. Links OCR input → AI output → questions |
| v0.22-journal-tables | `journal_questions` | AI-generated questions with answer/dismiss tracking |
| v0.23-drop-legacy-screenshot-entries | — | Cleanup of vestigial `screenshot_entries` table from prior experiment |

Screenshots stored on disk at `~/Library/Application Support/MacParakeet/journal/{sessionId}/`.

## Feature flow

```
User clicks "Start Journaling" on Transcribe tab
    │
    ▼
Capture loop (every 2 min by default)
    ├── CGDisplayCreateImage → JPEG
    ├── Vision OCR (on-device)
    └── Save to DB + disk
    │
    ▼
Analysis loop (every 30 min by default)
    ├── Fetch unanalyzed screenshots
    ├── Fetch same-day meeting transcripts
    ├── LLMService.analyzeJournal()
    ├── Extract running summary + questions
    └── Update DB
    │
    ▼
User clicks "Stop & Review"
    ├── Final batch analysis
    └── Chat panel opens (JournalChatPanel)
    │
    ▼
Chat with AI → "Save Journal"
    ├── LLM generates final narrative from running summary
    └── Journal entry saved with .completed status
```

## Settings

| Setting | Options | Default | UserDefaults key |
|---------|---------|---------|------------------|
| Screenshot interval | 30s / 1m / 2m / 5m / 10m | 2 min | `journal_capture_interval_secs` |
| Analysis interval | 15m / 30m / 60m | 30 min | `journal_analysis_interval_mins` |
| Idle skip | On/Off | Off | `journal_idle_skip_enabled` |
| Idle threshold | 30s / 60s / 120s | 120s | `journal_idle_threshold_secs` |
| Storage retention | 7d / 30d / 90d / Forever | 30 days | `journal_retention_days` |

Feature gate: `AppFeatures.journalingEnabled` (default `true`)

## Update channel

| Component | Value |
|-----------|-------|
| **SUFeedURL** (in DMG) | `https://iannellomarco.github.io/macparakeet/appcast.xml` |
| **EdDSA public key** | `N/L9A3Dq0CVwDIlibInW1J7EW4ctRc6TyzidwwLH/PE=` |
| **EdDSA private key** | macOS Keychain (generated with `generate_keys`) |
| **Sparkle sign_update** | `.build/artifacts/sparkle/Sparkle/bin/sign_update` |
| **Version scheme** | `0.6.100` (above upstream's `0.6.13` to avoid tag collisions) |

### Migration path for old users

Users on the old `macparakeet-dayjournal` DMG are redirected via a transition appcast:
1. Old DMG checks `macparakeet-dayjournal/appcast.xml`
2. Finds update pointing to the new fork's DMG
3. Installs → new DMG has SUFeedURL = `macparakeet/appcast.xml`
4. All future updates come from the new fork

`macparakeet-dayjournal` repo is public but stripped — only `appcast.xml` + `.nojekyll` + `index.html`, no code, no credentials.

## Release workflow

See `RELEASE.md` for step-by-step. Quick reference:

```bash
cd /Users/marcoiannello/Desktop/macPara2/macparakeet-fork

# Build
VERSION=0.6.101 scripts/dist/build_app_bundle.sh

# Sign + notarize + DMG
SIGN_IDENTITY="Developer ID Application: Marco Iannello (HX54PKUTV6)" \
  NOTARYTOOL_PROFILE="macparascreen-notary" \
  CREATE_DMG=1 scripts/dist/sign_notarize.sh

# EdDSA sign
.build/artifacts/sparkle/Sparkle/bin/sign_update dist/MacParakeet.dmg
# → outputs sparkle:edSignature="..." length="..."

# Update appcast.xml with new version, signature, URL, length

# Create release + upload DMG (see RELEASE.md for full commands)

# Push appcast
git add appcast.xml && git commit -m "appcast v0.6.101" && git push origin main
```

## Credentials (never commit these)

| Credential | Location |
|------------|----------|
| Developer ID cert | macOS Keychain: `Developer ID Application: Marco Iannello (HX54PKUTV6)` |
| Notary profile | macOS Keychain: `macparascreen-notary` |
| EdDSA private key | macOS Keychain (Sparkle) |
| GitHub token | `gh` CLI authenticated as `iannellomarco` |
| Apple ID | `iannello.marco10@gmail.com` (Team: `HX54PKUTV6`) |
| App-specific password | In Keychain, not in any file. Revoke at appleid.apple.com when done |

## Verification commands

```bash
# Build
swift build

# Tests (all must pass)
swift test
# Expected: ~3104 tests, 0 failures

# Dev run
scripts/dev/run_app.sh

# Gatekeeper
spctl --assess --verbose --type install dist/MacParakeet.dmg
# Expected: accepted source=Notarized Developer ID

# Appcast live
curl -s "https://iannellomarco.github.io/macparakeet/appcast.xml"
```

## Key files reference

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Full project context for coding agents (upstream) |
| `AGENTS.md` | Cross-agent guide (upstream) |
| `CONTEXT.md` | This file — fork-specific context |
| `RELEASE.md` | Step-by-step release workflow with all commands |
| `spec/adr/023-day-journal-screenshot-second-brain.md` | Architecture decision record for Day Journal |
| `plans/completed/2026-05-screenshot-day-journal.md` | Original implementation plan |
| `scripts/dist/build_app_bundle.sh` | Build app bundle (SUFeedURL + SUPublicEDKey embedded) |
| `scripts/dist/sign_notarize.sh` | Sign + notarize + create DMG |
| `scripts/dist/generate_appcast.sh` | Generate appcast XML |
| `appcast.xml` | Sparkle appcast (deployed via GitHub Pages) |

## Current state (2026-05-29)

- **Version:** v0.6.100 (test release — next real release should be 0.7.0-journal.1)
- **Upstream:** Synced as of commit `0e424325` (15 commits ahead of fork base)
- **Tests:** 3104 tests, 0 failures
- **Build:** Clean
- **Update channel:** Verified working — v0.6.100 update delivered successfully

## Known issues / Future work

1. **Per-app exclusion** — skip screenshots when specific apps are frontmost (1Password, banking)
2. **Screenshot gallery** — browse captured images within a journal entry in the detail view
3. **CLI commands** — `macparakeet-cli journal` for headless journal management
4. **Export formats** — export journal entries as Markdown, PDF
5. **Vision model path** — optionally send actual screenshots to vision-capable AI providers
6. **Better error handling** — surface AI provider failures in the UI, not just logs
7. **Integration tests** — for JournalService with mock dependencies
8. **Version scheme** — settle on `0.7.0-journal.N` to avoid upstream tag collisions
9. **Delete test release v0.6.100** after confirming migration works
