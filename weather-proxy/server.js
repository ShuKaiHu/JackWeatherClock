'use strict'

const http = require('node:http')
const { createTokenCache } = require('./token')
const {
  cacheKey,
  clientAddress,
  createCache,
  createDailyBudget,
  createRateLimiter
} = require('./guards')

// A stateless signing proxy in front of Apple's WeatherKit REST API. It exists
// for one reason: the ES256 private key that authenticates a WeatherKit request
// cannot ship inside an APK, and Apple's own guidance is to put the signing
// behind a service. Everything else about it is deliberately boring — no
// storage, no user data, no dependencies beyond Node's standard library.

const {
  WEATHERKIT_TEAM_ID: teamId,
  WEATHERKIT_SERVICE_ID: serviceId,
  WEATHERKIT_KEY_ID: keyId,
  WEATHERKIT_PRIVATE_KEY: privateKey,
  PROXY_SHARED_SECRET: sharedSecret,
  PORT = '8080'
} = process.env

for (const [name, value] of Object.entries({
  WEATHERKIT_TEAM_ID: teamId,
  WEATHERKIT_SERVICE_ID: serviceId,
  WEATHERKIT_KEY_ID: keyId,
  WEATHERKIT_PRIVATE_KEY: privateKey
})) {
  if (!value) {
    console.error(`Missing required environment variable ${name}`)
    process.exit(1)
  }
}

const currentToken = createTokenCache({ teamId, serviceId, keyId, privateKey })

// 5,000 a day is roughly 150,000 a month against an allowance of 500,000, so
// there is headroom for real growth while a scraped URL still cannot drain the
// month in an afternoon.
const responseCache = createCache()
const dailyBudget = createDailyBudget({ limit: Number(process.env.DAILY_UPSTREAM_LIMIT ?? 5_000) })
const rateLimiter = createRateLimiter()

const UPSTREAM_TIMEOUT_MS = 10_000

const sendJson = (response, status, body) => {
  const payload = JSON.stringify(body)
  response.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
    'Cache-Control': 'no-store'
  })
  response.end(payload)
}

const finiteNumber = (raw, min, max) => {
  const value = Number(raw)
  return Number.isFinite(value) && value >= min && value <= max ? value : null
}

/**
 * Only the three fields the app actually reads are passed through. Forwarding
 * Apple's full payload would ship temperature, pressure and wind to a client
 * that ignores them, and would make any future response change a client problem.
 */
const projectHours = (weather) =>
  (weather?.forecastHourly?.hours ?? []).map((hour) => ({
    forecastStart: hour.forecastStart,
    precipitationChance: hour.precipitationChance,
    conditionCode: hour.conditionCode
  }))

async function fetchWeather({ latitude, longitude, timezone, language, start, end }) {
  const url = new URL(
    `https://weatherkit.apple.com/api/v1/weather/${encodeURIComponent(language)}/${latitude}/${longitude}`
  )
  url.searchParams.set('dataSets', 'forecastHourly')
  // Apple documents `timezone` as required, and silently reshapes the forecast
  // roll-up without it.
  url.searchParams.set('timezone', timezone)
  if (start) url.searchParams.set('hourlyStart', start)
  if (end) url.searchParams.set('hourlyEnd', end)

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${currentToken()}` },
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
  })

  if (!response.ok) {
    const detail = await response.text().catch(() => '')
    const error = new Error(`WeatherKit responded ${response.status}: ${detail.slice(0, 200)}`)
    error.status = response.status
    throw error
  }

  return response.json()
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost')

  if (url.pathname === '/healthz') {
    return sendJson(response, 200, { ok: true })
  }

  if (request.method !== 'GET' || url.pathname !== '/v1/weather') {
    return sendJson(response, 404, { error: 'not_found' })
  }

  // Raises the bar against casual scraping of the quota. It is not real
  // authentication — the secret ships in the APK too — so the daily cap and
  // Cloud Run's own limits stay the actual backstop.
  if (sharedSecret && request.headers['x-rainyclock-key'] !== sharedSecret) {
    return sendJson(response, 401, { error: 'unauthorized' })
  }

  const latitude = finiteNumber(url.searchParams.get('lat'), -90, 90)
  const longitude = finiteNumber(url.searchParams.get('lon'), -180, 180)
  const timezone = url.searchParams.get('tz')

  if (latitude === null || longitude === null || !timezone) {
    return sendJson(response, 400, { error: 'lat, lon and tz are required' })
  }

  const query = {
    latitude,
    longitude,
    timezone,
    language: url.searchParams.get('lang') || 'en',
    start: url.searchParams.get('start'),
    end: url.searchParams.get('end')
  }

  // Served from memory, so it costs no allowance and no caller can be throttled
  // out of an answer somebody else already paid for.
  const key = cacheKey(query)
  const cached = responseCache.get(key)
  if (cached) {
    return sendJson(response, 200, cached)
  }

  if (!rateLimiter.tryConsume(clientAddress(request))) {
    return sendJson(response, 429, { error: 'rate_limited' })
  }

  if (!dailyBudget.tryConsume()) {
    // Loud, because reaching this on real traffic means the limit is wrong,
    // and reaching it otherwise means the URL is being abused.
    console.error(`Daily upstream limit reached after ${dailyBudget.spent} calls`)
    return sendJson(response, 503, { error: 'daily_limit_reached' })
  }

  try {
    const weather = await fetchWeather(query)
    const body = { hours: projectHours(weather) }
    responseCache.set(key, body)
    sendJson(response, 200, body)
  } catch (error) {
    // 401 from Apple means the token is wrong — a configuration fault, not a
    // client one. Say so in the log; the client only ever needs "try later".
    console.error(`Weather request failed: ${error.message}`)
    sendJson(response, 502, { error: 'upstream_unavailable' })
  }
})

server.listen(Number(PORT), () => {
  console.log(`weather-proxy listening on ${PORT}`)
})
