'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const { synthesize, BYTES_PER_SECOND } = require('../tts')
const { resetTokenCache } = require('../google-auth')

// Every one of these failure modes was observed against a live Google speech
// API, and each one used to be reported to the user as something it was not.
// They are stubbed rather than exercised for real because most are
// intermittent: a content refusal that fires on one benign request in six
// cannot be reproduced on demand.

/** A RIFF-wrapped clip of `seconds`, which is what Cloud TTS actually returns. */
function wavBody(seconds) {
  const pcm = Buffer.alloc(Math.round(seconds * BYTES_PER_SECOND), 1)
  const size = (n) => { const b = Buffer.alloc(4); b.writeUInt32LE(n); return b }
  const wav = Buffer.concat([
    Buffer.from('RIFF'), size(36 + pcm.length), Buffer.from('WAVE'),
    Buffer.from('fmt '), size(16), Buffer.alloc(16),
    Buffer.from('data'), size(pcm.length), pcm
  ])
  return { audioContent: wav.toString('base64') }
}

/** Replays a scripted sequence of responses and counts the calls. */
function stubFetch(sequence) {
  let call = 0
  globalThis.fetch = async () => {
    const next = sequence[Math.min(call, sequence.length - 1)]
    call += 1
    if (next.ok) {
      return { ok: true, status: 200, json: async () => next.body ?? wavBody(2) }
    }
    return {
      ok: false,
      status: next.status,
      text: async () => next.detail ?? '',
      json: async () => ({})
    }
  }
  return () => call
}

const run = () => synthesize({
  persona: 'steady', segments: [{ text: '早安' }],
  language: 'zh-Hant', maximumSeconds: 10
})

test.beforeEach(() => {
  resetTokenCache()
  // Stands in for the metadata server, which does not exist off Cloud Run.
  process.env.GOOGLE_ACCESS_TOKEN = 'test-token'
})

test.afterEach(() => {
  delete globalThis.fetch
  delete process.env.GOOGLE_ACCESS_TOKEN
})

test('a content refusal is retried, because it fires on benign text', async () => {
  // Measured at roughly one benign request in six, with identical requests
  // either side succeeding.
  const calls = stubFetch([
    { status: 400, detail: '{"error":{"message":"blocked for safety"}}' },
    { ok: true }
  ])
  const pcm = await run()
  assert.ok(pcm.length > 0)
  assert.equal(calls(), 2, 'should have retried once and then succeeded')
})

test('a refusal that survives every attempt is reported as 422, not 502', async () => {
  stubFetch([{ status: 400, detail: '{"error":{"message":"blocked for safety"}}' }])
  await assert.rejects(run(), (error) => error.status === 422)
})

test('rate limiting is retried and never collapses into upstream_unavailable', async () => {
  // The quota is per project, so one user can trip it for another.
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
  const calls = stubFetch([{ status: 403, detail: 'caller lacks permission' }])
  await assert.rejects(run(), (error) => error.status === 422)
  assert.equal(calls(), 1)
})

test('a response with no audio is retried, then reported as an upstream fault', async () => {
  stubFetch([{ ok: true, body: {} }])
  await assert.rejects(run(), (error) => error.status === 502)
})

test('audio longer than the cap is truncated before it reaches the caller', async () => {
  stubFetch([{ ok: true, body: wavBody(30) }])
  const pcm = await run()
  assert.equal(pcm.length, BYTES_PER_SECOND * 10)
})

test('the request carries a bearer token rather than an API key', async () => {
  // The whole point of moving off the Developer API: there is no key to leak.
  let seen = null
  globalThis.fetch = async (url, options) => {
    seen = { url: String(url), headers: options.headers }
    return { ok: true, status: 200, json: async () => wavBody(2) }
  }
  await run()
  assert.match(seen.url, /texttospeech\.googleapis\.com/)
  assert.equal(seen.headers.Authorization, 'Bearer test-token')
  assert.ok(!('x-goog-api-key' in seen.headers))
  assert.ok(!seen.url.includes('key='))
})
