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

## The Open-Meteo licensing caveat

Open-Meteo's keyless API is licensed for **non-commercial use**; an ad-supported app is
commercial. Before the Play release goes live with ads enabled, pick one:

1. Subscribe to Open-Meteo's commercial API plan (adds an API key; one-line change in
   `OpenMeteoWeatherService`).
2. Swap the provider — everything sits behind the `WeatherSamplingService` interface, so a
   MET Norway (free, CC-BY attribution, but thin precipitation-probability coverage outside
   the Nordics) or paid-tier implementation is a drop-in.
3. Ship the first release without the banner (remove the ads dependency), keep Open-Meteo
   free tier legitimately, and add ads once a provider decision is made.

The attribution string on the Route tab ("Weather data by Open-Meteo.com") satisfies their
attribution requirement either way.

## Deliberately not ported

- **Route map preview** (`RoutePreviewMapView`, MapKit polyline). Google's Directions/Routes
  API needs a billing-enabled key; the shipped iOS weather decision never used the polyline
  anyway — it samples the home and office endpoints only (see PRODUCT_DECISIONS.md). The
  Route tab shows the endpoint weather without a map. Maps SDK for Android is free for mobile
  if a map view is ever wanted.
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
（鬧鐘時間計算、天氣決策、設定模型）從 iOS 版一比一移植並附單元測試；平台差異如下：
天氣改用 Open-Meteo（**免金鑰，但免費層限非商業使用——上架含廣告前必須訂閱其商業方案、
換供應商、或先拿掉廣告**，介面已抽象好可直接抽換）；地址解析用系統 Geocoder（同樣不需
Google 金鑰，但沒有自動完成建議，保留「實際使用地址／確認使用」流程）；鬧鐘用
`AlarmManager.setAlarmClock` + 全螢幕通知 + 前景服務播放 `USAGE_ALARM` 音訊，靜音與勿擾
下都會響，重開機由 `BootReceiver` 重排；早晨重新判斷降雨改用 WorkManager，比 iOS 的
BGTaskScheduler 可靠得多；Android 沒有 ATT，廣告個人化完全由 UMP 同意書決定。路線地圖
預覽刻意不移植（iOS 的決策本來就只取樣住家與公司兩端點）。上架流程見
`docs/play-store-submission-checklist.md`。
