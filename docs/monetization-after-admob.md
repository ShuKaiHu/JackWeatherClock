# Monetization after the AdMob ban (2026-08-24)

The publisher account `pub-2920259088304022` was disabled for invalid traffic on
2026-08-22 and the appeal was rejected on 2026-08-24 (case `0-8759000041641`). The terms
are final: no payment, no further participation in the publisher programme, **no new
accounts**. Incident history is in `docs/admob-invalid-traffic-appeal.md`; this file is
what to do next.

## The one hard rule

**Never open another AdSense/AdMob account** — not personally, not under a family member,
not under a company, and never by serving this app through someone else's publisher
account. It is an explicit term of the ban, Google links accounts by payee identity,
device, network and app identity, and the usual outcome is that the second account is
banned too, taking its owner down with it. There is no clever version of this.

## What the ban does *not* touch

Worth stating plainly, because the loss looks bigger than it is:

| Still fine | Why |
| --- | --- |
| Apple Developer Program, the App Store listing, `1.6.5` in the store | Apple, unrelated to Google |
| WeatherKit + the relay | Apple |
| Google Maps Platform key, project `RainyClock` (`510427696731`), billing | Google **Cloud** — a paying-customer relationship, administered separately from the AdSense publisher programme |
| A future Play Developer account | Play is a separate programme with its own registration and enforcement |
| The GitHub Pages sites | Not Google |

What is gone is exactly one thing: serving ads through any AdSense-family product (AdSense,
AdMob, AdSense for YouTube, Ad Exchange). Everything the app *does* is unaffected.

## Start from the actual numbers

The record, not optimism: **168 ad requests, 0 impressions, US$0.00** through 2026-07-28,
and still US$0.00 at the ban a month later. Zero fill was explained by simulator traffic
and a brand-new listing, but the install base is genuinely tiny.

Suppose everything had gone perfectly: a banner in Taiwan at a US$0.50–2 eCPM needs roughly
a thousand impressions to make one dollar. At this app's size that is single-digit dollars
per **year**. Against that, an ad SDK costs:

- an ATT prompt at the worst possible moment (first launch, before any value is shown),
- a privacy manifest, `SKAdNetworkItems` (currently 50 Google-supplied IDs) and App Privacy
  answers that must all agree — getting this wrong invalidated build `20` with ITMS-91064,
- ~1–2 MB of binary, plus a network SDK's crash surface,
- and a standing enforcement risk of exactly the kind that just cost this account.

Ads start to make sense somewhere around thousands of daily sessions. Rainy Clock is not
there yet. So the ranking below is by what actually serves the app, not by what recovers
the lost banner.

## Path A — ship ad-free (recommended now)

Delete the banner, ship `1.6.6`, keep the app free. The banner already renders at height 0
whenever it fails to load, so **users will not see any difference** — the layout is
unchanged. What comes out with it: the ATT prompt (a real UX win on first launch), the UMP
consent flow, ~50 `SKAdNetworkItems`, the tracking declarations, and two SPM dependencies.
The privacy policy gets simpler and more honest.

Cost: a few hours. Benefit: a cleaner app, no enforcement surface, faster review.
This is reversible — if the install base grows, an SDK can be added back deliberately.

## Path B — a tip jar or pro unlock (StoreKit 2)

If the app should earn something, in-app purchase beats ads at this scale by a wide margin:
one paying user ≈ tens of thousands of banner impressions.

- No third-party SDK, no ATT prompt, no `SKAdNetworkItems`, no CMP, no invalid-traffic risk.
- Apple takes 15% under the Small Business Program (under US$1M/yr — this qualifies).
- Shapes that fit this app: a consumable「請我喝杯咖啡」tip, or a non-consumable unlock for
  a bounded extra (more saved routes, extra alarms) — never paywalling the core alarm.
- Cost: StoreKit 2 is a few hundred lines including restore and the store-config work in
  App Store Connect. Needs a tax/banking profile with Apple, which may already exist.

## Path C — a non-Google ad network

Available, and nothing about the Google ban blocks it — other networks run their own
account systems and do not import Google's decision. Realistic candidates for an iOS
**non-gaming utility, banner format, Taiwan/HK traffic**:

| Network | Fit | Notes |
| --- | --- | --- |
| **Unity LevelPlay** (ironSource) | Good | Mediation plus its own demand; accepts non-gaming apps; free; wants a live store listing. The most common AdMob replacement. |
| **AppLovin MAX** | Good, if accepted | The strongest mediation stack; approval leans toward apps with existing volume, so a tiny app may be declined or left with thin fill. |
| **Pangle** (TikTok / ByteDance) | Good for APAC | Strong Taiwan fill, self-serve, banner supported. Chinese-owned — the privacy policy and Data-safety answers must say so. |
| **InMobi** | Reasonable | Long-standing APAC banner demand, self-serve, accepts small publishers. |
| **Liftoff Monetize** (ex-Vungle) | Marginal | Video/gaming-leaning; banners are not its strength. |
| **Appodeal** | Easiest for a solo dev | An aggregator: one SDK, many demand sources, mediation handled for you. Its AdMob source is unusable for this publisher, which removes a large slice of its demand. |
| **Start.io** (StartApp) | Fallback only | Lowest barrier to entry, correspondingly low eCPM. A floor, not a plan. |
| **Mintegral** | Use caution | Approves easily, but its SDK drew security scrutiny in 2025; do your own diligence before shipping it to users. |

Not worth pursuing here: **Meta Audience Network** (wound down for third-party apps),
**Amazon APS / PubMatic / Magnite** (gated to larger publishers), **Yandex** (wrong market).

> Verify before signing up: this list was written without web access, so approval
> thresholds, current SDK names and each network's SKAdNetwork list must be confirmed on the
> network's own documentation.

### What a swap actually costs

Every item below is per-network work, and every one of them has bitten this project before:

1. **`SKAdNetworkItems`** — replace the 50 Google-supplied IDs in `RainyClock/Info.plist`
   with the new network's published list.
2. **`PrivacyInfo.xcprivacy`** — `NSPrivacyTracking` and `NSPrivacyTrackingDomains` must
   match the new SDK's actual domains. Mismatching these is exactly what invalidated build
   `20` (ITMS-91064).
3. **App Privacy answers** in App Store Connect, re-done for the new SDK's data collection.
4. **ATT purpose string** in `Info.plist` and both `InfoPlist.strings`.
5. **A new CMP for the EEA.** This one is easy to miss: **UMP dies with the account.** The
   GDPR message is hosted in AdMob → Privacy & messaging, so with the publisher account
   disabled it can no longer be edited or served. `ConsentManager` and the
   `UserMessagingPlatform` dependency go with it; a replacement network needs its own
   consent solution before serving EEA users.
6. **`app-ads.txt`** — lives in the *other* repo (`ShuKaiHu/ShuKaiHu.github.io`), and its
   Google lines are now dead. Each network publishes its own lines to add.
7. **Remove the Google SDK** — the `swift-package-manager-google-mobile-ads` SPM package and
   `GADApplicationIdentifier` in `Info.plist`.
8. **Privacy policy** (`docs/privacy-policy.html`, both languages) — the named ad partner
   changes.

### Rules that carry over to any network

The ban reason follows the developer, not the account. Every network runs invalid-traffic
detection of the same kind, and a second ban would be worse than the first:

- **Wire the test/production unit switch before the first line of production ad code** —
  the pattern now in `AppEnvironment.swift` (Debug, simulator, and any build carrying an
  embedded provisioning profile get the test unit) is network-agnostic; port it on day one
  rather than two weeks in.
- **Register your own devices as test devices** in the new network's console before the
  first production build reaches them.
- **Never open the app to check whether ads work.** Read the network's report: requests > 0
  with impressions 0 means wait; requests == 0 means something broke.
- **Never tap your own ads**, on any device, ever.
- If a signup form asks whether you have been removed from another ad programme, answer
  honestly — a false declaration is its own grounds for termination.

## Recommendation

**Path A now, Path B when there is appetite, Path C only if the install base grows.**

Concretely: strip the ad code, ship `1.6.6` clean (it is already uploaded but not
submitted — a fresh build supersedes it), and let the app be a good free utility. Revisit
ads only when App Store Connect shows thousands of daily sessions, at which point Unity
LevelPlay or AppLovin MAX is the place to start, with the guards above in place from the
first commit.
