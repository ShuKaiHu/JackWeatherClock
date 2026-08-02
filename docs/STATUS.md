# Rainy Clock — Status & Backlog

Living handoff document. Read this first when picking the project back up; update it when
something ships, gets blocked, or gets discovered. Detail lives in the other docs — this
file is the index and the "where were we?".

- Submission mechanics, rejection history, AdMob setup → `docs/app-store-submission-checklist.md`
- Store copy, release notes, review notes → `docs/appstore-metadata.md`
- Product reasoning and rejected alternatives → `docs/PRODUCT_DECISIONS.md`

Last updated: 2026-08-02.

## Where things stand

| | Version | State |
| --- | --- | --- |
| Live on the App Store | `1.6.3 (18)` | Approved and released 2026-07-28 |
| Rejected | `1.6.4 (19)` | Rejected 2026-08-01 on 5.1.2(i) and 2.1(a) |
| **In development** | `1.6.5 (22)` | Build 20 invalidated (ITMS-91064), 21 superseded by the audit fixes; 22 is archived and waiting to upload |

`1.6.3` is the AlarmKit release: alarms pierce silent mode and Focus on iOS 26+, snooze with
a 1–15 minute interval, and the first shipped `RainyClockAlarmWidget` extension. It cleared
review on the first attempt, so AlarmKit's `NSAlarmKitUsageDescription` prompt and the new
widget extension are both proven acceptable to App Review — nothing extra was asked for.

Apple offered to approve `1.6.4` as a bug-fix submission if asked; we chose to fix both
findings and resubmit as `1.6.5` instead. The resubmission also carries the English (U.S.)
localization added for `1.6.4` — that metadata has still never been through review, since
`1.6.4` never shipped.

## The 1.6.4 rejection

Reviewed on an **iPad Air 11-inch (M3), iPadOS 26.6** — worth remembering, it explains the
second finding entirely.

**5.1.2(i) — tracking without ATT.** The AdMob-hosted GDPR message asks for consent to
"personalised advertising and content"; App Review reads that as a declaration that the app
tracks, and there was no ATT prompt behind it. The app itself never used that consent —
`npa=1` was hardcoded since the `1.5 (7)` rejection — so the message and the code disagreed.
Fixed by implementing ATT and actually honouring it. Full reasoning, and the manual App Store
Connect steps this creates, are in `docs/app-store-submission-checklist.md`.

**2.1(a) — "unable to add Widgets at the Home Screen."** Not a defect, answered by reply. The
app ships no Home Screen widget at all: the widget extension holds only the AlarmKit Live
Activity, which is why it exists. And on an iPad the app runs in iPhone compatibility mode,
where iOS offers no third-party widgets whatever the app contains.

## Monetization: unblocked, waiting on traffic

AdMob's app-ads.txt verification passed on 2026-07-27 and the app's approval status is 就緒
(Ready). Nothing is left to configure. What the AdMob report showed the next day:

| Metric | Value | Reading |
| --- | --- | --- |
| Requests | 168 | The integration works — requests reach Google |
| Impressions | 0 | Google returned no ad, 168 times |
| Match rate | 0.00% | Same thing stated as a rate |
| Revenue | US$0.00 | Expected at this stage |

Verified on 2026-07-28 that this is **not** a code fault: swapping in Google's test ad unit
made a banner appear immediately, and the log showed the UMP consent call to
`fundingchoicesmessages.google.com/a/consent` followed by ad requests to
`googleads.g.doubleclick.net/mads/gma`. Zero fill is explained by the requests coming almost
entirely from simulators (AdMob does not serve production ads to simulators and filters that
traffic) plus a newly verified app with no install base.

Do not diagnose this by opening the app repeatedly — a failed load renders at height 0 and
looks identical to no ad, and self-requests against the production unit look like invalid
traffic. Read the AdMob report instead: requests > 0 with impressions 0 means "wait", and
requests == 0 means "something broke".

The 使用者指標 / user metrics panel in AdMob reads all zeros because the app has no Firebase
or Google Analytics SDK. It is not a signal. Real download numbers are in App Store Connect
under 分析 / Analytics.

## 1.6.5 — in development

Everything `1.6.4` contained, plus the rejection fixes. Version numbers already bumped in both
places (`Info.plist` → `1.6.5 (20)`, project file → `MARKETING_VERSION 1.6.5` /
`CURRENT_PROJECT_VERSION 20`).

- [x] ATT prompt implemented in `ConsentManager`, fired after the UMP form, honoured by
      `AdMobBannerView` (personalized request only when granted). `NSUserTrackingUsageDescription`
      added in `Info.plist` and both `InfoPlist.strings`; `PrivacyInfo.xcprivacy` now declares
      `NSPrivacyTracking = true`. Builds clean, tests pass.
- [x] Verified on an iPhone 17 simulator 2026-08-02: the prompt appears on first launch right
      after the consent flow, granting writes `kTCCServiceUserTracking = 2` to the simulator's
      TCC database, and the banner then loads through the personalized (no `npa`) request.
      Worth re-checking after any change to the launch sequence — a prompt requested while the
      app is inactive is silently denied forever.
- [x] App Privacy in App Store Connect changed to declare tracking 2026-08-02: Device ID,
      Advertising Data, Product Interaction and Coarse Location answer "yes" to the tracking
      question; crash and performance data stay "no". This was the manual half of the 5.1.2(i)
      fix — the code change alone does not resolve the rejection.
- [x] `build/RainyClock-1.6.5-20.xcarchive` created and verified: app and extension both at
      `1.6.5 (20)`, ATT string present, `NSPrivacyTracking = true`.
- [x] Build 20 uploaded, the rejected `1.6.4` version renamed to `1.6.5` with the build
      attached, release notes and review note pasted, the rejection message answered in
      Resolution Center, and the whole thing submitted 2026-08-02. Copy used is in
      `docs/appstore-metadata.md`.
- [x] **Build 20 was then invalidated by ITMS-91064** — `NSPrivacyTracking = true` with an
      empty `NSPrivacyTrackingDomains` is not a valid combination, and filling the list would
      have blocked AdMob's endpoint for everyone who declines the prompt. Manifest reverted to
      `false`, `build/RainyClock-1.6.5-21.xcarchive` built and verified. Details in
      `docs/app-store-submission-checklist.md`.
- [x] **Pre-submission audit, 2026-08-02.** Six review dimensions, each adversarially verified.
      What it caught and what was fixed is in the section below; the archive is now
      `build/RainyClock-1.6.5-22.xcarchive` (21 was superseded before it was ever uploaded).
- [ ] Upload build 22, attach it to the 1.6.5 version, and resubmit. The release notes, review
      note and Resolution Center reply are already in place from the build-20 attempt — only
      the build changes. **The website fixes must be pushed and live before resubmitting** —
      App Review opens the privacy-policy URL.
- [ ] Wait for the verdict.

## Pre-submission audit — what it found

The audit that ran before build 22 turned up one thing that would very likely have caused a
third 5.1.2(i) rejection, and two real bugs. Fixed:

1. **The live privacy policy said the app does not track you.** `docs/privacy-policy.html`
   listed "Track you across apps or websites" under *Data We Do Not Collect*, in both
   languages, while the app now shows an ATT prompt and the App Store Connect label declares
   tracking. That page is linked from the listing and from the AdMob consent form, so App
   Review reads it. Rewritten with a Tracking section that describes the ATT choice honestly.
   **This repo's `docs/` is the published site — the fix only counts once it is pushed.**
2. **The support page said the alarm cannot ring through silent mode.** Stale since `1.6.3`
   shipped AlarmKit, and directly contradicted by the store description. Rewritten, with a
   second entry covering the upgrade case where an old alarm still uses the notification path.
3. **A failed registration still looked like a scheduled alarm.** `AlarmViewModel` published
   and persisted `scheduledAlarmSummary` *before* `scheduleAlarm` could throw, while the error
   message lived only in memory — so the next launch showed the green "alarm scheduled" state
   for an alarm the system had never accepted. For an alarm app that is a missed alarm. The
   assignment now happens only after registration succeeds.
4. **Withdrawing ad consent did nothing.** `refreshConsentState()` could only ever latch
   `canRequestAds` to true, and the banner's `BannerView` is configured once in `makeUIView`,
   so a user who revoked consent through the privacy options form kept seeing ads until they
   relaunched — the opposite of what that form promises. The flag is two-way now, and
   `adConfigurationRevision` rebuilds the banner whenever an answer that shapes the ad request
   changes (which also fixes a late ATT grant never reaching the current session).
5. **The rain decision was frozen at scheduling time.** Both paths register a *weekly
   repeating* alarm at whatever time the rain check produced, so an alarm armed on a rainy day
   kept ringing early every week and one armed on a dry day never moved — against the intended
   behaviour recorded in `PRODUCT_DECISIONS.md`. Opening the app now re-decides an armed alarm
   whenever its rain check is older than four hours
   (`refreshScheduledAlarmIfWeatherIsStale()`), silently, keeping the previous status line if
   the refresh fails. Three regression tests cover 3 and 5.

**Still open from the audit** (none block this submission): the app cannot re-check the weather
while it is closed, so the fix above only covers users who open it — closing that gap needs a
`BGAppRefreshTask` and a background-mode declaration, which is a change worth making *after*
1.6.5 clears review rather than during it. Smaller items: Release builds on the Simulator still
request the production ad unit, the alarm sound preview sets no `AVAudioSession` so it is silent
under the ring switch, `RoutePolylineSampler` is dead production code containing a NaN-to-Int
trap, the store screenshots predate the 1.6.4 interface redesign, and the English (U.S.) listing
carries only the Traditional Chinese screenshots. If 2.1(a) comes back a second time, the appeal did not land and
      the options narrow to shipping a real Home Screen widget (iPhone only — still invisible
      on an iPad reviewer's device) or adding full iPad support.
- [ ] Optional, no longer blocking: check whether AdMob → Privacy & messaging lets the GDPR
      message drop its personalization purposes. Only worth acting on if the no-tracking
      posture is wanted back — it would mean reversing the privacy label a second time.

## 1.6.4 — rejected 2026-08-01

- [x] Debug builds use Google's test banner unit (`ca-app-pub-3940256099942544/2934735716`)
      via `#if DEBUG` in `RainyClock/AppEnvironment.swift`, so development traffic never hits
      the production unit again.
- [x] Alarm-tab weekday selector redesigned: selected days are filled blue circles with white
      text, unselected days plain dim text (no visible chip). All interface accents unified on
      the system blue — the cyan tints on the sound-preview button, Snooze toggle, Schedule
      button, ad-privacy button, and the Route tab's transport-mode chips are gone. Weather
      condition colors (yellow/cyan/blue on forecast icons) intentionally kept as-is.
- [x] Build 19 uploaded to App Store Connect 2026-07-29 (CLI export failed with the usual
      `Failed to Use Accounts`; Organizer upload worked, two known Google-SDK dSYM warnings).
- [x] English (U.S.) localization added to the listing — store name `Rainy Clock: Rain Alarm`
      ("Rainy Clock" and "RainyClock" are taken by other accounts). Done via the iris API from
      the browser session because the ASC UI hides the name-conflict error; details in
      `docs/appstore-metadata.md`.
- [x] New store screenshots uploaded by hand (source images in `pics/20260729/`).
- [x] Submitted 2026-07-29 and rejected 2026-08-01; the store metadata and screenshots uploaded
      for it stay valid for 1.6.5.

## Backlog

Ordered by value, not urgency. None of these block a release.

1. **Add the English App Store localization.** The listing has only Traditional Chinese, so
   every storefront including the US serves Chinese description, keywords, and release notes.
   The English copy is already written in `docs/appstore-metadata.md` and has never been used.
   Metadata-only change — no new build needed, but it must ride along with a version submission.
2. **Clear the "Sign-in required" checkbox in App Review Information.** It is checked with a
   demo account even though the app has no login. It has never caused a rejection, but the
   credentials sit there for no reason.
3. **Refresh `SKAdNetworkItems` occasionally.** 50 identifiers were declared in `1.6.2 (17)`;
   Google adds buyers to its list over time.
4. **Confirm the AdMob payments and tax profile is complete.** Earnings are withheld past the
   payout threshold otherwise. Worth settling before there is anything to withhold.
5. **Google Places fallback is dormant.** `GooglePlacesAPIKey` is empty in
   `RainyClock/Info.plist`, so address lookup relies entirely on Apple geocoding.
6. **Google SDK frames symbolicate poorly.** Xcode upload warns about missing dSYMs for
   `GoogleMobileAds` and `UserMessagingPlatform`. Does not block upload; only limits crash
   reports inside those frameworks.

## Environment gotchas

Things that have cost time before and will again.

- **Xcode's Apple Account grant lapses.** `xcodebuild -exportArchive` then fails with
  `Failed to Use Accounts`. The reliable path is `open -a Xcode build/<name>.xcarchive` and
  Distribute App from Organizer, leaving **Manage Version and Build Number** unchecked.
- **`find`ing the built `.app` picks up stale bundles.** `DerivedData/Build/Products/` still
  holds a `Release-iphonesimulator` build from June. Always take the explicit
  `Debug-iphonesimulator/RainyClock.app` path and confirm `CFBundleShortVersionString` before
  installing to a simulator.
- **Version numbers live in two places.** The app's `Info.plist` hardcodes them
  (`GENERATE_INFOPLIST_FILE = NO`) while `RainyClockAlarmWidget` derives them from build
  settings. Both must be bumped together or App Store validation rejects the upload.
- **The developer website is a separate repo.** `app-ads.txt`, and the domain root generally,
  are served from `ShuKaiHu/ShuKaiHu.github.io`; this repo's `docs/` folder is published at
  `shukaihu.github.io/RainyClock/`. **This repo must stay public** or the support and
  privacy-policy URLs on the live listing break.
