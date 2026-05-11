#!/usr/bin/env tsx
/**
 * Generate voiceover audio via the ElevenLabs API.
 *
 * Reads SCRIPT (`src/content/script.ts`) and writes MP3 files per scene
 * plus a master demo voiceover into `src/assets/audio/`. Files are
 * gitignored — regenerate on demand whenever the script changes.
 *
 * Usage:
 *   npm run voice                         # generate every scene
 *   npm run voice -- mode-dictation       # only one scene
 *   npm run voice -- master-demo          # only the long-form master VO
 *
 * Requires ELEVENLABS_API_KEY in `.env`. See `.env.example`.
 *
 * Voice direction:
 *   Calm, confident, minimal. Slight warmth. Never the default robotic preset.
 *   See docs/brand-identity.md § Brand Voice.
 */

import * as fs from 'node:fs/promises';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { SCRIPT } from '../src/content/script.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const API_KEY = process.env.ELEVENLABS_API_KEY;
// Default voice: "Rachel" — calm/professional. Override via ELEVENLABS_VOICE_ID.
const VOICE_ID = process.env.ELEVENLABS_VOICE_ID ?? '21m00Tcm4TlvDq8ikWAM';
const MODEL_ID = process.env.ELEVENLABS_MODEL_ID ?? 'eleven_turbo_v2_5';
const OUT_DIR = path.resolve(__dirname, '../src/assets/audio');

const endpoint = (voiceId: string) =>
  `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

interface VoiceJob {
  name: string;
  text: string;
}

const jobs: VoiceJob[] = [
  { name: 'hook-opener', text: SCRIPT.bridges.openingLine },
  { name: 'mode-dictation', text: SCRIPT.modes.dictation.vo },
  { name: 'mode-transcription', text: SCRIPT.modes.transcription.vo },
  { name: 'mode-meeting', text: SCRIPT.modes.meeting.vo },
  { name: 'closing', text: SCRIPT.bridges.closingLine },
  {
    name: 'master-demo',
    text: [
      SCRIPT.bridges.openingLine,
      SCRIPT.modes.dictation.vo,
      SCRIPT.modes.transcription.vo,
      SCRIPT.modes.meeting.vo,
      SCRIPT.bridges.closingLine,
    ].join(' '),
  },
];

async function renderVoice(job: VoiceJob): Promise<void> {
  if (!API_KEY) {
    throw new Error(
      'ELEVENLABS_API_KEY missing. Copy .env.example to .env and add your key.',
    );
  }

  const res = await fetch(endpoint(VOICE_ID), {
    method: 'POST',
    headers: {
      'xi-api-key': API_KEY,
      'Content-Type': 'application/json',
      Accept: 'audio/mpeg',
    },
    body: JSON.stringify({
      text: job.text,
      model_id: MODEL_ID,
      // Tuned for calm/measured delivery. Adjust per-scene if needed.
      voice_settings: {
        stability: 0.55,
        similarity_boost: 0.75,
        style: 0.15,
        use_speaker_boost: true,
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`ElevenLabs API ${res.status}: ${err}`);
  }

  const buf = Buffer.from(await res.arrayBuffer());
  await fs.mkdir(OUT_DIR, { recursive: true });
  const outPath = path.join(OUT_DIR, `${job.name}.mp3`);
  await fs.writeFile(outPath, buf);
  console.log(`✓ ${job.name} → ${path.relative(process.cwd(), outPath)}`);
}

async function main(): Promise<void> {
  const requested = process.argv.slice(2);
  const toRun =
    requested.length > 0
      ? jobs.filter((j) => requested.includes(j.name))
      : jobs;

  if (toRun.length === 0) {
    console.error(
      'No matching jobs. Available:',
      jobs.map((j) => j.name).join(', '),
    );
    process.exit(1);
  }

  for (const job of toRun) {
    await renderVoice(job);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
