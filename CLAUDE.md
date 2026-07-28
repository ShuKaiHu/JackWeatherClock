# Rainy Clock

iPhone-only rain-aware commute alarm. SwiftUI, no backend. Apple Maps for routes, Apple
Weather / WeatherKit for forecasts, AlarmKit for alarms on iOS 26+, one Google AdMob banner.

## Read first

**`docs/STATUS.md`** — what shipped, what is in review, what is being worked on, and the
backlog. Start there, and update it when state changes.

Supporting docs:

- `docs/app-store-submission-checklist.md` — submission mechanics, rejection history, AdMob
  and app-ads.txt setup, archiving and upload gotchas.
- `docs/appstore-metadata.md` — store copy, release notes, App Review notes.
- `docs/PRODUCT_DECISIONS.md` — product reasoning, including rejected alternatives.

## Things that are easy to get wrong

- **Version numbers live in two places.** The app's `Info.plist` hardcodes
  `CFBundleShortVersionString` / `CFBundleVersion` (`GENERATE_INFOPLIST_FILE = NO`), while the
  `RainyClockAlarmWidget` extension derives them from `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` in the project file. Bump both or App Store validation rejects
  the upload.
- **The published website is a different repo.** `ShuKaiHu/ShuKaiHu.github.io` owns
  `shukaihu.github.io/` and serves `app-ads.txt`. This repo's `docs/` folder is published at
  `shukaihu.github.io/RainyClock/` and carries the support and privacy-policy pages linked
  from the live App Store listing — so **this repo must stay public**.
- **Debug builds must not request production ads.** `AppEnvironment.adMobBannerAdUnitID`
  switches to Google's test unit under `#if DEBUG`. Requesting production ads from simulators
  is invalid traffic and risks the AdMob account.
- **Confirm which `.app` you are installing.** `DerivedData/Build/Products/` holds stale
  bundles; check `CFBundleShortVersionString` before installing to a simulator.

## Build

```bash
xcodebuild -project RainyClock.xcodeproj -scheme RainyClock -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build
```
