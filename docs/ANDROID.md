# Rainy Clock for Android

The Android port lives in `android/` — a standalone Gradle project (Kotlin, Jetpack Compose,
minSdk 26, targetSdk 35, package `com.shukaihu.rainyclock`). It reimplements the shipped iOS
product one-to-one where the platform allows, and this document records every place it could
not, and why. Play Store submission mechanics are in `docs/play-store-submission-checklist.md`.

## Build

```bash
cd android
./gradlew testDebugUnitTest assembleDebug     # unit tests + debug APK
./gradlew bundleRelease \
  -PadmobAppId=ca-app-pub-XXXX~YYYY \
  -PadmobBannerAdUnitId=ca-app-pub-XXXX/ZZZZ  # Play upload artifact (needs signing set up)
```

CI (`.github/workflows/android.yml`) runs the tests and builds the debug APK on every push
that touches `android/`. The alarm tones are **not** duplicated in the repo: a Gradle task
copies the iOS target's `.wav` files into a generated `res/raw/` folder at build time
(CamelCase → `sound_snake_case.wav`), so both platforms ship the same audio from one source.

## Platform substitutions

| iOS (shipped) | Android | Why / consequences |
| --- | --- | --- |
| WeatherKit (`WeatherKitSamplingService`) | **Open-Meteo** (`OpenMeteoWeatherService`) | WeatherKit's REST API would require shipping an Apple private key inside the APK — unacceptable. Open-Meteo needs no key and returns hourly `precipitation_probability` plus a WMO code, mapped onto the same clear/cloudy/rain buckets. **Licensing caveat below.** |
| MapKit geocoding (`MapItemResolver`) | Platform `Geocoder` (`AddressResolver`) | Same posture as iOS (no Google Places billing, no API key). No autocomplete-suggestions API exists, so the "choose from dropdown" flow is reduced to the "actual address in use / Use this location" confirmation flow. |
| AlarmKit + widget Live Activity | `AlarmManager.setAlarmClock` + full-screen intent + foreground service (`AlarmScheduler`, `AlarmRingService`, `AlarmRingActivity`) | `setAlarmClock` is exempt from Doze and survives everything but a reboot; `BootReceiver` re-arms from the persisted summary after reboots, time and timezone changes. Audio plays with `USAGE_ALARM`, which rings through silent mode and DND's alarm exception at the alarm volume — the AlarmKit behaviour, no OS-26 gate needed. Snooze is our own button (1–15 min, off switch honoured), so the pre-iOS-26 "no snooze on the notification path" split does not exist here. |
| `BGTaskScheduler` (`BackgroundWeatherRefresh`) | WorkManager (`WeatherRefreshWorker`) | Same contract: one refresh aimed 45 minutes before the lead-time point re-decides the morning's alarm; a failed round keeps the previous decision and the alarm still rings. WorkManager honours delayed work far more reliably than BGTaskScheduler, so the iOS "three paths and pray" note mostly disappears — but battery-saver modes on some OEMs (especially Chinese OEM ROMs) can still defer it, so the on-open staleness refresh (4-hour rule) is ported too. |
| ATT prompt (`ConsentManager`) | UMP consent only | Android has no ATT. Personalization is governed by the UMP/TCF consent string, which the Google Mobile Ads SDK honours by itself — no manual `npa` juggling. The two-way `canRequestAds` and the rebuild-banner-on-consent-change behaviour (iOS audit findings) are ported. |
| AdMob iOS app + banner unit | New AdMob **Android app** + banner unit | Same AdMob account, same `pub-` ID, so the existing `app-ads.txt` already covers it. Debug builds always use Google's test unit (`AppEnvironment`), and a release build with no configured production unit falls back to the test unit rather than hitting production by accident. |

## Palette and chrome

`ui/theme/Theme.kt` restates the iOS palette rather than using the Material baseline: black
canvas, `#1F1F21` cards, `#2E2E33` filled fields, and iOS's dark-mode system blue `#0A84FF`
as the single accent. The scheme is dark-only, because `ContentView.swift` pins itself with
`preferredColorScheme(.dark)` — `values/themes.xml` matches `values-night` so the launch
window never flashes white. Weather tints are iOS's `.yellow` / `.cyan` / `.blue`, and the
route-weather tiles carry the same top-to-bottom teal→blue gradient, laid out **side by side**
the way the iOS `HStack` presents them.

Two Material roles are deliberately *not* tinted. Sliders draw their inactive track from
`secondaryContainer` and the navigation pill draws from it too, so it stays dark and the mode
chips and tab strip ask for the accent explicitly. The ad banner sits **below** the tab strip
at the very bottom of the window, with the gesture-bar inset moved onto the enclosing column
so the banner is never drawn under the system handle.

## Weather provider: moving to WeatherKit REST (decided 2026-08-09)

Open-Meteo's keyless API is licensed for **non-commercial use** and this app carries ads, so
it cannot ship as-is. The replacement is **Apple's WeatherKit REST API**, chosen 2026-08-09.

**Why, in one number.** Every provider was judged on the ceiling it imposes, because
`RouteWeatherService` issues **one call per sample point** — home, office, and the interior
route points — so a single rain decision costs 2–5 calls, not one. At roughly 90 calls per
user per month:

| Provider | Free allowance | Users before it costs money |
| --- | --- | --- |
| **WeatherKit REST** | 500,000 / month, included in the Apple Developer Program membership already paid for | **~5,500** |
| Google Maps Platform Weather API | 10,000 / month per SKU | ~110 |
| Open-Meteo free tier | 10,000 / day, but **non-commercial only** | licence-blocked, not volume-blocked |

Google's Weather API was rejected despite being the least work to wire up: it costs money
*and* has the lowest ceiling of the three. WeatherKit also means **both platforms make the
same call against the same data**, which for an app whose entire product is one rain decision
is worth more than the convenience of staying inside one vendor.

**The cost: this app now has a backend.** WeatherKit REST authenticates with an ES256 JWT
signed by an Apple private key, and Apple's own guidance is explicit — *"Never distribute your
private key. If you need to create tokens for apps or websites, create an authenticated
service to create and sign your own tokens."* A `.p8` inside an APK is a distributed private
key, so a signing proxy is not a design preference, it is the only compliant option. That
contradicts the "no backend" line in `CLAUDE.md`, which is now out of date for Android.
The proxy is deliberately tiny and stateless, and the app **degrades to the previous rain
decision if it is unreachable** — a proxy outage must never mean a missed alarm.

**The proxy is public, and stays public.** It cannot authenticate callers: any credential it
demanded would ship inside the APK next to the URL. Firebase App Check with Play Integrity is
the only real answer, and it needs the app registered in Play Console — which does not exist
yet. So instead of proving *who* is calling, the proxy bounds what any caller can cost, with
the WeatherKit allowance rather than its own CPU as the thing being defended:

- **A response cache**, 15 minutes, keyed on coordinates rounded to two decimals (~1.1 km,
  far finer than any forecast grid). This is the largest lever by some distance — one hour and
  one neighbourhood is the same answer for everybody, so a whole city collapses into a single
  upstream call. Measured on Cloud Run: 0.83 s cold, 0.09 s cached.
- **A per-caller throttle**, 60 requests per 5 minutes, so one client cannot drain the day
  alone. Verified end to end: the 56th distinct request onwards answers `429`.
- **A hard daily ceiling on upstream calls** (`DAILY_UPSTREAM_LIMIT`, 5,000 — roughly 150,000
  a month against an allowance of 500,000). Apple offers no way to cap the allowance from
  their side, so this is what stops a scraped URL draining the month in an afternoon.

The cache is checked **before** the throttle on purpose: a cached answer costs no allowance,
and nobody should be refused an answer someone else already paid for. Hammering cached
coordinates therefore costs only Cloud Run CPU, which `--max-instances 3` already bounds.

**Auth shape** (from Apple's docs, exact — the token is rejected if it carries extra claims):
header `alg: ES256`, `kid: <10-char Key ID>`, `id: "<TeamID>.<ServiceID>"`; claims `iss:
<TeamID>`, `iat`, `exp`, `sub: <ServiceID>`; sent as `Authorization: Bearer <token>`.
The data call is `GET https://weatherkit.apple.com/api/v1/weather/{language}/{lat}/{lon}`
with `dataSets=forecastHourly` and a **required** `timezone`. Each `HourWeatherConditions`
carries `forecastStart`, `precipitationChance` (0–1) and `conditionCode` — a one-to-one match
for what `WeatherKitSamplingService` already consumes on iOS, so the three-bucket mapper is
unchanged.

Until the swap lands, `OpenMeteoWeatherService` stays in the tree and the Route tab keeps its
"Weather data by Open-Meteo.com" attribution; **do not ship a release that pairs the
Open-Meteo free tier with ads.**

## Google Maps route preview + on-route rain sampling

The Route tab renders the commute on a Google map (Maps SDK for Android via `maps-compose`)
with the polyline, travel time and distance from the **Routes API** (`computeRoutes`).
Beyond the preview, the route feeds the alarm itself: `RouteSampler` picks interior points
along the polyline — none under 4 km, the midpoint from 4–20 km, quarter/mid/three-quarter
points beyond — and `EndpointRouteWeatherService` rain-checks **home, those points, and the
office**; any of them over the threshold pulls the alarm earlier. (This goes beyond the
shipped iOS app, which samples endpoints only; it implements the long-intended on-route
check. The deleted iOS `RoutePolylineSampler` trapped on single-sample requests — the
Android sampler's degenerate cases are unit-tested.)

Configuration: one Google Maps Platform API key with **Maps SDK for Android** and
**Routes API** enabled, passed as `-PmapsApiKey=…` (or `mapsApiKey` in
`~/.gradle/gradle.properties`). Restrict the key in the Cloud console to the app's package
name + signing-cert SHA-1 — the Routes client sends `X-Android-Package` / `X-Android-Cert`
so restricted keys work over REST too. **With no key configured everything degrades
gracefully**: the map card hides, and the rain decision falls back to the endpoint-only
check. Mobile map display is free; Routes API has a 10k-calls/month free tier — cap the
quota in the console and this app's usage (one call per preview, one per scheduling round)
never approaches it — **provided every offered mode stays in the Essentials tier**, which is
why the scooter mode was dropped (see "Deliberately not ported"). Routes API bills by feature
tier, not by call count alone: `TRAFFIC_AWARE` modifiers are Pro, two-wheeler routing is
Enterprise, and neither draws on the Essentials free allowance.

## Deliberately not ported

- **The scooter commute mode** (decision 2026-08-09). Routes API prices two-wheeler routing
  (`TWO_WHEELER`) as an **Enterprise-tier feature, outside the 10,000-call Essentials free
  allowance**, while `DRIVE` / `WALK` / `TRANSIT` all stay inside it. Scooters are the most
  common commute in this app's home market, so keeping the mode would have routed the
  *majority* of real usage through the only billable path — on an ad-supported free app whose
  revenue is currently US$0. iOS keeps its scooter pill (Apple Maps charges nothing and has
  no two-wheeler mode anyway, so it already shows a driving estimate); Android offers Car,
  Walking and Transit only. A settings blob still carrying `"scooter"` decodes to `CAR`
  through `coerceInputValues` rather than failing and wiping every other field — pinned by a
  test in `CommuteAlarmSettingsTest`.
- **Address autocomplete dropdown.** No platform API; see the geocoding row above.
- **Live Activity / widget.** AlarmKit forced the iOS widget extension into existence. The
  Android alarm needs no extension; the ring notification itself carries Stop and Snooze.
- **Ten-channels-for-ten-tones.** Notification channel sounds are immutable after creation,
  so the alarm channel is silent and `AlarmRingService` plays the chosen tone itself —
  which is also what keeps the tone looping.

## Behaviour contracts kept from the iOS audit

- A failed alarm registration never persists as "scheduled" (summary saved only after
  `setAlarmClock` succeeds).
- Parameter edits auto-refresh an armed alarm after a 1.5 s debounce; address edits remove
  the alarm outright and only the schedule button re-arms it.
- The rain decision is re-made per morning (WorkManager + after-fire re-arm + on-open 4-hour
  staleness check), never frozen at scheduling time.
- Sound preview plays with `USAGE_ALARM` so it is audible with the ringer muted.
- A failed banner load logs its error in debug builds; a failed consent round does not latch.

## 繁體中文摘要

`android/` 是獨立的 Gradle 專案（Kotlin + Compose，minSdk 26、targetSdk 35）。核心邏輯
（見下）之外，路線預覽用 Google Maps（地圖顯示免費）＋ Routes API（每月一萬次免費，
在主控台把配額鎖在免費額度內），金鑰用 `-PmapsApiKey=…` 傳入並在 Cloud 主控台綁定套件
名稱＋簽章憑證；**沒設金鑰時地圖卡片自動隱藏、降雨判斷退回只查住家與公司**。路線同時
餵給鬧鐘判斷：依距離取路線內部取樣點（<4 公里不取、4–20 公里取中點、更長取 1/4、1/2、
3/4 三點），住家／途中任一點／公司任一處超過降雨門檻就提前響鈴——這是 iOS 版一直想做
而未做的行為，Android 版先行。核心邏輯
（鬧鐘時間計算、天氣決策、設定模型）從 iOS 版一比一移植並附單元測試；平台差異如下：
天氣改用 Open-Meteo（**免金鑰，但免費層限非商業使用——上架含廣告前必須訂閱其商業方案、
換供應商、或先拿掉廣告**，介面已抽象好可直接抽換）；地址解析用系統 Geocoder（同樣不需
Google 金鑰，但沒有自動完成建議，保留「實際使用地址／確認使用」流程）；鬧鐘用
`AlarmManager.setAlarmClock` + 全螢幕通知 + 前景服務播放 `USAGE_ALARM` 音訊，靜音與勿擾
下都會響，重開機由 `BootReceiver` 重排；早晨重新判斷降雨改用 WorkManager，比 iOS 的
BGTaskScheduler 可靠得多；Android 沒有 ATT，廣告個人化完全由 UMP 同意書決定。路線地圖
預覽刻意不移植（iOS 的決策本來就只取樣住家與公司兩端點）。上架流程見
`docs/play-store-submission-checklist.md`。
