'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const { PERSONA_IDS, EMOTION_IDS, EMOTIONS, buildPrompt, styleLanguage, tagFor } = require('../personas')
const { extractAudio, truncateToSeconds, BYTES_PER_SECOND } = require('../tts')

const one = (text, emotion) => [{ text, emotion }]

test('every persona resolves to a voice and both style languages', () => {
  assert.equal(PERSONA_IDS.length, 6)
  for (const persona of PERSONA_IDS) {
    const zh = buildPrompt({ persona, segments: one('起床囉'), language: 'zh-Hant' })
    const en = buildPrompt({ persona, segments: one('Wake up'), language: 'en-US' })
    assert.ok(zh.voice.length > 0, `${persona} has no voice`)
    assert.notEqual(zh.prompt, en.prompt, `${persona} gives the same direction in both languages`)
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
    assert.doesNotMatch(built.prompt, spokenAloud, `${emotion} emits a vocalized adjective tag`)
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
  assert.ok(built.prompt.includes('[extremely fast]'))
})

test('an unknown emotion degrades to no tag rather than passing text through', () => {
  const built = buildPrompt({ persona: 'steady', segments: one('早安', 'ecstatic'), language: 'zh' })
  assert.ok(built.prompt.includes('早安'))
  assert.doesNotMatch(built.prompt, /\[ecstatic\]/)
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
  assert.match(built.prompt, /早安～該起床囉！.*\[extremely fast\] 今天外面下雨.*\[shouting\] 快起來/s)
})

test('empty segments are dropped without collapsing the rest', () => {
  const built = buildPrompt({
    persona: 'steady',
    segments: [{ text: '早安' }, { text: '  ' }, { text: '起床' }]
  })
  assert.equal(built.prompt.endsWith('早安 起床'), true)
})

test("square brackets in the user's own words are stripped before ours are added", () => {
  const built = buildPrompt({ persona: 'steady', segments: one('[shouting] 快起來'), language: 'zh' })
  assert.ok(!built.prompt.includes('[shouting]'), 'user-supplied tag survived')
  assert.ok(built.prompt.includes('快起來'))
})

test('the sergeant keeps its own tag, which the user cannot forge', () => {
  const built = buildPrompt({ persona: 'sergeant', segments: one('起床'), language: 'zh' })
  assert.ok(built.prompt.includes('[shouting]'))
})

test('the prompt carries an explicit synthesize instruction', () => {
  // Without it the model sometimes reads the direction aloud as dialogue.
  const built = buildPrompt({ persona: 'steady', segments: one('hello'), language: 'en' })
  assert.match(built.prompt, /Synthesize this speech:/)
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

test('the audio blob is found wherever the response shape hides it', () => {
  const blob = Buffer.alloc(2_000, 7).toString('base64')
  assert.equal(extractAudio({ output: [{ content: [{ audio: { data: blob } }] }] }).length, 2_000)
  assert.equal(extractAudio({ candidates: [{ content: { parts: [{ inlineData: { data: blob } }] } }] }).length, 2_000)
})

test('a prose answer instead of audio reads as no audio, not as garbage', () => {
  assert.equal(extractAudio({ candidates: [{ content: { parts: [{ text: 'Sorry, I cannot' }] } }] }), null)
})
