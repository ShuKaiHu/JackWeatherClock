# Rainy Clock — Android status & backlog

Living handoff document for the **Android port**. Read this first when picking Android back
up; update it when something ships, gets blocked, or gets discovered.

The iPhone app keeps its own log in `docs/STATUS-IOS.md`. Keep the two apart: they ship on
different schedules and are often worked on at the same time, and a shared file means two
sessions writing over each other. Anything true of both platforms goes in `docs/STATUS.md`.

- Port architecture, platform substitutions and Android gotchas → `docs/ANDROID.md`
- Play Store submission runbook → `docs/play-store-submission-checklist.md`
- Product reasoning and rejected alternatives (both platforms) → `docs/PRODUCT_DECISIONS.md`

Last updated: 2026-08-13.

## Android port — in development

Started 2026-08-08 on branch `claude/android-play-store-release-jykw59`. A standalone Gradle
project in `android/` (Kotlin + Compose, minSdk 26, targetSdk 35) reimplementing the shipped
product: endpoint rain check, smart alarm with the same time math (unit-tested against the
iOS semantics), exact alarms that ring through silent mode and DND, snooze, boot re-arm,
WorkManager morning re-decision, UMP consent + one AdMob banner, zh-Hant + English strings.
CI builds it (`.github/workflows/android.yml`); the alarm tones are copied from the iOS
target's `.wav`s at build time, not duplicated.

Since the first push it also gained the **Google Maps route preview** (Maps SDK +
Routes API, key via `-PmapsApiKey`, hides itself when unconfigured) and — a first for the
product — **on-route rain sampling**: interior points along the polyline (midpoint, or
quarter points on long commutes) are rain-checked alongside home and office, and any of
them over the threshold pulls the alarm earlier. iOS still samples endpoints only.

**Restyled to match iOS on 2026-08-09**: the Material baseline purple is gone, replaced by
the palette `ContentView.swift` defines — black canvas, `#1F1F21` cards, `#2E2E33` filled
fields, iOS dark-mode system blue `#0091FF`, dark-only like iOS. The route-weather segments
now sit side by side as gradient tiles the way the iOS `HStack` presents them, and the ad
banner moved *below* the tab strip. Details and the two Material colour roles left
deliberately untinted are in `docs/ANDROID.md`.

Decisions and deliberate gaps (no address autocomplete, Open-Meteo instead of WeatherKit —
the WeatherKit REST key cannot ship in an APK; four options incl. a tiny signing proxy are
documented) are in `docs/ANDROID.md`.

### Outstanding — everything still owed, in priority order

Mechanics live in `docs/play-store-submission-checklist.md`; this is the "what is left and
who has to do it" view. Items marked **(you)** need a human with console access, a payment
method, or a product call — nobody else can close them.

**1. Money and secrets — open right now, do these first**

- [x] **Maps API key restricted — done and verified 2026-08-09.** Both halves are set:
      application restriction → Android apps → `com.shukaihu.rainyclock` + the debug SHA-1
      `3A:6A:BC:72:DB:DB:B8:81:E6:EB:68:52:99:F1:1F:8D:24:07:AD:32`, and API restriction →
      Maps SDK for Android + Routes API only. Confirmed by probing from a laptop with no
      Android headers: Geocoding answers `REQUEST_DENIED` ("not authorized to use this API
      key") and Routes answers `PERMISSION_DENIED` ("Requests from this Android client
      application `<empty>` are blocked"). **Still owed on this key: the upload-cert and Play
      App Signing SHA-1s** must be added before release, or maps break for everyone who
      installs from Play — Google re-signs the APK, so the shipped build presents the *Play*
      certificate, not the upload one. Re-run the same probe after adding them.
- [x] **Routes API capped at 300 requests/day, 2026-08-09** (≈9,000/month, inside the free
      Essentials allowance), plus a US$1 monthly budget alert on the project. Worth knowing
      for anyone who goes looking: Maps Platform has **no daily cap by default** once billing
      is attached, so this was adding a limit that did not exist, not lowering one. The budget
      alert only notifies — the quota is the hard stop.
- [ ] **(you) Disable the ~30 Maps APIs the console enabled by default.** The app calls two.
      Route Optimization, Navigation SDK and Places are expensive; every one left enabled is
      reachable with a leaked key.

**2. Weather provider — decided, working locally, not yet deployed**

Open-Meteo's non-commercial licence made it unshippable alongside ads. **Apple WeatherKit REST
was chosen on 2026-08-09** and works end to end on the emulator. Full reasoning and the
provider comparison are in `docs/ANDROID.md`; the short version is that the free allowance is
500,000 calls a month against Google's 10,000, it costs nothing extra because the Apple
Developer Program membership is already paid for, and both platforms now read the *same*
forecast — which matters for an app whose entire product is one rain decision.

That is not cosmetic. On the first real comparison, the same hour and coordinate read **57%
on WeatherKit and 92% on Open-Meteo**. Both cleared the 50% threshold that morning by luck;
a 45/80 split would have woken iPhone users early and left Android users asleep. Expect the
Android alarm to fire *less* often than it used to, and revisit whether 50% is still the right
default.

- [x] Signing proxy written (`weather-proxy/`, zero-dependency Node) and verified against the
      real key: HTTP 200, hourly `precipitationChance` and `conditionCode` returned.
- [x] `WeatherKitProxySamplingService` wired behind the existing `WeatherSamplingService`
      seam; `-PweatherProxyUrl` selects it and an unset value falls back to Open-Meteo so a
      credential-less checkout still builds. Verified on the emulator through
      `http://10.0.2.2:8080` — cleartext is permitted **only** by a `src/debug` network
      security config, so release builds still refuse it.
- [x] Attribution now follows the provider actually in use, because showing the wrong credit
      breaches one licence or the other. It says "Apple Weather" **in words**: the  glyph the
      iOS app uses is U+F8FF, a private-use codepoint only Apple's fonts carry, and on Android
      it renders as *nothing* — leaving "Weather data provided by Weather".
- [x] Key stored at `~/.config/rainyclock/AuthKey_QQLPN677CU.p8`, mode 600, and in Secret
      Manager as `weatherkit-private-key`. It briefly sat inside this repo, which is
      **public** — `*.p8` is now gitignored as a second line of defence, and the history is
      clean. Apple allows exactly one download; losing the file means a new key.
- [x] **Proxy deployed to Cloud Run 2026-08-09**, `asia-east1`, max 3 instances, 256 MiB,
      the key mounted from Secret Manager rather than baked into the deploy command:
      `https://rainyclock-weather-proxy-510427696731.asia-east1.run.app`. Verified from
      the emulator with the local proxy stopped, so the reading genuinely came from the
      cloud service. Build with
      `-PweatherProxyUrl=https://rainyclock-weather-proxy-510427696731.asia-east1.run.app`.
- [x] **Proxy abuse defences, 2026-08-09.** It has to stay unauthenticated — any credential
      it demanded would ship in the APK beside the URL — so it bounds cost instead of
      identity: a 15-minute response cache keyed on ~1.1 km coordinates, a 600-per-5-minute
      per-caller throttle, and a hard 5,000/day ceiling on upstream calls. The throttle is
      loose on purpose: a public IP is not a person, and carrier-grade NAT is the norm here. All three
      verified against the deployed service; the throttle starts answering `429` on the
      56th distinct request. Reasoning in `docs/ANDROID.md`.
- [ ] **Firebase App Check** once a Play Console listing exists — Play Integrity is the only
      thing that actually proves a request came from a genuine build, and it needs the app
      registered in Play. Until then the cost bounds above are the whole defence.

**3. Accounts and assets that take calendar time**

- [ ] **(you) Play Developer account** (US$25). If it registers as a *personal* account, the
      **12-testers-for-14-days closed test** applies — that is the longest pole in the whole
      schedule, so open the account early even if the build is not final.
- [ ] **(you) Upload keystore**, generated once and backed up outside the repo, with Play App
      Signing opted in at first upload. Its SHA-1 (and Play's) then go into the Maps key.
- [ ] **(you) AdMob: register a new Android app** and one anchored adaptive banner unit; pass
      both as Gradle properties at build time. `app-ads.txt` needs no change — it is
      per-account and already verified. **Blocked since 2026-08-23: the publisher account
      was disabled for invalid traffic** (`docs/admob-invalid-traffic-appeal.md`); nothing
      can be registered under it until the appeal resolves, and a replacement account must
      not be opened. If the disablement sticks, the Android release ships ad-free or on a
      non-Google network.

**4. Content and code left to write**

- [x] **`docs/privacy-policy.html` covers Android, 2026-08-09**, both languages: Google Maps
      Platform named, a Tracking section that states there is no ATT prompt on Android, and a
      new section on the WeatherKit relay — coordinates now leave the device to a service we
      operate, which nothing disclosed before. Rounded to ~1 km, no identifier, in memory for
      ~15 minutes, never written down. **Only counts once pushed and live**, and the Play
      Data safety answers have to agree with it.
- [ ] **Android screenshots** for the listing. `pics/20260729/` is iPhone-framed and the
      Android UI genuinely differs; retake on the emulator. The dark/blue restyle means the
      old shots are wrong twice over.
- [ ] Feature graphic 1024×500 and a 512×512 icon.
- [x] **`WeekdaySelector` font scaling fixed 2026-08-09.** The circle now grows with the
      system font scale (capped at 1.9x) and the row wraps to four per line above 1.3x, since
      seven circles wide enough for scaled text do not fit across a phone. Verified at
      `font_scale 1.8`: all seven day names render in full, no ellipses.
- [x] **Branch merged to `main` via PR #2, 2026-08-13.** Nothing sits uncommitted. Later
      Android work keeps landing on `claude/android-play-store-release-jykw59` and reaches
      `main` through new PRs.

**5. Play Console declarations and rollout** — all in the checklist doc: data safety form,
ads declaration, the **`USE_EXACT_ALARM`** permission declaration (mandatory; the release is
rejected on upload without it), content rating, then internal test → closed test if required
→ staged production rollout.

**Already closed:** the Maps Platform key itself. Project `RainyClock` (`510427696731`),
billing attached, Maps SDK for Android + Routes API enabled, key in
`~/.gradle/gradle.properties`. Verified end to end on the emulator 2026-08-09 — map tiles,
polyline, 26 min / 17.2 km on a real Tainan commute.

**The scooter mode was dropped from Android on 2026-08-09.** Routes API prices two-wheeler
routing as Enterprise tier, outside the free Essentials allowance, and scooters are the most
common commute in the target market — so the mode would have put most real traffic on the
only billable path. Android now offers Car, Walking and Transit; iOS keeps its scooter pill
(Apple Maps is free and has no two-wheeler mode, so it already shows a driving estimate).
Reasoning in `docs/PRODUCT_DECISIONS.md`, both languages. A settings blob still holding
`"scooter"` degrades to `CAR` instead of wiping every other field — pinned by a test.
