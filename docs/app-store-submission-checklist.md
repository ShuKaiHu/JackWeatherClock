# Rainy Clock App Store Submission Checklist

Ongoing state and the backlog live in `docs/STATUS.md`; this file is the submission reference.

## Current Build

| Item | Status |
| --- | --- |
| App version | `1.6.4` (in development) |
| Build number | `19` |
| Review status | `1.6.3 (18)` uploaded via Organizer and submitted for review 2026-07-27, awaiting verdict |
| Last released | `1.6.2 (17)` — released to the App Store 2026-07-27 |
| Bundle identifier | `com.shukaihu.RainyClock` |
| Extension bundle identifier | `com.shukaihu.RainyClock.AlarmWidget` (added in `1.6.3`) |
| Device family | iPhone only |
| Primary language | Traditional Chinese |

## Submission History

- `1.5 (7)` — **Rejected** 2026-07-22, Guideline 5.1.2(i) (Privacy – Data Use and Sharing): the App Privacy label declared data used to track the user, but the app has no App Tracking Transparency prompt.
- `1.6 (10)` — Resubmitted 2026-07-23 with the 5.1.2(i) fix below. **Rejected** 2026-07-24, Guideline 5.2.5 (Legal – Apple Sites and Services): WeatherKit data shown without the required Apple Weather attribution mark and legal link.
- `1.6.1 (16)` — Submitted 2026-07-25 with the 5.2.5 fix (official Apple Weather mark + legal link in the Route tab weather section), a review note explaining WeatherKit usage, and a screen recording captured on a physical iPhone. **Approved 2026-07-26 and released to the App Store the same day.**
- `1.6.4 (19)` — In development. Debug builds now request Google's test banner unit instead of the production one; see the AdMob section.
- `1.6.3 (18)` — **Submitted 2026-07-27.** Adopts AlarmKit on iOS 26+ (alarm pierces silent mode and Focus), adds snooze on/off with a 1–15 minute interval, the system default alarm tone, automatic re-scheduling when settings change (address changes instead remove the alarm), and the colour-coded status line. First build to ship the `RainyClockAlarmWidget` extension. Release notes and updated description are in `docs/appstore-metadata.md`.
- `1.6.2 (17)` — Submitted 2026-07-27. **Approved and released the same day.** Declares Google's `SKAdNetworkItems` list (50 identifiers) in `Info.plist`, which the shipped builds were missing, and adds the UMP consent flow for EEA/UK/Swiss users. Also the first version to carry a marketing URL (`https://shukaihu.github.io/RainyClock/`), which is what unblocks AdMob's app-ads.txt verification — see below. Release notes are in `docs/appstore-metadata.md`.

## AlarmKit Setup (`1.6.3`)

The alarm rings through silent mode and Focus on iOS 26+ via AlarmKit. Points that matter for submission:

- **No Apple approval needed.** AlarmKit is not gated like Critical Alerts — it only needs `NSAlarmKitUsageDescription` in `Info.plist` (localized in both `InfoPlist.strings`) plus the one-time user prompt. Verified on an iOS 26.2 simulator: the prompt shows the app's own description text.
- **A new target ships with the app: `RainyClockAlarmWidget`** (app extension, `MinimumOSVersion` 26.0, embedded under `PlugIns/`). It renders the snooze Live Activity. AlarmKit requires a widget extension for any alarm that can enter the countdown state, and Apple warns the system may drop such alarms without one — do not remove it. **Its `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` must stay in lockstep with the app's `Info.plist`**, or App Store validation rejects the upload. The app's `Info.plist` hardcodes the version (`GENERATE_INFOPLIST_FILE = NO`), while the extension derives it from build settings, so both need bumping.
- Automatic signing has to mint a second provisioning profile for `com.shukaihu.RainyClock.AlarmWidget` at archive time. First archive after this change may need a Xcode round-trip to register the new App ID.
- The app also declares `NSSupportsLiveActivities`.
- **Upgrade path.** An install that reaches iOS 26 without rescheduling keeps ringing through its old notification alarms (no gap, but no silent-mode piercing either). `rearmAlarmsIfNeeded()` therefore runs on every system, not just pre-26, and the Alarm tab shows `alarmkit_reschedule_notice` until the user schedules once and AlarmKit takes over.
- **Localized strings shown by the alarm** are built with `bundle: .atURL(Bundle.main.bundleURL)` rather than the default `.main`. The widget extension decodes them in its own process, where `.main` is the appex and the lookup would fall back to printing the raw key.
- **Verified on simulator:** authorization prompt, alarm arming, firing at the scheduled minute, `breaksThroughFocus: true` in the alert request, the selected `.wav` resolving from the app bundle, and the widget extension rendering `AlarmAttributes<CommuteAlarmMetadata>`.
- **Still needs a device pass before submitting:**
  - Ringing with the physical ring/silent switch off (a simulator has no switch).
  - The snooze button round-trip, and whether a 18–24s custom `.wav` loops until stopped or falls silent.
  - The snooze Live Activity showing translated text ("賴床中"), not the raw key `alarm_snoozing_title` — this is the cross-process bundle resolution above.
  - Archiving: automatic signing has to mint the extension's provisioning profile, and both version numbers must match.

## Rejection Resolution (5.2.5 — WeatherKit attribution)

- `WeatherAttributionView` fetches `WeatherService.shared.attribution` and renders the official combined dark Apple Weather mark, linked to Apple's `legalPageURL`.
- The mark sits outside the "forecast loaded" conditional so it is always visible in the Route tab weather section (the primary WeatherKit surface). Build 16 removed it from the Alarm tab by preference.
- App Review note (English) described the WeatherKit usage and where the attribution appears; a screen recording from a physical iPhone was attached to the reply.

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
- Local notification alarm scheduling implemented for iOS 17–25, incl. 5-minute follow-up rings (max 10, capped to iOS's 64-pending limit) that stop when the alarm is acknowledged while the weekly schedule stays armed. On iOS 26+ AlarmKit replaces this path entirely (see AlarmKit Setup); scheduling through AlarmKit also clears any notification requests an upgraded install still has armed, so it cannot ring twice.
- Public-transit commute mode shows home/work pins plus `calculateETA` travel time and distance (MapKit cannot route transit geometry).
- Taiwan address validation generalized (postal-romanization table + dynamic Han→Latin transliteration, house-number and wrong-city guards).
- Address search results follow the language the user typed (Chinese input → Chinese results, English input → English results).
- App Privacy answers completed in App Store Connect (see Rejection Resolution).
- App Review notes and contact info filled in App Store Connect.
- App Store screenshots uploaded (3 iPhone 6.5" screenshots).
- App Store metadata draft is in `docs/appstore-metadata.md`.
- Source pushed to `origin/main` (commits `69155da`, `e12bacf`).

## AdMob Setup

The app serves one inline adaptive banner, forced non-personalized (`npa=1`).

| Item | Value |
| --- | --- |
| AdMob app ID (`GADApplicationIdentifier`) | `ca-app-pub-2920259088304022~6773413597` |
| Banner ad unit (`AppEnvironment.adMobBannerAdUnitID`) | `ca-app-pub-2920259088304022/7372515130` |

- **Link the app to its App Store listing in AdMob.** Google only reviews and approves an app once it is listed in a supported store and linked in the AdMob account; unlinked apps get limited ad serving, so revenue stays near zero until this is done. Do it now that `1.6.1 (16)` is live, then wait for AdMob's review.
- Confirm the AdMob payments and tax profile is complete, otherwise earnings are withheld even past the payout threshold.
- `SKAdNetworkItems` is declared as of `1.6.2 (17)` — see the AdMob third-party SKAdNetwork list and refresh it occasionally, as Google adds buyers.
- **EEA consent (UMP) is implemented as of `1.6.2 (17)`.** A GDPR "European regulations" message is published in AdMob (targeted at EEA/UK/Switzerland only, with the "Do not consent" option and close icon enabled, Google's default ad-partner list, and the GitHub Pages privacy policy URL). `ConsentManager` runs the flow and the Mobile Ads SDK only starts once `canRequestAds` is true. To rehearse the regulated-region path from a non-EEA simulator, launch a Debug build with `-forceEEAConsentGeography`:

  ```bash
  xcrun simctl launch booted com.shukaihu.RainyClock -forceEEAConsentGeography
  ```

- Changes to the AdMob message take up to an hour to reach devices, so treat "the form did not appear" as a propagation question before treating it as a bug.

### app-ads.txt

AdMob reported "we can't verify Rainy Clock (iOS)" for two independent reasons: the App Store listing had **no marketing URL** (`itunes.apple.com/lookup` returned `sellerUrl: null`, so Google had no domain to crawl), and no `app-ads.txt` existed at any domain root.

| Item | Value |
| --- | --- |
| Developer website domain | `shukaihu.github.io` |
| app-ads.txt | `https://shukaihu.github.io/app-ads.txt` |
| Hosting repo | [`ShuKaiHu/ShuKaiHu.github.io`](https://github.com/ShuKaiHu/ShuKaiHu.github.io) (public, Pages from `main` `/`) |
| Line served | `google.com, pub-2920259088304022, DIRECT, f08c47fec0942fa0` |

- The file **must** sit at the domain root. Google takes the domain from the store listing's developer website and discards the path, so `shukaihu.github.io/RainyClock/app-ads.txt` would never be read. GitHub Pages only serves the root from a repo named exactly `<user>.github.io`, which is why the developer site lives in its own repo instead of in `docs/` here.
- `shukaihu.com` was deliberately **not** used. It is on Cloudflare with Google Workspace MX records and a dead origin (522); pointing it at Pages would have meant DNS surgery for no benefit, and the domain root would have had to host the publisher line.
- **This repo must stay public.** Its Pages site at `shukaihu.github.io/RainyClock/` serves the support and privacy-policy URLs on the live App Store listing; GitHub Pages from a private repo requires GitHub Pro. Making it private would 404 those links.
- Marketing URL: `https://shukaihu.github.io/RainyClock/`, added on the `1.6.2` version page. It is a version-level field, so it only reached the public product page when `1.6.2` was released on 2026-07-27; before that `itunes.apple.com/lookup` kept returning `sellerUrl: null` and AdMob could not pass. Support and privacy-policy URLs were unaffected and needed no change.
- **Verified 2026-07-27**, within hours of `1.6.2` going live — AdMob's app settings now show 應用程式驗證「已驗證」 and 核准狀態「就緒」. The expected 24-hour-to-several-day re-crawl did not materialise.

  ```bash
  curl -s "https://itunes.apple.com/lookup?id=6780500386" | grep -o '"sellerUrl":"[^"]*"'
  ```

- One publisher line covers every app under `pub-2920259088304022`; future apps need no new file.
- Google re-crawls store listings on its own schedule. Expect 24 hours to several days after the marketing URL goes live before "Check for updates" in AdMob passes — though in practice it passed within hours.

### Debug builds use a test ad unit (`1.6.4`)

`AppEnvironment.adMobBannerAdUnitID` returns Google's test banner unit
(`ca-app-pub-3940256099942544/2934735716`) under `#if DEBUG` and the production unit otherwise.
Google requires test ads during development; requesting production ads from simulators counts
as invalid traffic and enough of it puts the AdMob account at risk. Before this change every
run from Xcode hit the production unit.

### Reading the AdMob report when no ads appear

A banner that fails to load renders at height 0 with opacity 0 (`AdMobBannerView`), so "no ad
on screen" and "ad failed" look identical. Do not diagnose by launching the app repeatedly —
read the report:

| Requests | Impressions | Meaning |
| --- | --- | --- |
| > 0 | 0 | Integration works; Google has no ad to return. Wait. |
| 0 | 0 | Something is broken in the app or the SDK never started. |

Observed 2026-07-28: 168 requests, 0 impressions, 0.00% match rate. Confirmed to be the first
row, not a fault — swapping in the test ad unit produced a banner immediately, and the log
showed the UMP call to `fundingchoicesmessages.google.com/a/consent` followed by ad requests to
`googleads.g.doubleclick.net/mads/gma`. Nearly all of those requests came from simulators, and
AdMob does not serve production ads to simulators.

The 使用者指標 / user metrics panel in AdMob shows zeros because the app integrates no Firebase
or Google Analytics SDK. It is not a signal about real usage; App Store Connect's 分析 tab is.

## Archiving and Uploading

```bash
xcodebuild -project RainyClock.xcodeproj -scheme RainyClock -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/RainyClock-<version>-<build>.xcarchive -allowProvisioningUpdates archive
```

- `xcodebuild -exportArchive` with `build/ExportOptions-AppStoreUpload.plist` uploads straight to App Store Connect, but it needs an Apple Account signed in under Xcode → Settings → Accounts. Without one it fails with `Failed to Use Accounts` / "Failed to find an account with App Store Connect access for team MQJ88U9NAJ", and the local keychain holds only Apple Development certificates — the Apple Distribution certificate is created during export.
- The account grant lapsed after the Xcode 26.6 upgrade for `1.6.2 (17)`. The fallback that works without CLI credentials is `open -a Xcode build/<archive>.xcarchive`, then Distribute App → App Store Connect → Upload in Organizer, leaving **Manage Version and Build Number** unchecked so Xcode does not bump the build number.

## After Release

- Watch App Analytics and Crashes (Xcode Organizer) for the first real-user data; note that Google SDK frames symbolicate poorly (missing dSYMs).
- Keep `docs/appstore-metadata.md` and the screenshots in sync with the next feature release.

## Known Review / QA Risks

- iOS local notifications can only play short bundled notification sounds; this app is not a full-screen system alarm replacement.
- Apple Maps / Apple's Taiwan geocoder can mis-resolve some queries. Notably the English POI phrase "Taipei Main Station" mis-geocodes to Maan / Wulai District in both CLGeocoder and MKLocalSearch; the app's address-validation layer correctly rejects the mismatch (shows "address not found") rather than pinning the wrong location, and the autocomplete-dropdown path resolves it correctly. When Apple returns a nearby suggested location, the app shows the actual address in use for confirmation.
- Google Places fallback requires a valid API key before enabling; `GooglePlacesAPIKey` is currently empty in `RainyClock/Info.plist`, so the app relies on Apple geocoding.
- Xcode upload warns about missing dSYM files for Google SDK frameworks (GoogleMobileAds, UserMessagingPlatform). This does not block upload; only Google SDK crash symbolication is limited.

## Useful URLs

- Support: `https://shukaihu.github.io/RainyClock/support.html`
- Privacy Policy: `https://shukaihu.github.io/RainyClock/privacy-policy.html`
- Repository: `https://github.com/ShuKaiHu/RainyClock`
