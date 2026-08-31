'use strict'

const { EMOTION_IDS } = require('./personas')

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
// Everything here is best-effort. Any failure — quota, timeout, a short answer,
// a hallucinated id — falls back to neutral for that sentence and the clip is
// still generated.

const ENDPOINT_BASE = 'https://generativelanguage.googleapis.com/v1beta/models'
const MODEL = process.env.GEMINI_ANNOTATE_MODEL ?? 'gemini-flash-lite-latest'
const TIMEOUT_MS = 8_000

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

async function annotate({ apiKey, sentences, persona, language }) {
  if (!apiKey || sentences.length === 0) return neutral(sentences.length)

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
    contents: [{ parts: [{ text: instruction }] }],
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
    const response = await fetch(`${ENDPOINT_BASE}/${MODEL}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS)
    })
    if (!response.ok) return neutral(sentences.length)

    const payload = await response.json()
    const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) return neutral(sentences.length)

    // Pad and validate rather than trusting the length or the values: the schema
    // is a request, not a guarantee.
    return sentences.map((_, i) => (EMOTION_IDS.includes(parsed[i]) ? parsed[i] : 'neutral'))
  } catch {
    return neutral(sentences.length)
  }
}

module.exports = { annotate, splitSentences, MODEL }
