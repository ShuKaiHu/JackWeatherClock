# AdMob account disabled — incident record and appeal (2026-08-23)

On 2026-08-23 Google disabled the publisher account `pub-2920259088304022` for
「無效流量和/或其他違反發布商政策」. The notice is the standard invalid-traffic
disablement: all ad serving stops (AdMob included), a 30-day payment hold starts, and the
only recourse is one well-prepared appeal. This file is the working record: what we know,
what caused it as far as the repo can prove, what was already fixed and when, and the
appeal answers mapped onto the real form.

**The live app needs no emergency release.** A banner that gets no fill renders at height 0
and opacity 0 (`AdMobBannerView`), so users of `1.6.5` see nothing change. Requests to a
disabled account simply return no ad.

## Do / don't, before anything else

- **Do not open a new AdSense/AdMob account**, and do not route the app through anyone
  else's account. Google treats that as 規避停權處分 (circumventing the disablement); it
  gets the new account banned and forecloses the appeal.
- **Confirmed real, 2026-08-23:** the AdMob console itself shows 「您目前無法使用 AdMob —
  帳戶已關閉,但您可以提交這份表單申訴」, linking to the 無效流量申訴 form. Not phishing,
  and console access is gone.
- **Report exports are no longer possible** — the console is closed. The only surviving
  AdMob numbers are the 2026-07-28 read recorded in `STATUS-IOS.md`: 168 requests,
  0 impressions, 0.00% match, US$0.00. App Store Connect analytics are Apple-side and
  unaffected; pull downloads and active devices from there for the appeal.
- **Appeal once, not fast.** The form's own checkbox states that once Google rules on the
  appeal, no follow-up appeals are accepted and no further contact is made. Fill the two
  numeric blanks (App Store Connect downloads/devices) before submitting.
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
| 2026-08-23 | Disablement notice received; console confirms the closure. This branch closes the last non-store channel: a Release build installed by Xcode or ad-hoc carries `embedded.mobileprovision`, and `AppEnvironment` now returns the test unit whenever that file is present, so **only genuine App Store installs can request the production unit** (`72dc9219b0f3eeec069e4fe0da79bac1080a3f17`). |

## Root-cause assessment

Ranked by likelihood. Google never names the specific activity, so the appeal states these
honestly rather than guessing at others.

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
   see if it works"? The answer picks between two sentences in the form text below.】
3. **Ruled out.** No purchased, incentivized, bot or exchanged traffic — confirmed by the
   owner 2026-08-23 ("我是真的沒有買流量"); the app has never been advertised. No ad
   stacking or hidden ads: the code shows exactly one anchored adaptive banner, in the view
   hierarchy only after UMP consent, and visible if and only if a creative loaded. No
   interstitials, no rewarded ads, no click-encouraging copy. Android has never shipped and
   the repo carries only Google's sample IDs for it, so no Android traffic exists.

## Remediation — already shipped, plus this branch

Evidence that the cause was found and fixed *before* the disablement, which is the
strongest card the appeal holds. The repo is public, so the commits are citable links
(`https://github.com/ShuKaiHu/RainyClock/commit/<sha>`).

- 2026-07-28 — Debug builds request Google's test unit (`89e17b9…`).
- 2026-08-03 — Any simulator build, including Release smoke tests, requests the test unit
  (`3750c86…`). Shipped to the store in `1.6.5` on 2026-08-04.
- 2026-08-23 (this branch) — Sideloaded/Xcode-installed Release builds detected via
  `embedded.mobileprovision` and given the test unit; the production unit is now reachable
  from App Store installs only (`72dc921…`). Ships with the next submitted version.
  TestFlight (never used so far) would need test devices registered in AdMob first — noted
  in `AppEnvironment.swift`.
- Operational rules, in force since 2026-07-28 and staying: never diagnose ad serving by
  opening the app ("read the AdMob report instead" — STATUS-IOS.md); never interact with
  ads on any owned device; register owned devices under AdMob 設定 → 測試裝置 if the
  account is reinstated (needs each device's IDFA, which requires ATT granted on that
  device to be readable).

## The appeal form, field by field

The form is the 無效流量申訴 (Invalid Traffic appeal), reached from the closed console's
「這份表單」link. Located and mapped 2026-08-23. Before submitting, fill every 【】:
real name, the App Store URL, the App Store Connect numbers, and the tapped-or-not
sentence choice. The App Store URL comes from the App Store share sheet, or:

```
curl -s "https://itunes.apple.com/lookup?bundleId=com.shukaihu.RainyClock&country=tw" | python3 -m json.tool | grep trackViewUrl
```

> **請輸入您的姓名**
> 【真實姓名,與 AdMob 帳戶付款資料一致】
>
> **請輸入您的發布商代碼**
> pub-2920259088304022
>
> **聯絡電子郵件地址**
> (已預填的帳戶信箱即可 — Google 的回覆會寄到這裡)
>
> **您刊登廣告的範例網址或應用程式 ID**
> iOS 應用程式「雨天鬧鐘 Rainy Clock」
> AdMob 應用程式 ID:ca-app-pub-2920259088304022~6773413597
> Bundle ID:com.shukaihu.RainyClock
> App Store:【App Store 連結】
>
> **您想要刊登廣告的網址或應用程式 ID(必須是運作中)**
> 【App Store 連結】
>
> **您是否曾為網站、行動應用程式和/或 YouTube 頻道購買流量?**
> 否
>
> **使用者如何連到您的網站、行動應用程式和/或 YouTube 頻道?您如何宣傳內容?**
> 本 App 是個人開發的雨天通勤鬧鐘工具,2026-08-04 於 App Store 上架目前版本 1.6.5。
> 使用者 100% 來自 App Store 自然搜尋與親友口碑;從未購買流量、從未投放任何廣告、
> 從未使用獎勵性安裝或第三方推廣。除 App Store 商店頁和 GitHub Pages 上的支援頁
> (https://shukaihu.github.io/RainyClock/)外,沒有其他宣傳管道。自上架至今
> App Store Connect 顯示約【N】次下載、【N】台活躍裝置,主要位於【國家/地區】。
>
> **您自己或您的網站、行動應用程式和/或 YouTube 頻道是否曾經違反 AdSense 或
> Ad Manager 計畫政策或《條款及細則》?如果是,請說明詳細情況。**
> 是,但屬開發疏失而非刻意:2026-07-12 至 2026-08-03 期間,程式碼尚未區分測試與
> 正式廣告單元,開發者自己的 iOS 模擬器與除錯建置對正式廣告單元發出了請求,
> 可能構成無效流量。該期間曝光為 0、收益為 US$0,未對任何廣告主造成損失。
> 問題由我們自行發現,並在帳戶遭停用之前就已修正(詳見後兩題)。除此之外
> 沒有其他違規:從未購買流量、無任何鼓勵點擊的設計、內容亦無政策疑慮。
>
> **您的網站、行動應用程式和/或 YouTube 頻道上為什麼會有無效活動?
> 請詳細說明您認為是哪些原因導致了無效活動。**
> 我們無法得知貴系統實際偵測到的活動,但依自查,最可能的原因如下:
> 1. 開發期自我流量(2026-07-12 至 2026-08-03):整合 AdMob 初期未切換測試廣告
> 單元,開發者的模擬器與除錯建置直接請求了正式單元。帳戶 2026-07-27 才完成
> app-ads.txt 驗證,App 當時幾乎沒有安裝基礎,因此帳戶早期的請求記錄幾乎全部
> 是這類開發流量——2026-07-28 讀取報表時為 168 次請求、0 次曝光、收益 US$0,
> 我們當日即開始修正。
> 2. 2026-08-04 正式上架後,開發者本人也是這個 App 的日常使用者;在安裝基礎
> 很小的情況下,自有裝置產生的請求佔比偏高。
> 【二選一,留一句刪一句:
> 開發者與親友從未點擊過 App 內的任何廣告。
> / 開發者曾於【日期】為確認整合是否正常,在自己的裝置上點擊過【次數】次橫幅,
> 當時不了解這構成無效點擊,對此致歉。】
> App 內只有一個錨定自適應橫幅(畫面底部、分頁列上方),沒有插頁式、獎勵廣告
> 或任何鼓勵點擊的設計;歐洲經濟區使用者先經 UMP 同意流程,未授權 ATT 的請求
> 一律帶 npa=1。
>
> **您將進行哪些調整來改進您網站、行動應用程式和/或 YouTube 頻道的廣告流量品質?**
> 本 App 程式碼完全公開於 GitHub(https://github.com/ShuKaiHu/RainyClock),
> 以下修正的提交日期均可查證,且第 1、2 項早於停權日:
> 1. 2026-07-28:Debug 建置一律改用 Google 官方測試廣告單元
> (https://github.com/ShuKaiHu/RainyClock/commit/89e17b9f861e776c81de3f97d858e773a32e54d5)
> 2. 2026-08-03:任何模擬器建置(含 Release 冒煙測試)一律使用測試單元
> (https://github.com/ShuKaiHu/RainyClock/commit/3750c86747e6c316dc25879cadbe4a3bd98dbf50);
> 這兩項修正皆已包含在 2026-08-04 上架的 1.6.5 版。
> 3. 2026-08-23:進一步收窄——凡帶有開發用描述檔的安裝(Xcode 直接安裝、ad-hoc)
> 於執行期一律改用測試單元,正式廣告單元只有 App Store 正式下載版可觸及
> (https://github.com/ShuKaiHu/RainyClock/commit/72dc9219b0f3eeec069e4fe0da79bac1080a3f17),
> 將隨下一個送審版本發布。
> 4. 營運守則:不以開啟 App 的方式診斷廣告放送,一律改讀 AdMob 報表;帳戶若
> 恢復,立即將開發者自有裝置登錄為 AdMob 測試裝置;任何情況下不與自家廣告互動;
> 定期檢視報表,及早發現異常流量。
>
> **請從您的網站、行動應用程式和/或 YouTube 頻道流量記錄或報表中,找出所有可能
> 跟無效活動有關的可疑 IP 位址、參照網址或廣告請求,並提供相關資料給我們。**
> 帳戶停用後我們已無法存取 AdMob 報表,且 AdMob 報表本身不向發布商提供 IP 層級
> 資料,因此無法列出具體 IP。能明確指認的可疑流量即為上述開發期自我流量:
> - 期間:2026-07-12 至 2026-08-03
> - 來源:開發者自有的 Mac(iOS 模擬器)與 iPhone 除錯建置,位於【城市/國家】,
> 經【ISP】的一般家用網路連線
> - 規模:2026-07-28 讀取報表時為 168 次廣告請求、0 次曝光(貴系統當時已過濾,
> 未產生任何收益)
> - 2026-08-04 之後,同一網路環境下開發者自有 iPhone 作為一般使用者使用 App 的
> 請求,也應視為需要排除的自我流量。
> 上述各時間點均有公開的 GitHub 提交記錄與開發日誌可供查證。

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
