# Rainy Clock App Store Submission Checklist

## Current Build

| Item | Status |
| --- | --- |
| App version | `1.6` |
| Build number | `10` |
| Review status | Submitted for App Review (2026-07-23) — Processing → Waiting for Review |
| Archive path | `build/RainyClock-1.6-10.xcarchive` |
| Bundle identifier | `com.shukaihu.RainyClock` |
| Device family | iPhone only |
| Primary language | Traditional Chinese |

## Submission History

- `1.5 (7)` — **Rejected** 2026-07-22, Guideline 5.1.2(i) (Privacy – Data Use and Sharing): the App Privacy label declared data used to track the user, but the app has no App Tracking Transparency prompt.
- `1.6 (10)` — Resubmitted 2026-07-23 with the fix below.

## Rejection Resolution (5.1.2(i))

Chosen approach: the app does **not** track. No ATT prompt is added.

- App Privacy in App Store Connect corrected: every data type has "Used to Track You" **unchecked**. Data collection (advertising data, coarse location, product interaction, crash/performance data, device ID) is declared as collected for non-personalized ad serving and diagnostics only, not tracking.
- Ads are served via Google AdMob configured for **non-personalized ads only** (`npa=1` in `RainyClock/AdMobBannerView.swift`); the app never accesses the IDFA.
- `RainyClock/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`.
- App Review note (English) added to the version's 備註 field explaining the above.

## Completed

- App name and bundle renamed to Rainy Clock / 雨天鬧鐘; app is iPhone only.
- App icon is included in the Xcode asset catalog.
- GitHub Pages support and privacy pages exist under `docs/`.
- Weather source is Apple Weather / WeatherKit; route preview uses Apple Maps.
- Bottom ad uses Google AdMob banner placement, forced non-personalized (`npa=1`).
- Local notification alarm scheduling implemented, incl. 5-minute follow-up rings (max 10, capped to iOS's 64-pending limit) that stop when the alarm is acknowledged while the weekly schedule stays armed.
- Public-transit commute mode shows home/work pins plus `calculateETA` travel time and distance (MapKit cannot route transit geometry).
- Taiwan address validation generalized (postal-romanization table + dynamic Han→Latin transliteration, house-number and wrong-city guards).
- Address search results follow the language the user typed (Chinese input → Chinese results, English input → English results).
- App Privacy answers completed in App Store Connect (see Rejection Resolution).
- App Review notes and contact info filled in App Store Connect.
- App Store screenshots uploaded (3 iPhone 6.5" screenshots).
- App Store metadata draft is in `docs/appstore-metadata.md`.
- Source pushed to `origin/main` (commits `69155da`, `e12bacf`).

## Still Required Before Public Release

- Await App Review result for `1.6 (10)` (email notification, usually within 24h).
- Release option is currently set to manual release after approval — release when ready.

## Known Review / QA Risks

- iOS local notifications can only play short bundled notification sounds; this app is not a full-screen system alarm replacement.
- Apple Maps / Apple's Taiwan geocoder can mis-resolve some queries. Notably the English POI phrase "Taipei Main Station" mis-geocodes to Maan / Wulai District in both CLGeocoder and MKLocalSearch; the app's address-validation layer correctly rejects the mismatch (shows "address not found") rather than pinning the wrong location, and the autocomplete-dropdown path resolves it correctly. When Apple returns a nearby suggested location, the app shows the actual address in use for confirmation.
- Google Places fallback requires a valid API key before enabling; `GooglePlacesAPIKey` is currently empty in `RainyClock/Info.plist`, so the app relies on Apple geocoding.
- Xcode upload warns about missing dSYM files for Google SDK frameworks (GoogleMobileAds, UserMessagingPlatform). This does not block upload; only Google SDK crash symbolication is limited.

## Useful URLs

- Support: `https://shukaihu.github.io/RainyClock/support.html`
- Privacy Policy: `https://shukaihu.github.io/RainyClock/privacy-policy.html`
- Repository: `https://github.com/ShuKaiHu/RainyClock`
