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
 * Retries are short and few, because a caller is waiting and the app's fallback
 * to a bundled tone beats a long stall. Two things are retried:
 *
 * - 5xx, which this model produces intermittently.
 * - `content_blocked`, which measurement shows is *noise rather than judgement*.
 *   "早安，該起床囉" — good morning, time to get up — was refused on roughly one
 *   call in six while identical requests either side of it succeeded. Reporting
 *   that to the user as "your words were rejected" would be both wrong and
 *   unactionable, so it gets the same treatment as a 500.
 *
 * A refusal that survives every attempt is passed on as 422, because at that
 * point it probably is about the words.
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
  let blockedEveryTime = true
  for (let attempt = 0; attempt < 3; attempt += 1) {
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
      if (detail.includes('content_blocked')) {
        lastError = new Error('gemini blocked the content')
        lastError.blocked = true
        continue
      }
      blockedEveryTime = false
      const error = new Error(`gemini rejected the request: ${detail.slice(0, 300)}`)
      error.status = response.status === 400 || response.status === 403 ? 422 : 502
      throw error
    }

    blockedEveryTime = false
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
  // Refused every single time is the one case where the words are plausibly the
  // problem, and the only case worth telling the user about.
  error.status = blockedEveryTime && lastError?.blocked ? 422 : 502
  throw error
}

module.exports = { synthesize, extractAudio, truncateToSeconds, SAMPLE_RATE, BYTES_PER_SECOND, MODEL }
