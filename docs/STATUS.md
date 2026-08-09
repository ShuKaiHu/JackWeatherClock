# Rainy Clock — where to look

Two platforms, two logs. iOS and Android ship on different schedules and are often worked on
at the same time, so each keeps its own history, backlog and "where were we?":

- **iPhone app** → **`docs/STATUS-IOS.md`**
- **Android port** → **`docs/STATUS-ANDROID.md`**

Write platform state into its own log, never into this page. Split on 2026-08-09 after one
shared file kept collecting both platforms' edits from two sessions at once. Only facts that
are true of *both* belong here.

## Where things stand — 2026-08-09

| Platform | State |
| --- | --- |
| **iOS** | `1.6.3 (18)` live on the App Store. `1.6.5 (23)` archived and waiting to upload — that submission answers the 1.6.4 rejection. `1.6.6 (24)` settled in the working tree, held back until 1.6.5 clears review. |
| **Android** | Never shipped. The port builds, runs and matches the iOS behaviour, but a weather-provider licensing call and a Play developer account still block a first release. |

## Shared references

- Product reasoning and rejected alternatives, both platforms → `docs/PRODUCT_DECISIONS.md`
- iOS submission mechanics, rejection history, AdMob and app-ads.txt → `docs/app-store-submission-checklist.md`
- iOS store copy, release notes, review notes → `docs/appstore-metadata.md`
- Android architecture and platform substitutions → `docs/ANDROID.md`
- Play Store runbook → `docs/play-store-submission-checklist.md`

## True on both sides

- **The published website is this repo.** `docs/` is served at `shukaihu.github.io/RainyClock/`
  and carries the support and privacy-policy pages linked from the live App Store listing —
  and the privacy-policy page is what a Play listing will have to point at too. **This repo
  must stay public**, and a fix to either page only counts once it is pushed. The domain root
  and `app-ads.txt` come from a *different* repo, `ShuKaiHu/ShuKaiHu.github.io`.
- **`app-ads.txt` is per AdMob account, not per app.** It is already verified, so an Android
  app registered under the same account needs no change to it.
- **The alarm tones are shared.** Android copies the iOS target's `.wav` files at build time
  rather than duplicating them; deleting one on the iOS side breaks the Android build.
