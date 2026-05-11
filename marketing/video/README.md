# MacParakeet Video Pipeline

Programmatic rendering for every MacParakeet marketing asset — demos,
hero loops, social cuts, GIFs. Built with [Remotion](https://www.remotion.dev)
for composition and [ElevenLabs](https://elevenlabs.io) for voice. Every
asset is regeneratable from a single source: `src/content/script.ts`.

The locked human-readable spec lives at [`docs/marketing.md`](../../docs/marketing.md).

## Why this exists

A traditional video editor (Final Cut, Premiere, Screen Studio's editor)
freezes the script at export time. Re-recording when copy changes is hours
of work. With Remotion, every change to `script.ts` re-renders the video
on the next `npm run render`. Marketing moves at engineering velocity.

## Setup

```sh
cd marketing/video
npm install
cp .env.example .env   # then paste your ElevenLabs API key
```

Requires Node 20+.

## Workflow

```sh
# Interactive preview in the browser (Remotion Studio)
npm run preview

# Generate voiceover from the locked script
npm run voice

# Render the Hook composition (the validation spike) — 1080p
npm run render:hook

# Render the Hook composition at 4K
npm run render:hook-4k
```

Outputs land in `out/` (gitignored).

## Architecture

```
marketing/video/
├── package.json
├── remotion.config.ts          # quality defaults (CRF 16, h264, 60fps)
├── src/
│   ├── index.ts                # Remotion entrypoint
│   ├── Root.tsx                # composition registry
│   ├── content/
│   │   └── script.ts           # ⭐ the locked script — single source of truth
│   ├── compositions/
│   │   └── Hook.tsx            # 5s validation spike
│   ├── components/
│   │   ├── HookReveal.tsx      # staggered word reveal
│   │   └── ParakeetMark.tsx    # animated brand mark
│   ├── theme/
│   │   └── tokens.ts           # imports from brand-assets/palette
│   └── assets/                 # screencasts/, audio/ — gitignored
└── scripts/
    └── generate-voice.ts       # ElevenLabs voiceover generator
```

## Currently scaffolded

- ✅ `Hook` — 5s reveal of the locked hook + supporting line (validation spike)
- ✅ ElevenLabs voiceover pipeline (CLI script, regenerable per scene)

## Roadmap

- ⏳ `Demo60` — 60s master demo with VO + screencast composition
- ⏳ `HeroLoop30` — 30s autoplay-muted hero for macparakeet.com
- ⏳ `SocialVertical15` — 9:16 portrait social cut
- ⏳ Mode-specific GIF clips (Dictation, YouTube, Meeting, Export)

See `docs/marketing.md` for the full storyboard.

## Quality bar

All renders target **1080p / 60fps minimum**, **CRF 16** (visually lossless),
**48kHz audio mastered to -16 LUFS**. Springs for motion, never linear
interpolations. Brand palette from `brand-assets/palette/palette.json`,
typography from `docs/brand-identity.md`.

See `docs/marketing.md` § *Quality Bar* for the non-negotiables.

## Iteration discipline

One-way flow: **docs/marketing.md → src/content/script.ts → voice MP3s → rendered MP4s**.
Never edit a `.mp4` directly. Every change to copy starts in `docs/marketing.md`.
