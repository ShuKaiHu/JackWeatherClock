# Rainy Clock — Status & Backlog

Living handoff document. Read this first when picking the project back up; update it when
something ships, gets blocked, or gets discovered. Detail lives in the other docs — this
file is the index and the "where were we?".

- Submission mechanics, rejection history, AdMob setup → `docs/app-store-submission-checklist.md`
- Store copy, release notes, review notes → `docs/appstore-metadata.md`
- Product reasoning and rejected alternatives → `docs/PRODUCT_DECISIONS.md`
- Android port architecture and platform substitutions → `docs/ANDROID.md`
- Play Store submission runbook → `docs/play-store-submission-checklist.md`

Last updated: 2026-08-09.

## Where things stand

| | Version | State |
| --- | --- | --- |
| Live on the App Store | `1.6.3 (18)` | Approved and released 2026-07-28 |
| Rejected | `1.6.4 (19)` | Rejected 2026-08-01 on 5.1.2(i) and 2.1(a) |
| **Waiting to upload** | `1.6.5 (23)` | Builds 20 (invalidated), 21 and 22 superseded before upload; **`build/RainyClock-1.6.5-23.xcarchive` is the one to upload** |
| **In development** | `1.6.6 (24)` | Version numbers bumped 2026-08-09; on-route rain sampling and the Dynamic Type fix. Holds until 1.6.5 clears review |

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
      the build changes. **Upload the existing `build/RainyClock-1.6.5-23.xcarchive`** — source
      moved on to `1.6.6 (24)` on 2026-08-09, so a fresh archive would no longer be build 23.
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

## 1.6.6 (24) — next iOS version, holds until 1.6.5 clears review

**Version numbers bumped 2026-08-09** to `1.6.6` / build `24`, in `Info.plist` *and* the
project file, verified in a Debug build: app and `RainyClockAlarmWidget.appex` both report
`1.6.6 (24)`. **`build/RainyClock-1.6.5-23.xcarchive` is unaffected and is still the archive
to upload for the pending 1.6.5 submission** — it was archived before the bump. Only rebuild
build 23 from source if you first put the version numbers back.

**On-route rain sampling** landed in `MapKitRouteWeatherService` 2026-08-08: the rain check
now covers interior points along the MKDirections route (midpoint from 4 km, quarter points
from 20 km) in addition to home and office — any of them over the threshold pulls the alarm
earlier. Transit and any route failure degrade to the endpoint-only check. The distance
rules and the sampler match the Android `RouteSampler` exactly; the degenerate cases that
trapped the deleted `RoutePolylineSampler` are covered in `WeatherSampleMapperTests.swift`
(`RoutePolylineSamplerTests`). Decision recorded in `PRODUCT_DECISIONS.md`.

Note the behaviour change in the release notes when this version goes out. Written on a Linux
container without Xcode, so the code needed a compile check before archiving — **done
2026-08-09 on the Mac**: `xcodebuild test` against an iPhone 17 Pro simulator, 57 tests passed
and none failed, the six `RoutePolylineSamplerTests` among them. Re-run after the Dynamic Type
work below landed, so that count covers both.

**The extra sample points broke the card row, fixed 2026-08-09.** The Route tab laid the
weather cards out in a plain `HStack` written when there were only ever two of them. Rendered
on an iPhone 16e simulator against a stubbed snapshot (the real path needs addresses, network
and a signed WeatherKit build), the sample counts the sampler can actually produce look like
this:

| Segments | Commute | Before | After |
| --- | --- | --- | --- |
| 2 | < 4 km, transit, route failure | fine | unchanged |
| 3 | 4–20 km | fine at standard sizes | unchanged; wraps 2+1 at accessibility sizes |
| 5 | ≥ 20 km | **row wider than the screen** — first and last card clipped at the bezel, the page lost its 20pt margins, titles broke to "Com-/mute s…" | wraps 3+2 |

`RouteWeatherGrid` now wraps at three cards per row (two at accessibility sizes), and the
card's condition line went `lineLimit(1)` → `2`, which is what truncated "62% 降雨機率" to
"62…" at accessibility sizes even with only three cards. A ≥20 km commute is ordinary here —
Taipei to Hsinchu hits it — so this was a real user-facing break, not a corner case.

**Five cards then became a W** (2026-08-09): stops 1, 3, 5 on the top row, stops 2 and 4
dropped onto a lower row nesting in the gaps between them. A plain 3+2 grid reads wrong —
the fourth stop starts a new row at the far left, *behind* the second one — whereas the W
keeps every card further right than the one before it, so the block reads home → office left
to right. Geometry: the lower row is simply centred, which lands each card exactly half a
card plus half a gap off the row above; the width comes from a `GeometryReader` in the top
row's background. Only odd counts stagger (an even count fills the lower row completely and
leaves no gap to nest into), and only below accessibility sizes.

Shortening the labels was considered first and **measured, not assumed**: with
"中點1/2/3" and the old `HStack` the row still overflowed by 40pt. A card cannot go below
~70pt wide whatever the title says — the weather glyph is a hardcoded 42pt, the condition
line needs ~60pt at its minimum scale, and "住家附近"/"公司附近" are not shortenable. Five of
those plus spacing is 390pt against 350pt of usable width.

**The card labels were rewritten** the same day. The endpoints lost their qualifier in both
languages — `segment_home_area` and `segment_office_area` now read "Home" / "Office" and
住家 / 公司, not "Home area" / 住家附近. (The keys still say `_area`; the addresses above them
still say 住家 / 工作, so the card and the field it comes from differ by a word in Chinese.)
The interior samples stopped being "通勤途中取樣 N" / "Commute sample N"
and now say where they are: **路程 ¼ / ½ / ¾**, **¼ way / Halfway / ¾ way**. A short commute
samples one point and it is the true midpoint, so it reads 路程 ½ / Halfway.

**The card text now shares baselines across the row.** Each card centres a title / icon /
rain-figure stack, so a one-line "Cloudy" made a shorter stack than a two-line "62%
precipitation" beside it and centring dropped that card's title below its neighbours'. Each
card now lays every peer's title and rain figure out behind its own with `.hidden()`, so all
of them reserve the tallest card's height for each line and the three tiers line up. This
beats reserving a fixed two lines: nothing is padded when the row happens to be all
one-liners, and it holds in any language and at any text size without measuring text.

"中點1/2/3" was rejected for this: at ≥20 km the three points sit at 1/4, 1/2 and 3/4, so
two of the three are not the midpoint and the label would mislead. `interiorSegmentName`
therefore derives the fraction from the position — sample `index` of `total` sits at
`(index + 1) / (total + 1)` — rather than hardcoding three names. That only holds while the
sampler spaces its points evenly, so `RoutePolylineSampler.interiorSampleFractions` is now a
separate function and `testSampleFractionsAreEvenlySpacedSoTheNamesStayTrue` fails if a
future fraction list breaks the assumption. **The Android strings still say the old thing**
and are untouched here.

**Dynamic Type no longer truncates the controls** (2026-08-09). Reported from a real user:
on an iPhone with an enlarged system font the weekday circles all read "…". Three controls
sized text into a fixed box and truncated once the text style scaled past xxxLarge:

- the seven weekday chips (~34pt wide each on a 6.1" phone) — now wrap to **four per row**
  at accessibility sizes, and the circle grows with the text (`@ScaledMetric`, capped at 76pt);
- the four `RouteModePicker` pills — now **two columns** at accessibility sizes, with the
  "Mode" label moved onto its own line (`AnyLayout` switching `HStack`→`VStack`);
- the route weather card titles — `lineLimit(1)` → `2`, centred.

`minimumScaleFactor` alone was not enough, and is the reason both rows then looked ragged:
it shrinks each label independently to fit its own box, so "Fri" stayed full size next to a
shrunken "Wed", and `大眾交通` came out visibly smaller than `開車`. `RowLabelFont.fittedSize`
measures the widest label in the row with `UIFont` and gives every label in that row the same
size; a `GeometryReader` supplies the row width, which is free here because both grids have a
computed height. `minimumScaleFactor` stays as a fallback for the first layout pass.

Deliberately *not* fixed by pinning the font size or swapping in images: both would leave the
people who enlarged the font unable to read the control, and images cannot localize. Nothing
below xxxLarge changes shape. Verified on an iPhone 16e simulator via
`xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`, in English and
zh-Hant. **The Android `WeekdaySelector` has the same defect** — a fixed `Modifier.size(40.dp)`
circle — and is untouched here.

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
fields, iOS dark-mode system blue `#0A84FF`, dark-only like iOS. The route-weather segments
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
- [ ] **(you) Cap the Routes API quota** (API & Services → Routes API → Quotas). Structural,
      not advisory: a capped quota makes the bill $0 even if the key leaks or a bug loops.
- [ ] **(you) Disable the ~30 Maps APIs the console enabled by default.** The app calls two.
      Route Optimization, Navigation SDK and Places are expensive; every one left enabled is
      reachable with a leaked key.

**2. The one product decision still blocking a release**

- [ ] **(you) Weather-provider licensing.** Open-Meteo's keyless tier is **non-commercial**
      and this app carries ads. Three options in `docs/ANDROID.md`: buy their commercial
      plan, swap the provider behind `WeatherSamplingService`, or ship the first release
      ad-free. **Shipping ads on the free tier is not one of them.** Everything else below
      can proceed in parallel; this one gates going live.

**3. Accounts and assets that take calendar time**

- [ ] **(you) Play Developer account** (US$25). If it registers as a *personal* account, the
      **12-testers-for-14-days closed test** applies — that is the longest pole in the whole
      schedule, so open the account early even if the build is not final.
- [ ] **(you) Upload keystore**, generated once and backed up outside the repo, with Play App
      Signing opted in at first upload. Its SHA-1 (and Play's) then go into the Maps key.
- [ ] **(you) AdMob: register a new Android app** and one anchored adaptive banner unit; pass
      both as Gradle properties at build time. `app-ads.txt` needs no change — it is
      per-account and already verified.

**4. Content and code left to write**

- [ ] `docs/privacy-policy.html` needs an **Android paragraph** before it can be the Play
      privacy-policy URL — it currently describes ATT, which does not exist on Android.
      The page ships from this repo, so it only counts once pushed.
- [ ] **Android screenshots** for the listing. `pics/20260729/` is iPhone-framed and the
      Android UI genuinely differs; retake on the emulator. The dark/blue restyle means the
      old shots are wrong twice over.
- [ ] Feature graphic 1024×500 and a 512×512 icon.
- [ ] **`WeekdaySelector` truncates at large font scales** — a fixed `Modifier.size(40.dp)`
      circle, the same defect fixed on iOS on 2026-08-09 and still open here.
- [ ] Commit and merge the work sitting uncommitted on
      `claude/android-play-store-release-jykw59` (PR #2 is still a draft).

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
