'use strict'

// An access token for Google Cloud APIs, taken from the environment the service
// already runs in.
//
// This is what replaces the Gemini API key, and the point is that there is no
// longer a credential to hold: Cloud Run hands its service account's token to
// anything running inside it, so nothing has to be created, stored in Secret
// Manager, rotated, or kept out of a transcript. Moving to Cloud
// Text-to-Speech and Vertex AI is what makes that possible — the Gemini
// Developer API only authenticates with a key.

const METADATA_TOKEN_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token'

/** Refreshed a minute early, because a token that expires mid-request is a 401. */
const EXPIRY_MARGIN_MS = 60_000

let cached = null

async function fromMetadataServer() {
  const response = await fetch(METADATA_TOKEN_URL, {
    headers: { 'Metadata-Flavor': 'Google' },
    signal: AbortSignal.timeout(5_000)
  })
  if (!response.ok) {
    throw new Error(`metadata server responded ${response.status}`)
  }
  const { access_token: token, expires_in: expiresIn } = await response.json()
  return { token, expiresAt: Date.now() + expiresIn * 1_000 }
}

/**
 * Returns a bearer token, cached until shortly before it expires.
 *
 * `GOOGLE_ACCESS_TOKEN` exists only so the service can be run on a laptop,
 * where there is no metadata server: fill it from
 * `gcloud auth print-access-token`. It is not how the deployed service
 * authenticates and should never be set on Cloud Run.
 */
async function accessToken(now = Date.now()) {
  const override = process.env.GOOGLE_ACCESS_TOKEN
  if (override) {
    return override
  }

  if (cached && cached.expiresAt - EXPIRY_MARGIN_MS > now) {
    return cached.token
  }

  cached = await fromMetadataServer()
  return cached.token
}

/** Test seam: forget any cached token. */
function resetTokenCache() {
  cached = null
}

module.exports = { accessToken, resetTokenCache }
