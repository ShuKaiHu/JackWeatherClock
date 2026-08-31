'use strict'

const { buildPrompt } = require('./personas')

// Speech synthesis through the Gemini API, kept behind the proxy for the same
// reason the WeatherKit signing is: the key cannot ship inside the app. Here the
// stakes are higher than an allowance — a scraped Gemini key is billed by the
// token, so the spend cap in front of this has to be a real ceiling, not an
// alert.

const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions'

// 2.5-flash, not 3.1-flash: half the price for output audio, and without 3.1's
// documented habit of returning text tokens instead of audio.
const MODEL = process.env.GEMINI_TTS_MODEL ?? 'gemini-2.5-flash-preview-tts'

const UPSTREAM_TIMEOUT_MS = 30_000

/** Gemini returns headerless mono 16-bit PCM at this rate. */
const SAMPLE_RATE = 24_000
const BYTES_PER_SECOND = SAMPLE_RATE * 2

/**
 * A hard ceiling on returned audio, enforced here rather than trusted from the
 * client. The model has no duration parameter — you send words and it decides
 * how long to talk — so this is the only place the length is actually bounded.
 * Cut on an even byte so a sample is never split in half.
 */
function truncateToSeconds(pcm, seconds) {
  const limit = Math.floor(seconds * BYTES_PER_SECOND / 2) * 2
  return pcm.length > limit ? pcm.subarray(0, limit) : pcm
}

/**
 * Pulls the audio out of a response whose shape is not pinned down.
 *
 * The interactions API and the older generateContent API bury the payload at
 * different paths, and neither is documented for this model well enough to rely
 * on. Both hide exactly one long base64 blob, so taking the longest string is
 * more durable than guessing a path — and it degrades to a clear error rather
 * than a crash when the model returns prose instead of audio.
 */
function extractAudio(payload) {
  let best = null
  const stack = [payload]
  while (stack.length > 0) {
    const current = stack.pop()
    if (Array.isArray(current)) {
      stack.push(...current)
    } else if (current && typeof current === 'object') {
      stack.push(...Object.values(current))
    } else if (typeof current === 'string' && current.length > 1_000) {
      if (best === null || current.length > best.length) best = current
    }
  }
  return best === null ? null : Buffer.from(best, 'base64')
}

/**
 * Synthesizes one clip. Throws with `.status` set so the caller can tell a bad
 * request from an upstream fault.
 *
 * One retry, because this model intermittently 500s and a single immediate
 * retry clears most of it. No backoff loop: a caller is waiting, and the app's
 * own fallback to a bundled tone is a better answer than a long stall.
 */
async function synthesize({ apiKey, persona, segments, language, maximumSeconds }) {
  const built = buildPrompt({ persona, segments, language })
  if (!built) {
    const error = new Error('unknown persona or empty text')
    error.status = 400
    throw error
  }

  const body = JSON.stringify({
    model: MODEL,
    input: built.prompt,
    response_format: { type: 'audio' },
    generation_config: { speech_config: [{ voice: built.voice }] }
  })

  let lastError = null
  for (let attempt = 0; attempt < 2; attempt += 1) {
    let response
    try {
      response = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body,
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
      })
    } catch (cause) {
      lastError = new Error(`gemini unreachable: ${cause.message}`)
      continue
    }

    if (response.status >= 500) {
      lastError = new Error(`gemini responded ${response.status}`)
      continue
    }

    if (!response.ok) {
      const detail = await response.text().catch(() => '')
      // A refusal is the caller's problem and will not improve on retry: the
      // safety filter rejected the words, and the app should say so rather than
      // silently ring a default tone the user did not choose.
      const error = new Error(`gemini rejected the request: ${detail.slice(0, 300)}`)
      error.status = response.status === 400 || response.status === 403 ? 422 : 502
      throw error
    }

    const pcm = extractAudio(await response.json())
    if (pcm === null || pcm.length === 0) {
      // The model answered in words instead of audio. Retrying does sometimes
      // help; failing loudly is still better than returning silence.
      lastError = new Error('gemini returned no audio')
      continue
    }

    return truncateToSeconds(pcm, maximumSeconds)
  }

  const error = lastError ?? new Error('gemini failed')
  error.status = 502
  throw error
}

module.exports = { synthesize, extractAudio, truncateToSeconds, SAMPLE_RATE, BYTES_PER_SECOND, MODEL }
