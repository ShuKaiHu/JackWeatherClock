'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const { cacheKey, createCache, createDailyBudget, createRateLimiter } = require('../guards')

const base = {
  latitude: 23.0261,
  longitude: 120.2573,
  timezone: 'Asia/Taipei',
  language: 'zh-TW',
  start: '2026-08-09T22:00:00Z',
  end: '2026-08-10T02:00:00Z'
}

test('neighbours within about a kilometre share a cache entry', () => {
  // 23.0261 and 23.0304 are ~480 m apart; both round to 23.03.
  const a = cacheKey(base)
  const b = cacheKey({ ...base, latitude: 23.0304 })
  assert.equal(a, b)
})

test('a different hour window is a different entry', () => {
  const a = cacheKey(base)
  const b = cacheKey({ ...base, start: '2026-08-10T22:00:00Z' })
  assert.notEqual(a, b)
})

test('the cache serves a hit and forgets it once stale', () => {
  const cache = createCache({ ttlMs: 1_000 })
  cache.set('k', { hours: [] }, 0)

  assert.deepEqual(cache.get('k', 500), { hours: [] })
  assert.equal(cache.get('k', 1_000), null, 'expired exactly at the TTL')
  assert.equal(cache.size, 0, 'and is dropped rather than left to grow')
})

test('the cache evicts the least recently used entry when full', () => {
  const cache = createCache({ maxEntries: 2 })
  cache.set('a', 1)
  cache.set('b', 2)
  cache.get('a') // 'a' is now the more recently used of the two

  cache.set('c', 3)

  assert.equal(cache.get('a'), 1)
  assert.equal(cache.get('b'), null, 'the untouched entry went first')
  assert.equal(cache.get('c'), 3)
})

test('the daily budget stops at its limit and resets at UTC midnight', () => {
  const budget = createDailyBudget({ limit: 2 })
  const day = 1_754_697_600_000 // a UTC midnight

  assert.equal(budget.tryConsume(day), true)
  assert.equal(budget.tryConsume(day + 3_600_000), true)
  assert.equal(budget.tryConsume(day + 7_200_000), false, 'third call is over the limit')

  assert.equal(budget.tryConsume(day + 86_400_000), true, 'next UTC day starts fresh')
  assert.equal(budget.spent, 1)
})

test('the rate limiter throttles one caller without touching another', () => {
  const limiter = createRateLimiter({ limit: 2, windowMs: 1_000 })

  assert.equal(limiter.tryConsume('1.1.1.1', 0), true)
  assert.equal(limiter.tryConsume('1.1.1.1', 100), true)
  assert.equal(limiter.tryConsume('1.1.1.1', 200), false)

  assert.equal(limiter.tryConsume('2.2.2.2', 200), true, 'a different caller is unaffected')
  assert.equal(limiter.tryConsume('1.1.1.1', 1_200), true, 'the window rolls over')
})
