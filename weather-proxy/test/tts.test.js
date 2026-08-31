'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const { PERSONA_IDS, EMOTION_IDS, EMOTIONS, buildPrompt, styleLanguage, tagFor } = require('../personas')
const { pcmFromWav, truncateToSeconds, BYTES_PER_SECOND } = require('../tts')

const one = (text, emotion) => [{ text, emotion }]

test('every persona resolves to a voice and both style languages', () => {
  assert.equal(PERSONA_IDS.length, 6)
  for (const persona of PERSONA_IDS) {
    const zh = buildPrompt({ persona, segments: one('起床囉'), language: 'zh-Hant' })
    const en = buildPrompt({ persona, segments: one('Wake up'), language: 'en-US' })
    assert.ok(zh.voice.length > 0, `${persona} has no voice`)
    assert.notEqual(zh.style, en.style, `${persona} gives the same direction in both languages`)
  }
})

test('personas do not share a voice, and the roster is balanced by design', () => {
  const voices = PERSONA_IDS.map((id) => buildPrompt({ persona: id, segments: one('x') }).voice)
  assert.equal(new Set(voices).size, 6)
})

test('an unknown persona is rejected rather than defaulted', () => {
  assert.equal(buildPrompt({ persona: 'nope', segments: one('hi') }), null)
})

test('empty or whitespace-only text is rejected', () => {
  assert.equal(buildPrompt({ persona: 'steady', segments: one('   ') }), null)
})

// The whole reason emotions are ids and not tags: Google documents that
// adjective-form markup is "spoken as a word", so none may reach the model.
test('no emotion emits an adjective-form tag, which would be read aloud', () => {
  const spokenAloud = /\[(cheerful|urgent|encouraging|scared|curious|bored|excited|playful)\]/
  for (const emotion of EMOTION_IDS) {
    const built = buildPrompt({ persona: 'steady', segments: one('早安', emotion), language: 'zh' })
    assert.doesNotMatch(built.spoken, spokenAloud, `${emotion} emits a vocalized adjective tag`)
  }
})

test('every emitted tag is a documented Mode 2 or Mode 4 tag', () => {
  const safe = new Set(['[extremely fast]', '[shouting]', '[medium pause]', '[short pause]', '[long pause]', '[whispering]', '[sarcasm]', '[robotic]'])
  for (const emotion of EMOTION_IDS) {
    const tag = tagFor(emotion)
    if (tag !== null) assert.ok(safe.has(tag), `${emotion} emits unvetted tag ${tag}`)
  }
})

test('unverified adverb tags stay off unless explicitly enabled', () => {
  // They are recorded so the option is visible, but silence is the safe default.
  assert.equal(tagFor('cheerful'), null)
  assert.ok(EMOTIONS.cheerful.unverified, 'the candidate should still be recorded')
})

test('urgency becomes a pace change, which conveys it without being spoken', () => {
  const built = buildPrompt({ persona: 'steady', segments: one('要遲到了', 'urgent'), language: 'zh' })
  assert.ok(built.spoken.includes('[extremely fast]'))
})

test('an unknown emotion degrades to no tag rather than passing text through', () => {
  const built = buildPrompt({ persona: 'steady', segments: one('早安', 'ecstatic'), language: 'zh' })
  assert.ok(built.spoken.includes('早安'))
  assert.doesNotMatch(built.spoken, /\[ecstatic\]/)
})

test('segments are joined in order, each carrying its own delivery', () => {
  const built = buildPrompt({
    persona: 'bright',
    language: 'zh-Hant',
    segments: [
      { text: '早安～該起床囉！', emotion: 'neutral' },
      { text: '今天外面下雨，要早點出門。', emotion: 'urgent' },
      { text: '快起來準備出發！', emotion: 'stern' }
    ]
  })
  assert.match(built.spoken, /早安～該起床囉！.*\[extremely fast\] 今天外面下雨.*\[shouting\] 快起來/s)
})

test('empty segments are dropped without collapsing the rest', () => {
  const built = buildPrompt({
    persona: 'steady',
    segments: [{ text: '早安' }, { text: '  ' }, { text: '起床' }]
  })
  assert.equal(built.spoken, '早安 起床')
})

test("square brackets in the user's own words are stripped before ours are added", () => {
  const built = buildPrompt({ persona: 'steady', segments: one('[shouting] 快起來'), language: 'zh' })
  assert.ok(!built.spoken.includes('[shouting]'), 'user-supplied tag survived')
  assert.ok(built.spoken.includes('快起來'))
})

test('the sergeant keeps its own tag, which the user cannot forge', () => {
  const built = buildPrompt({ persona: 'sergeant', segments: one('起床'), language: 'zh' })
  assert.ok(built.spoken.includes('[shouting]'))
})

test("direction and words are separate, so the words are only ever the user's", () => {
  // The Developer API took one string and sometimes read the stage notes aloud.
  // Cloud TTS has a field for each, so no preamble is needed to tell them apart.
  const built = buildPrompt({ persona: 'steady', segments: one('hello'), language: 'en' })
  assert.equal(built.spoken, 'hello')
  assert.ok(built.style.length > 0)
  assert.ok(!built.style.includes('hello'))
})

test('locale maps onto the two style languages that exist', () => {
  assert.equal(styleLanguage('zh-Hant-TW'), 'zh-Hant')
  assert.equal(styleLanguage('zh'), 'zh-Hant')
  assert.equal(styleLanguage('en-US'), 'en')
  assert.equal(styleLanguage(undefined), 'en')
})

test('audio is truncated on an even byte so a sample is never split', () => {
  const pcm = Buffer.alloc(BYTES_PER_SECOND * 20)
  const cut = truncateToSeconds(pcm, 10)
  assert.equal(cut.length, BYTES_PER_SECOND * 10)
  assert.equal(cut.length % 2, 0)
})

test('audio shorter than the cap is returned untouched', () => {
  assert.equal(truncateToSeconds(Buffer.alloc(1_000), 10).length, 1_000)
})

test('the RIFF container Cloud TTS returns is unwrapped to bare samples', () => {
  const pcm = Buffer.alloc(200, 7)
  const wav = Buffer.concat([
    Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVE'),
    Buffer.from('fmt '), (() => { const b = Buffer.alloc(4); b.writeUInt32LE(16); return b })(), Buffer.alloc(16),
    Buffer.from('data'), (() => { const b = Buffer.alloc(4); b.writeUInt32LE(pcm.length); return b })(), pcm
  ])
  assert.deepEqual(pcmFromWav(wav), pcm)
})

test('the data chunk is located rather than assumed to start at byte 44', () => {
  // A WAV may legally carry LIST or other chunks first; a fixed offset would
  // ship metadata as audio.
  const pcm = Buffer.alloc(100, 9)
  const list = Buffer.alloc(10, 1)
  const wav = Buffer.concat([
    Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WAVE'),
    Buffer.from('LIST'), (() => { const b = Buffer.alloc(4); b.writeUInt32LE(list.length); return b })(), list,
    Buffer.from('data'), (() => { const b = Buffer.alloc(4); b.writeUInt32LE(pcm.length); return b })(), pcm
  ])
  assert.deepEqual(pcmFromWav(wav), pcm)
})

test('headerless audio passes through untouched', () => {
  const raw = Buffer.alloc(50, 3)
  assert.deepEqual(pcmFromWav(raw), raw)
})

// --- sentence splitting, which decides what the model gets asked to label ---

const { splitSentences } = require('../annotate')

test('Chinese splits on its own punctuation, which carries no spaces', () => {
  assert.deepEqual(
    splitSentences('早安～該起床囉！今天外面下雨。快起來換衣服！', 8),
    ['早安～該起床囉！', '今天外面下雨。', '快起來換衣服！']
  )
})

test('English splits only when whitespace follows the stop', () => {
  assert.deepEqual(
    splitSentences('Good morning! It is raining today. Leave early.', 8),
    ['Good morning!', 'It is raining today.', 'Leave early.']
  )
})

test('a time survives, because an alarm line is full of them', () => {
  assert.deepEqual(splitSentences('Leave at 7.30 today. Do not be late!', 8),
    ['Leave at 7.30 today.', 'Do not be late!'])
})

test('text with no punctuation stays one segment rather than being chopped', () => {
  assert.deepEqual(splitSentences('no punctuation here at all', 8), ['no punctuation here at all'])
})

test('past the limit the tail is joined, never dropped', () => {
  // Losing the user's last sentence would be a silent edit of what they wrote.
  const parts = splitSentences('a. b. c. d. e. f.', 3)
  assert.equal(parts.length, 3)
  assert.ok(parts.join(' ').includes('f.'))
})

test('an abbreviation does split, and that is accepted rather than unnoticed', () => {
  assert.deepEqual(splitSentences('Meet Mr. Chen today.', 8), ['Meet Mr.', 'Chen today.'])
})
