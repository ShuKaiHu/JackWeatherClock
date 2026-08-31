'use strict'

// The closed set of voices this proxy will speak in.
//
// The client sends a persona id and the words. It does NOT send a voice name or
// a style prompt, and that is the whole point: an endpoint that accepts an
// arbitrary style prompt is a free general-purpose Gemini endpoint the moment
// somebody reads the URL out of the app. Keeping the prompt here also means the
// wording can be retuned by redeploying the proxy instead of shipping an app
// update through review.
//
// Voice names are Google's prebuilt Gemini-TTS voices; the descriptor in each
// comment is Google's own one-word characterisation. Three female, three male,
// so gender is a property of the choice rather than a separate question the UI
// has to ask.

const STYLE_ZH = 'zh-Hant'
const STYLE_EN = 'en'

const PERSONAS = {
  // Default. Carries the rain briefing better than a hype voice does, and is the
  // least likely to be uninstalled as an annoying novelty.
  steady: {
    voice: 'Charon', // Informative
    style: {
      [STYLE_ZH]: '用沉穩、清楚、像晨間播報員的語氣說這段話。語速平穩，咬字清晰，台灣口音的中文。',
      [STYLE_EN]: 'Read this in a calm, clear morning-broadcast voice. Steady pace, crisp diction.'
    }
  },
  bright: {
    voice: 'Leda', // Youthful
    style: {
      [STYLE_ZH]: '用充滿活力、開朗有精神的語氣說這段話，像在叫醒賴床的朋友。語速稍快，台灣口音的中文。',
      [STYLE_EN]: 'Say this brightly and energetically, like waking up a friend who overslept. Slightly quick pace.'
    }
  },
  gentle: {
    voice: 'Vindemiatrix', // Gentle
    style: {
      [STYLE_ZH]: '用溫柔、放鬆、帶著關心的語氣說這段話，像在輕輕喚醒枕邊的人。語速偏慢，台灣口音的中文。',
      [STYLE_EN]: 'Say this gently and warmly, like softly waking someone beside you. Unhurried pace.'
    }
  },
  buddy: {
    voice: 'Puck', // Upbeat
    style: {
      [STYLE_ZH]: '用輕鬆、帶點調侃的語氣說這段話，像損友在虧你又賴床。台灣口音的中文。',
      [STYLE_EN]: 'Say this in a loose, teasing tone, like a friend ribbing you for oversleeping.'
    }
  },
  mom: {
    voice: 'Gacrux', // Mature
    style: {
      [STYLE_ZH]: '用媽媽碎念的語氣說這段話，帶點無奈又關心，像已經叫過第三次了。台灣口音的中文。',
      [STYLE_EN]: 'Say this the way a mother nags, half exasperated and half caring, as if this is the third time.'
    }
  },
  // The only persona that ships an audio tag. `[shouting]` is documented, raises
  // volume, and is spoken as delivery rather than read aloud as a word — unlike
  // the emotion-adjective tags, which Google says to express in the style prompt
  // instead. Never use `[whispers]`: it lowers volume, and a quiet alarm is a
  // broken one.
  sergeant: {
    voice: 'Orus', // Firm
    tag: '[shouting]',
    style: {
      [STYLE_ZH]: '用嚴厲、命令式、像教官點名的語氣說這段話，音量大，不容商量。台灣口音的中文。',
      [STYLE_EN]: 'Bark this like a drill sergeant calling roll. Loud, clipped, no room for argument.'
    }
  }
}

const PERSONA_IDS = Object.freeze(Object.keys(PERSONAS))

// The emotion vocabulary the app may ask for, one entry per sentence of the
// user's own text. The app decides which sentence gets which; this decides what
// that actually turns into, and the client never sends a raw tag.
//
// That split exists because Google sorts bracketed markup into four modes and
// only three of them are safe. From the Gemini-TTS docs:
//
//   Mode 1  non-speech sounds     [sigh] [laughing]        inserts the sound
//   Mode 2  style modifiers       [shouting] [whispering]  changes delivery only
//   Mode 3  vocalized adjectives  [scared] [curious]       "The markup tag itself
//                                                           is spoken as a word"
//   Mode 4  pacing                [medium pause]           inserts silence
//
// Google's warning on Mode 3 is explicit: "Because the tag itself is spoken,
// this mode is likely an undesired side effect for most use cases. Prefer using
// the Style Prompt to set these emotional tones instead." Every adjective-form
// emotion tag — [cheerful], [urgent], [encouraging] — is Mode 3, so none of them
// can be emitted directly. What follows maps each intent onto Mode 2 or Mode 4,
// which carry the same feeling through pace and volume without being read out.
//
// `unverified` marks adverb-form tags that a third-party evaluation reports as
// reliable but that Google does not document. They are off by default; flip one
// on only after hearing it, and the fix is a redeploy rather than an app update.
const EMOTIONS = {
  neutral: { tag: null },
  // Cheer through pace, not through the word "cheerful".
  cheerful: { tag: null, unverified: '[cheerfully]' },
  playful: { tag: null, unverified: '[mischievously]' },
  // Urgency is genuinely a pace change, so Mode 2 expresses it better than an
  // adjective would have.
  urgent: { tag: '[extremely fast]' },
  // The one tag that raises volume. Never [whispers], which lowers it: a quiet
  // alarm is a broken alarm.
  stern: { tag: '[shouting]' },
  encouraging: { tag: null, unverified: '[warmly]' },
  gentle: { tag: null, unverified: '[gently]' },
  beat: { tag: '[medium pause]' }
}

const EMOTION_IDS = Object.freeze(Object.keys(EMOTIONS))

/** Whether an unverified adverb-form tag may be emitted. Off unless heard. */
const allowUnverifiedTags = process.env.TTS_ALLOW_UNVERIFIED_TAGS === '1'

function tagFor(emotion) {
  const entry = EMOTIONS[emotion]
  if (!entry) return null
  if (entry.tag) return entry.tag
  return allowUnverifiedTags && entry.unverified ? entry.unverified : null
}

/** Normalises a caller's locale onto the two style languages that exist. */
function styleLanguage(language) {
  return typeof language === 'string' && language.toLowerCase().startsWith('zh') ? STYLE_ZH : STYLE_EN
}

/**
 * Splits the request into the two things Cloud Text-to-Speech asks for
 * separately: the direction (`input.prompt`) and the words (`input.text`).
 *
 * That separation is why the "Synthesize this speech:" preamble this used to
 * carry is gone. It existed because the Gemini Developer API took one string and
 * could not always tell direction from dialogue — it would read the stage notes
 * aloud. Here the API makes the distinction itself, so the words are only ever
 * the user's own.
 *
 * Square brackets are still stripped from the caller's text: a user who types
 * one would otherwise be writing an unintended delivery instruction into their
 * own alarm.
 */
function buildPrompt({ persona, segments, language }) {
  const definition = PERSONAS[persona]
  if (!definition) return null

  const lang = styleLanguage(language)

  const spoken = segments
    .map(({ text, emotion }) => {
      // Strip the user's own brackets before adding ours. Someone typing one is
      // otherwise writing a delivery instruction into their own alarm, and after
      // this line every bracket in the transcript is one we put there.
      const words = String(text ?? '').replace(/[[\]]/g, '').trim()
      if (!words) return null
      const tag = tagFor(emotion)
      return tag ? `${tag} ${words}` : words
    })
    .filter(Boolean)
    .join(' ')

  if (!spoken) return null

  return {
    voice: definition.voice,
    language: lang,
    style: definition.style[lang],
    spoken: definition.tag ? `${definition.tag} ${spoken}` : spoken
  }
}

module.exports = { PERSONAS, PERSONA_IDS, EMOTIONS, EMOTION_IDS, buildPrompt, styleLanguage, tagFor }
