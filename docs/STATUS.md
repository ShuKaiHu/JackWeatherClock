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
| **In development** | `1.6.5 (23)` | Builds 20 (invalidated), 21 and 22 superseded before upload; **23 is the one to upload** |

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
- [x] Website fixes pushed 2026-08-03 and verified live: `privacy-policy.html` serves the new
      Tracking section, the old "Track you across apps or websites" line is gone, and
      `support.html` describes the AlarmKit behaviour.
- [x] Second cleanup pass, 2026-08-03 — the audit's smaller findings, listed below.
- [ ] Upload build 23, attach it to the 1.6.5 version, and resubmit. The release notes, review
      note and Resolution Center reply are already in place from the build-20 attempt — only
      the build changes.
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

6. **The rain check now runs while the app is closed.** Item 5 only covered users who open the
   app, which is not the product: an alarm set for Mon/Tue/Wed has to be decided by *each*
   morning's forecast. `BackgroundWeatherRefresh` registers two `BGTaskScheduler` budgets and
   re-asks for them after every successful scheduling — a `BGAppRefreshTask` aimed 45 minutes
   before the next lead-time point, and a `BGProcessingTask` aimed the evening before, which is
   the window iOS grants most readily because the phone is usually idle and charging. Whichever
   runs first re-decides that morning's alarm and re-arms the next pair. `Info.plist` now
   declares `UIBackgroundModes` (`fetch`, `processing`) and `BGTaskSchedulerPermittedIdentifiers`
   — **an identifier here that does not match the code crashes the app at launch**, so verify a
   launch after touching either.

   **iOS never guarantees background execution**, so the honest contract is three paths — the
   overnight processing task, the morning refresh task, and opening the app — and a morning
   where none of them ran still rings, on the previous decision. The alarm itself is a weekly
   repeat and never disappears; only the earlier-or-not decision can go stale. A hard guarantee
   would need silent pushes from a server, which this app deliberately does not have.

### Second cleanup pass (build 23)

- The alarm-time headline used the app's only hand-built formatter: it forced a 12-hour clock,
  so with 24-Hour Time on it read "7:00 PM" above a picker set to 19:00, and it took the
  Chinese word order from the *device* language, putting "AM" in front of English strings on a
  Simplified Chinese device. Now `date.formatted(.dateTime.hour().minute())`; the orphaned
  `alarm_am`/`alarm_pm` keys are gone from both `.strings` files.
- The sound preview set no `AVAudioSession`, so it inherited `.soloAmbient` and played nothing
  under the ring switch — in an app whose premise is piercing silent mode. Now `.playback` with
  `.duckOthers`, released with `.notifyOthersOnDeactivation`.
- The banner asked for `inlineAdaptiveBanner(maxHeight: 36)` in an anchored slot. Google
  documents inline adaptive as the scroll-view variant, and a 36pt cap excludes the standard
  50pt creative — the one untested hypothesis left for the 0.00% match rate. Now
  `currentOrientationAnchoredAdaptiveBanner`, reserving the height the creative reports.
- A failed ad load discarded its error; it logs under `#if DEBUG` now. That was the blind spot
  behind every "is the integration broken?" round-trip described above.
- A failed UMP consent update latched `hasRequestedConsent` permanently, so one networkless
  cold start cost both ads and the privacy-options row for that whole launch. The latch clears
  on error and the foreground handler retries.
- "Ad privacy options" used `try?` and showed nothing when the form had not finished loading —
  a documented no-op with no feedback. It now surfaces a localized alert.
- `AppEnvironment` gated the test ad unit on `#if DEBUG` alone, so a Release build run on a
  simulator requested production ads. Now `#if DEBUG || targetEnvironment(simulator)`.
- Deleted `RoutePolylineSampler` (nothing shipped calls it, and it traps on `Int(Double.nan)`
  at `maximumCount == 1`) and `AlarmTimeCalculator.nextAlarmDate` (only ever called by five
  tests, none of which touched the shipped entry point). The invariant those tests guarded —
  never schedule in the past — is now asserted against the function the app actually calls.

**Still open** (none block this submission): the store screenshots predate the 1.6.4 interface
redesign and the English (U.S.) listing carries only the Traditional Chinese ones; and the app
never reconciles its persisted "armed" state against AlarmKit's actual alarm list — worth doing,
but `scheduledAlarmIdentifiers()` swallows its throw, so a transient error would read as "your
alarm is gone". Propagate it first.

Also fixed in the same pass, from the audit's own list: an unbounded retry loop where a failed
re-registration and the auto-refresh reconciler spun against each other every 1.5 seconds; an
unattended refresh marking correctly typed addresses as invalid; and the ATT purpose string,
which promised "the ad at the bottom of the screen" — a banner that renders at zero height
whenever the request does not fill. If 2.1(a) comes back a second time, the appeal did not land and
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

0. **Handle the users whose background refresh can never run.** *(Raised 2026-08-03, approach
   not decided.)* `BackgroundWeatherRefresh` is what makes each morning's alarm reflect that
   morning's forecast, and it silently does nothing when **Background App Refresh is switched
   off** (Settings › General) or the phone is in **Low Power Mode**. Those users keep whatever
   decision the last foreground run made and have no way to know. The app can detect both —
   `UIApplication.shared.backgroundRefreshStatus` and `ProcessInfo.processInfo.isLowPowerModeEnabled`,
   the latter with `NSProcessInfoPowerStateDidChange` — so the open question is what to *do*
   with that, not how to know. Sketches, none chosen: a notice on the Alarm tab with a
   deep link to Settings via `UIApplication.openSettingsURLString`; a local notification the
   evening before a scheduled day asking the user to open the app once; or state it plainly in
   the UI and accept it. Whatever is chosen must not nag people who never see rain anyway.

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
