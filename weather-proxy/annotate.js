'use strict'

const { EMOTION_IDS } = require('./personas')
const { accessToken } = require('./google-auth')

// Decides how each sentence of the user's line should be delivered.
//
// The split is done here, in code, and the model is only ever asked to label the
// pieces. It is never handed the text and asked for a rewrite, because the words
// belong to the user: an alarm that says something the user did not type is a
// worse failure than an alarm read flat. So the model returns one emotion id per
// sentence and nothing else, and the ids come from a closed set — which is also
// what stops it inventing `[cheerful]`, a tag Google documents as being spoken
// aloud as a word.
//
// Runs on **Vertex AI** rather than the Gemini Developer API, for the same
// reason the speech does: the Developer API's terms forbid use in a service
// "likely to be accessed by individuals under the age of 18", and explicitly do
// not govern Google Cloud services. Moving only the speech would have left the
// app half-covered by a contract it cannot honour. It also removes the last
// place an API key was needed.
//
// Everything here is best-effort. Any failure — quota, timeout, a short answer,
// a hallucinated id — falls back to neutral for that sentence and the clip is
// still generated.

const PROJECT = process.env.GOOGLE_CLOUD_PROJECT ?? 'rainyclock'
const LOCATION = process.env.VERTEX_LOCATION ?? 'us-central1'
const MODEL = process.env.VERTEX_ANNOTATE_MODEL ?? 'gemini-2.5-flash'
const TIMEOUT_MS = 8_000

const endpoint = () =>
  `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT}` +
  `/locations/${LOCATION}/publishers/google/models/${MODEL}:generateContent`

/**
 * Splits on sentence-ending punctuation in either script, keeping the mark with
 * the sentence it ends. Text with no punctuation at all stays one segment rather
 * than being chopped at an arbitrary length.
 *
 * The two halves of the pattern are not symmetric on purpose. CJK punctuation
 * ends a sentence on its own, because Chinese is written without spaces between
 * them. A Latin full stop only ends one when whitespace follows, which keeps
 * "7.30" — a time, and therefore common in an alarm — in one piece.
 *
 * An abbreviation followed by a space ("Mr. Chen") does still split. Left alone:
 * the only consequence is that two halves of one sentence get their own emotion,
 * and titles are vanishingly rare in a wake-up line next to times, which are not.
 */
function splitSentences(text, limit) {
  const parts = String(text)
    .split(/(?<=[。！？…]+)\s*|(?<=[.!?]+)\s+/u)
    .map((s) => s.trim())
    .filter(Boolean)

  if (parts.length === 0) return []
  if (parts.length <= limit) return parts

  // Past the limit the tail is joined rather than dropped: losing the user's
  // last sentence would be a silent edit of what they wrote.
  const head = parts.slice(0, limit - 1)
  head.push(parts.slice(limit - 1).join(' '))
  return head
}

const neutral = (n) => Array.from({ length: n }, () => 'neutral')

async function annotate({ sentences, persona, language }) {
  if (sentences.length === 0) return []

  const isChinese = typeof language === 'string' && language.toLowerCase().startsWith('zh')
  const instruction = [
    'You are directing a wake-up alarm recording.',
    `The speaker's character is "${persona}".`,
    `Assign exactly one delivery emotion to each of the ${sentences.length} numbered lines.`,
    `Choose only from: ${EMOTION_IDS.join(', ')}.`,
    'Vary them so the line is performed rather than read flat: openings tend to be warm or',
    'cheerful, information about being late or the weather tends to be urgent, closings tend to',
    'be encouraging. "stern" raises the volume, so use it sparingly and never on a gentle line.',
    'Do not translate, rewrite, or comment on the lines.',
    isChinese ? 'The lines are Traditional Chinese.' : '',
    '',
    sentences.map((s, i) => `${i + 1}. ${s}`).join('\n')
  ].filter(Boolean).join('\n')

  const body = {
    contents: [{ role: 'user', parts: [{ text: instruction }] }],
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'ARRAY',
        items: { type: 'STRING', enum: EMOTION_IDS },
        minItems: sentences.length,
        maxItems: sentences.length
      }
    }
  }

  try {
    const token = await accessToken()
    const response = await fetch(endpoint(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        'x-goog-user-project': PROJECT
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS)
    })
    if (!response.ok) return neutral(sentences.length)

    const payload = await response.json()
    const parsed = JSON.parse(payload?.candidates?.[0]?.content?.parts?.[0]?.text)
    if (!Array.isArray(parsed)) return neutral(sentences.length)

    // Pad and validate rather than trusting the length or the values: the schema
    // is a request, not a guarantee.
    return sentences.map((_, i) => (EMOTION_IDS.includes(parsed[i]) ? parsed[i] : 'neutral'))
  } catch {
    return neutral(sentences.length)
  }
}

module.exports = { annotate, splitSentences, MODEL, LOCATION }
