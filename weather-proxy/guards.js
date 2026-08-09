'use strict'

// The proxy has to answer unauthenticated requests: the app has no credential
// to present that would not also ship inside the APK. So instead of trying to
// prove *who* is calling, these guards bound what any caller can cost.
//
// The asset worth protecting is the WeatherKit allowance — 500,000 calls a
// month — not the proxy's own CPU, which Cloud Run's instance cap already
// limits. All three guards therefore sit in front of the *upstream* call.

/**
 * Weather for one place and hour is the same answer for everybody, so serving
 * it from memory is both the cheapest abuse defence available and a genuine
 * improvement: a whole city asking about tomorrow morning collapses into one
 * upstream call.
 *
 * Coordinates are rounded to two decimals — about 1.1 km, far finer than any
 * forecast grid, so neighbours share an entry without changing the answer.
 */
function cacheKey({ latitude, longitude, timezone, language, start, end }) {
  const round = (value) => value.toFixed(2)
  return [round(latitude), round(longitude), timezone, language, start ?? '', end ?? ''].join('|')
}

function createCache({ ttlMs = 15 * 60_000, maxEntries = 2_000 } = {}) {
  const entries = new Map()

  return {
    get(key, now = Date.now()) {
      const hit = entries.get(key)
      if (!hit) return null
      if (hit.expiresAt <= now) {
        entries.delete(key)
        return null
      }
      // Refresh insertion order so the oldest *unused* entry is evicted first.
      entries.delete(key)
      entries.set(key, hit)
      return hit.value
    },
    set(key, value, now = Date.now()) {
      if (entries.size >= maxEntries) {
        entries.delete(entries.keys().next().value)
      }
      entries.set(key, { value, expiresAt: now + ttlMs })
    },
    get size() {
      return entries.size
    }
  }
}

/**
 * A hard ceiling on upstream calls per UTC day. Apple gives no way to cap the
 * allowance from their side, so if the URL is ever scraped this is what stops a
 * month's quota disappearing in an afternoon. Legitimate traffic is nowhere
 * near it: a user costs a handful of calls a day, and the cache absorbs the
 * overlap between them.
 */
function createDailyBudget({ limit }) {
  let day = null
  let spent = 0

  const dayOf = (now) => Math.floor(now / 86_400_000)

  return {
    tryConsume(now = Date.now()) {
      const today = dayOf(now)
      if (today !== day) {
        day = today
        spent = 0
      }
      if (spent >= limit) return false
      spent += 1
      return true
    },
    get spent() {
      return spent
    }
  }
}

/**
 * Per-caller throttle, so one client cannot burn the daily budget alone. Held
 * in memory per instance, which is imprecise across a scaled-out service — but
 * the instance cap is low and the daily budget is the real backstop, so
 * approximate is enough. Being exact here would mean adding a datastore, and a
 * weather proxy is not worth an extra moving part.
 */
function createRateLimiter({ limit = 60, windowMs = 5 * 60_000, maxClients = 10_000 } = {}) {
  const seen = new Map()

  return {
    tryConsume(client, now = Date.now()) {
      const bucket = seen.get(client)
      if (!bucket || now - bucket.startedAt >= windowMs) {
        if (seen.size >= maxClients) seen.clear()
        seen.set(client, { startedAt: now, count: 1 })
        return true
      }
      if (bucket.count >= limit) return false
      bucket.count += 1
      return true
    }
  }
}

/** Cloud Run puts the caller first in `x-forwarded-for`. */
function clientAddress(request) {
  const forwarded = request.headers['x-forwarded-for']
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim()
  }
  return request.socket?.remoteAddress ?? 'unknown'
}

module.exports = { cacheKey, createCache, createDailyBudget, createRateLimiter, clientAddress }
