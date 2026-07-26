# Rainy Clock App Store Metadata

## App Information

| Field | English | 繁體中文 |
| --- | --- | --- |
| App Name | Rainy Clock | 雨天鬧鐘 |
| Subtitle | Rain-aware commute alarm | 通勤雨天智慧鬧鐘 |
| Category | Weather | 天氣 |
| Secondary Category | Utilities | 工具程式 |
| Price | Free | 免費 |
| Copyright | 2026 Shu-Kai Hu | 2026 Shu-Kai Hu |
| Support URL | `https://shukaihu.github.io/RainyClock/support.html` | `https://shukaihu.github.io/RainyClock/support.html` |
| Privacy Policy URL | `https://shukaihu.github.io/RainyClock/privacy-policy.html` | `https://shukaihu.github.io/RainyClock/privacy-policy.html` |
| Marketing URL | `https://shukaihu.github.io/RainyClock/` | `https://shukaihu.github.io/RainyClock/` |

The marketing URL is what AdMob reads to locate `app-ads.txt`; it must stay on the `shukaihu.github.io` domain. See the app-ads.txt section of `docs/app-store-submission-checklist.md`.

## Promotional Text

### English

Rainy Clock checks your commute weather and helps schedule an earlier alarm when rain may slow you down.

### 繁體中文

雨天鬧鐘會檢查通勤天氣，當雨勢可能影響出門時間時，協助你提前安排鬧鐘。

## Description

### English

Rainy Clock is a simple commute alarm for rainy mornings.

Set your home and work addresses, choose a commute mode, then set your normal alarm time. Rainy Clock previews your route, checks Apple Weather for your home and office areas around the alarm check time, and schedules a local notification alarm earlier when the rain chance exceeds your threshold.

Key features:
- Route setup with Apple Maps preview
- Home and office weather checks powered by Apple Weather
- Adjustable rain lead time from 1 to 60 minutes
- Adjustable rain probability threshold
- Weekday alarm selection
- Built-in alarm sounds with preview
- Local notifications for scheduled alarms

Rainy Clock does not require an account and does not run its own backend server.

### 繁體中文

雨天鬧鐘是一個為雨天通勤設計的簡單鬧鐘。

設定住家與工作地址、選擇通勤方式，再設定平常的鬧鐘時間。雨天鬧鐘會預覽通勤路線，並在鬧鐘判斷時間附近透過 Apple Weather 檢查住家與公司附近的天氣；如果降雨機率超過你設定的門檻，就會提前安排本機通知鬧鐘。

主要功能：
- 使用 Apple Maps 預覽通勤路線
- 透過 Apple Weather 檢查住家與公司附近天氣
- 雨天提前時間可在 1 到 60 分鐘間調整
- 可調整降雨機率門檻
- 可選擇每週哪些天響鈴
- 內建多種鬧鈴音效並支援試聽
- 使用本機通知排程鬧鐘

雨天鬧鐘不需要註冊帳號，也沒有自建後端伺服器。

## Keywords

### English

rain alarm,weather alarm,commute alarm,smart alarm,rain,weather,alarm clock,commute

### 繁體中文

雨天鬧鐘,天氣鬧鐘,通勤鬧鐘,智慧鬧鐘,降雨,天氣,鬧鐘,通勤

## Version 1.6.2 (17) “What’s New”

Submitted 2026-07-27. Nothing in this release is visible outside the EEA, the UK, and Switzerland; the notes say so rather than inventing user-facing changes.

### English

```
This update focuses on advertising privacy:

• In the European Economic Area, the UK, and Switzerland, a consent choice now appears before any ads load, and it can be changed at any time from "Ad privacy options" in Settings.
• Updated the technical configuration used for ad measurement.

Everywhere else the experience is unchanged — alarms, commute routes, and weather work exactly as before.
```

### 繁體中文

```
本次更新著重於廣告隱私規範：

• 歐洲經濟區、英國與瑞士的使用者，開啟 App 時會先看到廣告用途的同意選項，之後可隨時在設定中的「廣告隱私設定」重新調整。
• 更新廣告成效評估所需的技術設定。

其他地區的使用體驗不變，鬧鐘、通勤路線與天氣功能維持原樣。
```

## Version 1.3 “What’s New”

### English

- Improved address validation and route preview handling.
- Updated route weather checks to use Apple Weather.
- Added clearer actual-address hints when a typed address resolves to a suggested location.
- Refined alarm lead-time controls and route/alarm layout.

### 繁體中文

- 改善地址驗證與路線預覽處理。
- 路線天氣改用 Apple Weather。
- 當輸入地址被解析為建議地點時，顯示更清楚的實際使用地址提示。
- 調整雨天提前時間控制與路線／鬧鐘頁面排版。

## App Review Notes

### English

Rainy Clock uses Apple Maps for route preview and Apple Weather / WeatherKit for home and office weather checks. Alarm scheduling uses local notifications only. The app includes a Google AdMob banner ad at the bottom of the screen. No login is required.

### 繁體中文

雨天鬧鐘使用 Apple Maps 顯示路線預覽，並使用 Apple Weather / WeatherKit 檢查住家與公司附近天氣。鬧鐘排程只使用本機通知。App 底部有 Google AdMob 橫幅廣告。不需要登入。

### Version-specific note prepared for 1.6.2 (17)

The note carried over from the 5.1.2(i) resolution still described build `1.6 (10)` and said nothing about the new consent flow, so this replacement was prepared:

```
This app does not track users. The App Privacy information declares no data types as used
for tracking, and ads are served via Google AdMob configured for non-personalized ads only
(npa=1), with no AppTrackingTransparency prompt and no IDFA access.

New in this build (1.6.2 / 17): a Google UMP consent flow runs before the Mobile Ads SDK is
initialised for users in the EEA, the UK, and Switzerland; those users can revisit their
choice via "Ad privacy options" in Settings. The Apple Weather attribution mark and legal
link remain in the Route tab weather section, as reviewed in 1.6.1 (16).
```

The "Sign-in required" checkbox in App Review Information was also found checked with a demo account, even though the app has no login. It should be cleared.

## Privacy Nutrition Label Draft

Final answers should be verified in App Store Connect before submission.

| Area | Draft Answer |
| --- | --- |
| Account creation | No |
| User-generated content | No |
| Location data | Used for app functionality when resolving route/weather locations |
| Contact info | Not collected by the app |
| Backend server | None |
| Third-party SDKs | Google Mobile Ads SDK, Google User Messaging Platform |
| Advertising | Google AdMob banner ads |
| Tracking | Confirm based on final AdMob/UMP consent and IDFA configuration before submission |

## Screenshots Still Needed

Prepare screenshots for the required device sizes in App Store Connect:

- Route tab with valid addresses, route preview, and route weather.
- Alarm tab with weekday selection, alarm time, rain lead-time slider, rain threshold, and sound picker.
- Optional: address validation state showing the actual address in use.
