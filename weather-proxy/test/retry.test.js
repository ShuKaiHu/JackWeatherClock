'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const { synthesize, BYTES_PER_SECOND } = require('../tts')

// Every one of these failure modes was observed against the live API, and each
// one used to be reported to the user as something it was not.

const audioBody = () => {
  const pcm = Buffer.alloc(BYTES_PER_SECOND, 1).toString('base64')
  return { output: [{ content: [{ audio: { data: pcm } }] }] }
}

/** Replays a scripted sequence of responses and counts the calls. */
function stubFetch(sequence) {
  let call = 0
  globalThis.fetch = async () => {
    const next = sequence[Math.min(call, sequence.length - 1)]
    call += 1
    if (next.ok) {
      return { ok: true, status: 200, json: async () => audioBody() }
    }
    return {
      ok: false,
      status: next.status,
      text: async () => next.body ?? '',
      json: async () => ({})
    }
  }
  return () => call
}

const run = () => synthesize({
  apiKey: 'test', persona: 'steady', segments: [{ text: '早安' }],
  language: 'zh-Hant', maximumSeconds: 10
})

test.afterEach(() => { delete globalThis.fetch })

test('a content block is retried, because it fires on benign text', async () => {
  // Measured at roughly one benign request in six, with identical requests
  // either side succeeding.
  const calls = stubFetch([
    { status: 400, body: '{"error":{"code":"content_blocked"}}' },
    { ok: true }
  ])
  const pcm = await run()
  assert.ok(pcm.length > 0)
  assert.equal(calls(), 2, 'should have retried once and then succeeded')
})

test('a block that survives every attempt is reported as 422, not 502', async () => {
  stubFetch([{ status: 400, body: '{"error":{"code":"content_blocked"}}' }])
  await assert.rejects(run(), (error) => error.status === 422)
})

test('rate limiting is retried and never collapses into upstream_unavailable', async () => {
  // Gemini rate-limits per project, so one user can trip it for another.
  const calls = stubFetch([{ status: 429 }, { ok: true }])
  await run()
  assert.equal(calls(), 2)
})

test('sustained rate limiting surfaces as 429 so the app can say "try again"', async () => {
  stubFetch([{ status: 429 }])
  await assert.rejects(run(), (error) => error.status === 429)
})

test('a 5xx is retried', async () => {
  const calls = stubFetch([{ status: 503 }, { ok: true }])
  await run()
  assert.equal(calls(), 2)
})

test('a genuine bad request is not retried — retrying cannot fix it', async () => {
  const calls = stubFetch([{ status: 403, body: 'API key invalid' }])
  await assert.rejects(run(), (error) => error.status === 422)
  assert.equal(calls(), 1)
})

test('prose instead of audio is retried, then reported as an upstream fault', async () => {
  globalThis.fetch = async () => ({
    ok: true, status: 200,
    json: async () => ({ candidates: [{ content: { parts: [{ text: 'I cannot' }] } }] })
  })
  await assert.rejects(run(), (error) => error.status === 502)
})

test('audio longer than the cap is truncated before it reaches the caller', async () => {
  globalThis.fetch = async () => ({
    ok: true, status: 200,
    json: async () => ({ output: [{ content: [{ audio: {
      data: Buffer.alloc(BYTES_PER_SECOND * 30, 1).toString('base64')
    } }] }] })
  })
  const pcm = await synthesize({
    apiKey: 'test', persona: 'steady', segments: [{ text: '早安' }],
    language: 'zh-Hant', maximumSeconds: 10
  })
  assert.equal(pcm.length, BYTES_PER_SECOND * 10)
})
