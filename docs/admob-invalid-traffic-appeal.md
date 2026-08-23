# AdMob account disabled — incident record and appeal (2026-08-23)

On 2026-08-23 Google disabled the publisher account `pub-2920259088304022` for
「無效流量和/或其他違反發布商政策」. The notice is the standard invalid-traffic
disablement: all ad serving stops (AdMob included), a 30-day payment hold starts, and the
only recourse is one well-prepared appeal. This file is the working record: what we know,
what caused it as far as the repo can prove, what was already fixed and when, and the
appeal draft with the blanks only the account owner can fill.

**The live app needs no emergency release.** A banner that gets no fill renders at height 0
and opacity 0 (`AdMobBannerView`), so users of `1.6.5` see nothing change. Requests to a
disabled account simply return no ad.

## Do / don't, before anything else

- **Do not open a new AdSense/AdMob account**, and do not route the app through anyone
  else's account. Google treats that as 規避停權處分 (circumventing the disablement); it
  gets the new account banned and forecloses the appeal.
- **Log in to the consoles first** (`apps.admob.com`, `www.google.com/adsense`) and confirm
  the disablement banner is really there — a pasted email alone could be phishing. Do not
  click links in the email to log in; type the address.
- **Export every report you can still see** before access degrades: AdMob 報表 by day
  (requests, impressions, clicks, estimated earnings), by country, by app, from the first
  day to now. Screenshots are fine if CSV export is gone.
- **Appeal once, not fast.** The form asks for a full traffic analysis; a same-day appeal
  with empty sections wastes the one good shot. Target: submit within a few days, complete.
- **Verify `app-ads.txt` is still served** at `https://shukaihu.github.io/app-ads.txt`
  (owned by the `ShuKaiHu/ShuKaiHu.github.io` repo, not this one). Google re-crawls during
  review. This could not be checked from the sandboxed session that wrote this file.

## Timeline (repo-verified; full SHAs for the appeal's evidence links)

| Date | Event |
| --- | --- |
| 2026-07-12 | AdMob SDK and the **production** banner unit land in the app (`f8f7f79da3c656dc2648fe0c78ee29277c52ffdf`, "Prepare RainyClock 1.3 release"). No test-unit switch exists yet: **every build — simulator, Debug, device — requests the production unit.** |
| 2026-07-26 | `1.6.1 (16)` live; AdMob setup documented (`aab9a0ea76882962e45143b32464265018502d07`). UMP consent flow added (`dc4d8a37e3aad58512113ab42de065bcf9845652`). |
| 2026-07-27 | `1.6.2 (17)` approved and released same day; marketing URL reaches the listing; **app-ads.txt verified by AdMob**; 核准狀態 就緒. |
| 2026-07-28 | AdMob report read: **168 requests, 0 impressions, 0.00% match, US$0.00** — requests "almost entirely from simulators" (STATUS-IOS.md, written that day). Same day, Debug builds switch to Google's test unit (`89e17b9f861e776c81de3f97d858e773a32e54d5`). |
| 2026-08-02 | ATT prompt added; personalized requests only after grant, `npa=1` otherwise (`730e6bd3b6d93f29377ec343bd47333e902b21c4`). |
| 2026-08-03 | Test-unit switch extended to `targetEnvironment(simulator)`, closing the Release-on-simulator smoke-test path (`3750c86747e6c316dc25879cadbe4a3bd98dbf50`). **Developer-side traffic against the production unit ends here.** |
| 2026-08-04 | `1.6.5 (23)` live on the App Store — organic user traffic begins in earnest. |
| 2026-08-13 | `1.6.6 (24)` uploaded, never submitted. `1.6.5` is still the live build at disablement. |
| 2026-08-23 | Disablement notice received. This branch closes the last non-store channel: a Release build installed by Xcode or ad-hoc carries `embedded.mobileprovision`, and `AppEnvironment` now returns the test unit whenever that file is present, so **only genuine App Store installs can request the production unit**. |

## Root-cause assessment

Ranked by likelihood. Google never names the specific activity, so the appeal should state
these honestly rather than guess at others.

1. **Developer traffic on the production unit, 2026-07-12 → 2026-08-03.** For the first two
   weeks of the integration every simulator run and debug build requested the production
   unit — at least 168 requests by 2026-07-28 per AdMob's own report. Because the account
   was brand new (verified 2026-07-27) and the app had no install base, **near 100% of the
   account's early request history was the developer's own traffic**. Google filtered it
   (0 impressions), but a new account whose history is dominated by self-requests is the
   textbook invalid-traffic profile.
2. **Own-device use of the live app after 2026-08-04.** The developer is a genuine user of
   their own commute alarm, on a real App Store install that serves production ads. With a
   tiny install base, one person's daily impressions weigh heavily.
   【Owner must confirm: did you or anyone you know ever **tap** the banner, even once "to
   see if it works"? The answer changes the appeal wording — see the draft.】
3. **Ruled out by the repo.** No purchased, incentivized, bot or exchanged traffic — the
   app has never been advertised 【confirm】. No ad stacking or hidden ads: the code shows
   exactly one anchored adaptive banner, in the view hierarchy only after UMP consent, and
   visible if and only if a creative loaded. No interstitials, no rewarded ads, no
   click-encouraging copy. Android has never shipped and the repo carries only Google's
   sample IDs for it, so no Android traffic exists.

## Remediation — already shipped, plus this branch

Evidence that the cause was found and fixed *before* the disablement, which is the
strongest card the appeal holds. The repo is public, so the commits are citable links
(`https://github.com/ShuKaiHu/RainyClock/commit/<sha>`).

- 2026-07-28 — Debug builds request Google's test unit (`89e17b9…`).
- 2026-08-03 — Any simulator build, including Release smoke tests, requests the test unit
  (`3750c86…`). Shipped to the store in `1.6.5` on 2026-08-04.
- 2026-08-23 (this branch) — Sideloaded/Xcode-installed Release builds detected via
  `embedded.mobileprovision` and given the test unit; the production unit is now reachable
  from App Store installs only. TestFlight (never used so far) would need test devices
  registered in AdMob first — noted in `AppEnvironment.swift`.
- Operational rules, in force since 2026-07-28 and staying: never diagnose ad serving by
  opening the app ("read the AdMob report instead" — STATUS-IOS.md); never interact with
  ads on any owned device; register owned devices under AdMob 設定 → 測試裝置 if the
  account is reinstated (needs each device's IDFA, which requires ATT granted on that
  device to be readable).

## Data to gather before submitting 【owner】

- App Store Connect 分析: downloads, sessions, active devices, countries — per day since
  2026-07-27. This is the "legitimate traffic" baseline.
- AdMob report exports as above. Requests/impressions/clicks per day show the 07-12→08-03
  developer-traffic hump and the organic pattern after 08-04.
- The list of your own devices (and IPs, if static) that ran the app.
- Whether the payments and tax profile is complete (backlog already tracks this) — the
  final payment after the 30-day hold is withheld without it.

## The appeal

Entry point: the link inside the disablement email itself, or AdSense 說明中心 →「帳戶因
無效流量遭停用」的申訴表單 (the Invalid Traffic appeal form; the help center routes to it
from the disabled-account page). Fill 發布商 ID `pub-2920259088304022`. One submission;
duplicates without new information hurt. Answers typically arrive in one to a few weeks.
Expectations, honestly: invalid-traffic appeals are rarely granted, but this case has an
unusually clean, dated, public paper trail and a self-remediation that predates the ban —
it deserves a real attempt.

### Draft (zh-Hant; fill every 【】, delete whichever bracketed variant does not apply)

> **發布商 ID:** pub-2920259088304022
> **產品:** AdMob(iOS 應用程式「雨天鬧鐘 Rainy Clock」,Bundle ID `com.shukaihu.RainyClock`,App Store 連結:【App Store URL】)
>
> **應用程式與流量來源說明:**
> 雨天鬧鐘是單人開發的通勤鬧鐘 App,2026-08-04 於 App Store 上架目前版本 1.6.5。
> 流量 100% 來自 App Store 自然下載(搜尋與親友口碑),從未購買流量、從未使用任何
> 獎勵性安裝或第三方推廣。自上架至今 App Store Connect 顯示約【下載數】次下載、
> 【活躍裝置數】台活躍裝置,主要在【國家/地區】。App 內只有一個錨定自適應橫幅
> 廣告,置於畫面底部分頁列上方;無插頁式、無獎勵廣告、無任何鼓勵點擊的設計。
> 歐洲經濟區使用者先經 UMP 同意流程,未授權 ATT 一律送出 npa=1。
>
> **我們找到的無效活動可能原因(誠實說明):**
> 開發初期(2026-07-12 至 2026-08-03)程式碼尚未區分測試與正式廣告單元,開發者
> 自己的模擬器與除錯建置對正式單元發出了請求;2026-07-28 帳戶報表顯示的 168 次
> 請求、0 次曝光幾乎全部來自這些開發流量。當時帳戶剛完成驗證(2026-07-27)、
> App 尚無安裝基礎,因此帳戶早期請求史幾乎全是開發者自身流量。
> 【若曾點過廣告:此外,開發者曾於【日期】在自己的裝置上點擊過【次數】次橫幅
> 以確認整合是否正常,當時不了解這構成無效點擊,願就此致歉。】
> 【若確定從未點過:開發者與親友從未點擊過 App 中的廣告。】
>
> **已完成的修正(程式碼公開於 GitHub,提交紀錄可查證,且早於停權日):**
> 1. 2026-07-28:Debug 建置一律改用 Google 官方測試廣告單元
>    (https://github.com/ShuKaiHu/RainyClock/commit/89e17b9f861e776c81de3f97d858e773a32e54d5)
> 2. 2026-08-03:任何模擬器建置(含 Release)一律使用測試單元
>    (https://github.com/ShuKaiHu/RainyClock/commit/3750c86747e6c316dc25879cadbe4a3bd98dbf50),
>    並隨 2026-08-04 上架的 1.6.5 生效
> 3. 2026-08-23:進一步收窄——凡帶有開發用描述檔的安裝(Xcode 直接安裝、ad-hoc)
>    於執行期一律改用測試單元,正式廣告單元僅 App Store 正式下載版可觸及
>    (https://github.com/ShuKaiHu/RainyClock/commit/72dc9219b0f3eeec069e4fe0da79bac1080a3f17)
> 4. 營運守則:不以開啟 App 的方式診斷廣告放送,一律改讀 AdMob 報表;開發者
>    自有裝置將於帳戶恢復後登錄為 AdMob 測試裝置;任何情況下不與自家廣告互動。
>
> 懇請貴團隊重新審視本帳戶。上述開發期流量出於整合經驗不足,而非任何獲利意圖
> (該期間曝光為 0、收益為 0),且問題在停權前即已由我們自行發現並修正。若尚有
> 其他需要調整之處,我們願意全力配合。

## Money

The 30-day hold started with the notice: **on or after ~2026-09-22**, log in at
`www.google.com/adsense` to see whether a final balance survived the invalid-activity
clawback. Given US$0.00 revenue as of the last read report, expect nothing — but the
payments/tax profile must be complete for even a nonzero remainder to pay out.

## If the appeal is finally rejected

Decide then, not now. The realistic paths: ship ad-free (the app is fully functional
without the banner), a tip-jar IAP, or a non-Google ad network. Nothing in the current
code blocks any of these; removing the banner is deleting one `if` block in
`ContentView.swift` plus the two Google SDK dependencies.
