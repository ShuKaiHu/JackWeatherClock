# Rainy Clock App Store Submission Checklist

## Current Build

| Item | Status |
| --- | --- |
| App version | `1.6.2` (in development) |
| Build number | `17` |
| Review status | Not yet archived or submitted |
| Last released | `1.6.1 (16)` — released to the App Store 2026-07-26 |
| Bundle identifier | `com.shukaihu.RainyClock` |
| Device family | iPhone only |
| Primary language | Traditional Chinese |

## Submission History

- `1.5 (7)` — **Rejected** 2026-07-22, Guideline 5.1.2(i) (Privacy – Data Use and Sharing): the App Privacy label declared data used to track the user, but the app has no App Tracking Transparency prompt.
- `1.6 (10)` — Resubmitted 2026-07-23 with the 5.1.2(i) fix below. **Rejected** 2026-07-24, Guideline 5.2.5 (Legal – Apple Sites and Services): WeatherKit data shown without the required Apple Weather attribution mark and legal link.
- `1.6.1 (16)` — Submitted 2026-07-25 with the 5.2.5 fix (official Apple Weather mark + legal link in the Route tab weather section), a review note explaining WeatherKit usage, and a screen recording captured on a physical iPhone. **Approved 2026-07-26 and released to the App Store the same day.**
- `1.6.2 (17)` — In development. Declares Google's `SKAdNetworkItems` list (50 identifiers) in `Info.plist`, which the shipped builds were missing, and adds the UMP consent flow for EEA/UK/Swiss users.

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
- Local notification alarm scheduling implemented, incl. 5-minute follow-up rings (max 10, capped to iOS's 64-pending limit) that stop when the alarm is acknowledged while the weekly schedule stays armed.
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
- Marketing URL to set in App Store Connect: `https://shukaihu.github.io/RainyClock/`. It is a version-level field, so if the live version's copy is locked it ships with the next submission. Support and privacy-policy URLs are unaffected and need no change.
- One publisher line covers every app under `pub-2920259088304022`; future apps need no new file.
- Google re-crawls store listings on its own schedule. Expect 24 hours to several days after the marketing URL goes live before "Check for updates" in AdMob passes.

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
