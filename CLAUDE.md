# Rainy Clock

Rain-aware commute alarm. No backend. The iPhone app (repo root) is SwiftUI with Apple Maps
for routes, Apple Weather / WeatherKit for forecasts, AlarmKit for alarms on iOS 26+, and one
Google AdMob banner. The Android port lives in `android/` (Kotlin + Jetpack Compose) —
platform substitutions and its own gotchas are in `docs/ANDROID.md`, and the Play Store
runbook is `docs/play-store-submission-checklist.md`.

## One worktree per platform

The two platforms are worked on at the same time, so each has its own git worktree and its
own branch. Same repository and same history — two checkouts of it:

| Platform | Directory | Branch |
| --- | --- | --- |
| iOS | `Jack_Waether_Clock_MM/` | `ios/main` |
| Android | `RainyClock-Android/` (this one) | `claude/android-play-store-release-jykw59` |

**Work on the platform whose worktree you are in, and commit to its branch.** Both checkouts
contain the whole repo — a worktree splits branches, not directories — so nothing stops you
editing `android/` from the iOS worktree. Don't: that is the collision this arrangement
exists to end, after a day of iOS commits kept sweeping up the Android session's edits to
shared files.

**The other platform's files cannot be hidden**, so this rule is kept by hand rather than by
tooling: sparse-checkout would take `RainyClock/*.wav` out of the Android worktree, and the
Android build copies those alarm tones out of the iOS target at build time. Hide them and the
build stops working.

A session that finds itself in the wrong worktree has lost nothing — work lives in the branch,
not the directory. Confirm with `git branch -a --contains <sha>` before assuming otherwise:
right after a split both worktrees sit on the *same* commit, which looks like the branch was
reset when in fact every commit is still an ancestor of both tips.

Shared files (`docs/`, `CLAUDE.md`, `.gitignore`) drift between the two branches. Merge in the
direction of whoever needs the change; both branches are meant to land on `main` eventually.

`git worktree list` shows the current layout. Android's `android/local.properties` is
gitignored, so a newly created worktree needs it written by hand — see `docs/ANDROID.md`.

## Read first

The two platforms keep **separate logs** — they ship on different schedules and are often
worked on at the same time, so never write one platform's state into the other's file:

- **`docs/STATUS-IOS.md`** — the iPhone app: what shipped, what is in review, what is being
  worked on, and the iOS backlog.
- **`docs/STATUS-ANDROID.md`** — the Android port and everything still owed before a first
  Play release.
- **`docs/STATUS.md`** — a one-page router: which platform is where, plus the handful of facts
  that are true of both.

Start with the log for the platform you are touching, and update it when state changes.

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

iOS:

```bash
xcodebuild -project RainyClock.xcodeproj -scheme RainyClock -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build
```

Android (requires the Android SDK; CI runs this on every push touching `android/`):

```bash
cd android && ./gradlew testDebugUnitTest assembleDebug
```
