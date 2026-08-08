# Play Store Submission Checklist

Mechanics for getting `android/` onto Google Play. The App Store counterpart is
`docs/app-store-submission-checklist.md`; architecture and platform decisions are in
`docs/ANDROID.md`. Nothing here is done yet — this is the runbook.

## One-time account setup

- [ ] **Google Play Developer account** — US$25 one-time fee, at
      https://play.google.com/console/signup. Use the same Google account that owns the
      AdMob account so the Play ↔ AdMob link is trivial.
- [ ] **Know the personal-account testing rule.** Personal developer accounts created after
      November 2023 must run a **closed test with at least 12 testers for 14 days** before
      they may apply for production access. If this applies, start the closed test the same
      day the account is created — it is the long pole of the whole schedule.
- [ ] **Upload keystore.** Generate once, back it up outside the repo, never commit it:

      ```bash
      keytool -genkeypair -v -keystore rainyclock-upload.keystore \
        -alias rainyclock -keyalg RSA -keysize 2048 -validity 10000
      ```

      Wire it via `~/.gradle/gradle.properties` (`RAINYCLOCK_UPLOAD_STORE_FILE`, …) or
      Android Studio's signing UI. Opt in to **Play App Signing** at first upload so Google
      holds the release key and the upload key is replaceable if lost.

## AdMob (Android app)

- [ ] Register a **new Android app** in the existing AdMob account; note its app ID
      (`ca-app-pub-…~…`) and create one **anchored adaptive banner** unit.
- [ ] Pass both at build time — never hardcode them in the repo:
      `./gradlew bundleRelease -PadmobAppId=… -PadmobBannerAdUnitId=…`.
      Debug builds always use Google's test unit (`AppEnvironment.kt`), same rule as iOS.
- [ ] `app-ads.txt` needs **no change**: it lives at `shukaihu.github.io/app-ads.txt` and
      declares the publisher ID, which is per-account, not per-app. After the store listing
      is live, set the listing's **developer website** to `https://shukaihu.github.io` so
      AdMob's crawler can verify the Android app too, then check the verification status in
      AdMob (took a day on iOS).
- [ ] Expect **0.00% match rate at first** on the Android unit too — new app, no installs.
      Read the AdMob report (requests > 0, impressions 0 = wait), do not self-test against
      the production unit; that is the exact loop documented in `STATUS.md` for iOS.

## Google Maps Platform (route preview + on-route rain sampling)

- [ ] Create a Google Cloud project (or reuse one) and **attach a billing account** —
      required even though this app's usage stays inside the free tiers.
- [ ] Enable two APIs: **Maps SDK for Android** (map display — free on mobile) and
      **Routes API** (polyline/duration — 10k free calls/month).
- [ ] Create one API key and restrict it: Application restriction → Android apps →
      `com.shukaihu.rainyclock` + the SHA-1 of BOTH the upload cert and the Play App
      Signing cert (Play Console → Test and release → App signing shows the latter; ads and
      maps break in production if only the upload cert is listed). API restriction → the
      two APIs above.
- [ ] Set a **quota cap** on Routes API (e.g. 9,000/month) so cost is structurally $0.
- [ ] Pass the key at build time: `-PmapsApiKey=…` (or `mapsApiKey` in
      `~/.gradle/gradle.properties`). Never commit it. Without it the app still works —
      map hidden, endpoint-only rain check.

## Before the first upload

- [ ] **Weather-provider licensing decision** — Open-Meteo's keyless tier is non-commercial
      and the app carries ads. Subscribe, swap providers, or ship the first release ad-free.
      Details and options in `docs/ANDROID.md`. **Do not ship ads + free tier.**
- [ ] Version in `android/app/build.gradle.kts` (`versionCode` must increase every upload;
      `versionName` is display-only). Single source of truth — no dual-file trap like the
      iOS `Info.plist` / project-file split.
- [ ] Build the bundle: `./gradlew bundleRelease -P…` →
      `android/app/build/outputs/bundle/release/app-release.aab`.
- [ ] Smoke-test the release build on a real device (`assembleRelease`, install, schedule an
      alarm, flip the phone to silent + DND, let it ring, snooze, reboot mid-schedule and
      confirm the alarm survives).

## Play Console declarations (all required before review)

- [ ] **Privacy policy URL** — reuse `https://shukaihu.github.io/RainyClock/privacy-policy.html`
      **after updating the page**: it currently describes ATT, which does not exist on
      Android. Add an Android paragraph (UMP consent governs personalization; no ATT).
      The page ships from this repo's `docs/`, so the fix only counts once pushed.
- [ ] **Data safety form.** Truthful answers for this app: collects **approximate location?
      No** (addresses are geocoded to coordinates on-device and sent only to the weather API
      as query coordinates, not stored server-side — but the ads SDK is the real collector).
      Declare what the **Google Mobile Ads SDK** collects per Google's published data-safety
      guidance for AdMob: device identifiers (advertising ID), ad interaction data, coarse
      location derived from IP. Mark them as collected, shared with Google, for advertising.
      Keep this consistent with the privacy-policy page — the iOS 1.6.4 rejection was
      exactly a policy-vs-declaration mismatch; App Review and Play review both read the page.
- [ ] **Ads declaration** — yes, the app contains ads.
- [ ] **`USE_EXACT_ALARM` declaration.** Play policy restricts this permission to apps whose
      **core functionality is an alarm clock or timer**. In the console's permission
      declaration, state exactly that: the app is an alarm clock; exact timing is the
      product. This app qualifies squarely — but the declaration must be filed or the release
      is rejected on upload.
- [ ] **Full-screen intent** — targetSdk 35 keeps `USE_FULL_SCREEN_INTENT` auto-granted for
      alarm apps; no console declaration exists today, but the review may ask why a
      full-screen surface is used. Answer: it is the alarm's ring screen.
- [ ] **Content rating questionnaire** — no violence, no user content, no data-for-minors;
      lands at "Everyone".
- [ ] **Target API level** — targetSdk 35 satisfies the 2025/2026 requirement; nothing to do.

## Store listing

- [ ] Reuse the copy in `docs/appstore-metadata.md` (both zh-Hant and the English (U.S.)
      set — the English copy has still never shipped anywhere; Play can be its debut).
      Title ≤ 30 chars: `雨天鬧鐘 Rainy Clock` fits; check `Rainy Clock: Rain Alarm` for the
      English listing (the iOS name-conflict problem is App Store-specific; Play names are
      not unique).
- [ ] Screenshots: phone screenshots are mandatory (min 2). The `pics/20260729/` sources are
      iPhone-framed; retake on an Android emulator or device — Play rejects obviously
      wrong-platform frames and the UI genuinely differs (Material 3).
- [ ] Feature graphic 1024×500 is required for some surfaces; make one from the app icon
      artwork.
- [ ] App icon 512×512 PNG — export from `ic_launcher_foreground.xml` artwork.

## Release path

- [ ] Internal testing track first: upload the AAB, add your own account as tester, install
      via the opt-in link, verify ads show the **test** unit only if the build is debug and
      the production unit serves (or no-fills gracefully) on release.
- [ ] If the personal-account rule applies: closed test, 12+ testers, 14 days, then apply
      for production.
- [ ] Production rollout: start staged (20%) — an alarm app failure mode (silent morning) is
      severe, so watch vitals (crashes, ANRs) before 100%.
- [ ] After approval: add the Play badge/link to `docs/index.html` alongside the App Store
      link, and update `docs/STATUS.md`.

## Known review-risk areas (write the review note accordingly)

1. **Exact alarms + full-screen intent**: state plainly the app is an alarm clock; both are
   policy-permitted for exactly this category.
2. **Background location suspicion**: the app never requests any location permission — it
   geocodes typed addresses. Say so; it preempts the question.
3. **Consent flow**: UMP shows Google's own GDPR form where required; personalization is
   governed by it. The iOS listing's "personalised advertising" wording problem cannot recur
   here because there is no ATT counterpart to contradict.
