# Rainy Clock App Store Metadata

> **English (U.S.) was added with the `1.6.4 (19)` submission** and goes live when that version is released. Two gotchas discovered while adding it on 2026-07-29: (1) the English app names "Rainy Clock" and "RainyClock" are **taken by other accounts**, so the English listing name is `Rainy Clock: Rain Alarm`; (2) App Store Connect's version page has a UI bug — when adding a localization fails (e.g. because of the name conflict), the 儲存 button just shows a red error icon with no message and retries a doomed create forever. The real error is only visible on the `POST /iris/v1/appStoreVersionLocalizations` response (409). The workaround that worked: create the `appInfoLocalizations` record (name + subtitle) via the iris API from the logged-in browser session, then PATCH the auto-created `appStoreVersionLocalizations` with the copy below.

## App Information

| Field | English | 繁體中文 |
| --- | --- | --- |
| App Name | Rainy Clock: Rain Alarm | Rainy Clock |
| Subtitle | Rain-aware commute alarm | 雨天鬧鐘 |
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

Rainy Clock is a smart alarm app built for commuters.

Set your home and work addresses, choose a commute mode, then set your normal alarm time. Rainy Clock previews your commute route and checks Apple Weather around your home and office. When the rain chance exceeds your threshold, it moves your alarm earlier — so rainy mornings never catch you off guard.

Key features:
- Alarm breaks through Silent mode and Focus with a full-screen alert (iOS 26 and later)
- Snooze you can turn on or off, with a 1–15 minute interval and a countdown on the Lock Screen and in the Dynamic Island (iOS 26 and later)
- Home and work address setup with Apple Maps route preview
- Weather checks powered by Apple Weather
- Adjustable rain lead time and rain probability threshold
- Weekday alarm selection
- Built-in alarm sounds with preview, plus the system default alarm tone on iOS 26 and later
- Any settings change syncs to the scheduled alarm automatically

On iOS 17–25, alarms are scheduled as local notifications and still follow the silent switch.

Rainy Clock does not require an account and does not run its own backend server.

### 繁體中文

雨天鬧鐘是一款為通勤族設計的智慧鬧鐘 App。

設定住家與工作地址、選擇通勤方式，再設定平常的鬧鐘時間。雨天鬧鐘會預覽你的通勤路線，並透過 Apple Weather 檢查住家與公司附近的天氣。如果降雨機率超過你設定的門檻，App 會自動把鬧鐘提前，讓雨天早晨更從容。

主要功能：
・鬧鐘穿透靜音與專注模式，以全螢幕提示響鈴（iOS 26 以上）
・賴床功能可開關，間隔 1 到 15 分鐘自由選擇，倒數會顯示在鎖定畫面與動態島（iOS 26 以上）
・設定住家與工作地址，使用 Apple Maps 預覽通勤路線
・透過 Apple Weather 檢查天氣
・可調整雨天提前時間與降雨機率門檻
・可選擇鬧鐘響鈴的星期
・內建多種鬧鈴音效並支援試聽，iOS 26 以上還可選擇系統預設鬧鈴
・調整任何設定後，已排程的鬧鐘會自動同步更新

iOS 17–25 以本機通知排程鬧鐘，響鈴仍會受靜音開關影響。

雨天鬧鐘不需要註冊帳號，也不會建立自己的後端伺服器。

## Keywords

### English

rain alarm,weather alarm,commute alarm,smart alarm,rain,weather,alarm clock,commute

### 繁體中文

雨天鬧鐘,天氣鬧鐘,通勤鬧鐘,智慧鬧鐘,降雨,天氣,鬧鐘,通勤

## Version 1.6.5 (20) “What’s New”

`1.6.4` was rejected before release, so these notes carry its interface changes as well — from
a user's point of view `1.6.5` is the version where both land.

### English

```
Interface refresh, plus a say over your ads:

• The weekday selector on the Alarm tab now uses round buttons — the days your alarm will ring are clearly highlighted with a blue circle, visible at a glance.
• One consistent blue across the whole app: the sound preview, snooze switch, schedule button, and transport mode selector now share the same accent color.
• You are now asked whether ads may be matched to your interests. Decline and the app works exactly the same — you just see less relevant ads.
```

### 繁體中文

```
介面更新，並讓你決定廣告要不要個人化：

• 鬧鐘頁的星期選擇改為圓形按鈕——鬧鐘會響的日子以藍色圓底清楚標示，一眼就能看出來。
• 統一整個 App 的介面色彩：鈴聲試聽、賴床開關、排程按鈕與交通方式選擇現在使用同一個藍色。
• 新增詢問是否允許廣告依你的興趣呈現。選擇不允許也不影響任何功能，只是看到的廣告關聯性較低。
```

## Version 1.6.4 (19) “What’s New”

Rejected before release; superseded by the 1.6.5 notes above.

### English

```
Interface refresh:

• The weekday selector on the Alarm tab now uses round buttons — the days your alarm will ring are clearly highlighted with a blue circle, visible at a glance.
• One consistent blue across the whole app: the sound preview, snooze switch, schedule button, and transport mode selector now share the same accent color.
```

### 繁體中文

```
介面更新：

• 鬧鐘頁的星期選擇改為圓形按鈕——鬧鐘會響的日子以藍色圓底清楚標示，一眼就能看出來。
• 統一整個 App 的介面色彩：鈴聲試聽、賴床開關、排程按鈕與交通方式選擇現在使用同一個藍色。
```

## Version 1.6.3 (18) “What’s New”

### English

```
Your alarm now rings even on silent.

• On iOS 26 and later, the alarm uses Apple's new alarm system: it breaks through Silent mode and Focus with a full-screen alert, just like the built-in Clock app.
• New Snooze options: turn snooze on or off and pick an interval from 1 to 15 minutes. While snoozing, a countdown appears on the Lock Screen and in the Dynamic Island.
• New "System Default Alarm" ringtone option (iOS 26 and later).
• Changing the alarm time, weekdays, rain settings, sound, or snooze now updates the scheduled alarm automatically — no need to press the button again. Changing an address removes the alarm so you can confirm the new route first.
• The status message now clearly shows in color whether an alarm is currently set.

On iOS 17–25, alarms still follow the silent switch; the snooze interval controls how often the alarm re-rings until you stop it.
```

### 繁體中文

```
鬧鐘現在連靜音時也會響。

• 在 iOS 26 以上，鬧鐘改用 Apple 全新的系統鬧鐘機制：如同內建時鐘 App，以全螢幕提示穿透靜音與專注模式。
• 新增賴床選項：可開關賴床並選擇 1 到 15 分鐘的間隔；賴床倒數會顯示在鎖定畫面與動態島。
• 新增「系統預設鬧鈴」鈴聲選項（iOS 26 以上）。
• 調整鬧鐘時間、星期、雨天設定、鈴聲或賴床後，已排程的鬧鐘會自動同步更新，不需再按一次按鈕；變更地址則會先移除鬧鐘，確認新路線後再重新排程。
• 按鈕下方的狀態訊息改以顏色清楚顯示目前是否已設定鬧鐘。

iOS 17–25 的鬧鐘仍受靜音開關影響；賴床間隔會決定鬧鐘在停止前重複響鈴的頻率。
```

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

### Version-specific note prepared for 1.6.5 (20)

Replaces the 1.6.2 note above, which said the app does not track — no longer true. Paste into
the version's 備註 / Notes field:

```
This build adds App Tracking Transparency.

Where the prompt appears: launch the app, the ad-consent dialog appears first, and the ATT
permission request follows immediately after it on the Route tab (the first screen). No other
step is required — there is no login and no configuration to enter. The prompt is requested in
every region, not only in the EEA. If it does not appear, please check that "Allow Apps to
Request to Track" is enabled in Settings > Privacy & Security > Tracking.

Ads are requested as non-personalized (npa=1) unless the user grants tracking permission, and
the App Privacy information has been updated to declare data used to track.

Regarding "unable to add Widgets at the Home Screen" (2.1(a)): Rainy Clock is an iPhone-only
app and does not provide a Home Screen widget. The widget extension it ships contains only the
alarm's Live Activity, which AlarmKit requires in order to show the snooze countdown on the
Lock Screen and in the Dynamic Island (iPhone, iOS 26 and later). On iPad the app runs in
iPhone compatibility mode, where iOS does not offer third-party widgets at all. We kindly ask
that this be reviewed on an iPhone running iOS 26.
```

### Reply to send in App Store Connect for the 1.6.4 (19) rejection

```
Thank you for the review.

Guideline 5.1.2(i): resolved in build 1.6.5 (20), which implements App Tracking Transparency.
The permission request is presented on first launch, immediately after the ad-consent dialog,
on the app's first screen (the Route tab), in every region. Until permission is granted, ad
requests are sent as non-personalized. The app privacy information in App Store Connect has
been updated to disclose data used to track.

Guideline 2.1(a): we believe this is not a defect in the app. Rainy Clock is an iPhone-only
app (target device family: iPhone) and has never offered a Home Screen widget, in its
description, its screenshots, or its binary. The bundled widget extension contains only an
ActivityConfiguration: AlarmKit requires a widget extension in order to display the alarm's
snooze countdown as a Live Activity on the Lock Screen and in the Dynamic Island on iPhone
with iOS 26 or later. It provides nothing that can be added to the Home Screen. In addition,
the review was performed on an iPad Air 11-inch (M3), where the app runs in iPhone
compatibility mode; iPadOS does not offer third-party Home Screen widgets for apps running in
that mode. We kindly ask that this functionality be reviewed on an iPhone running iOS 26.
```

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
| Tracking | Yes, from `1.6.5 (20)`: ATT is implemented, so Device ID and advertising/usage data must be checked as "Used to Track You" |

## Screenshots Still Needed

Prepare screenshots for the required device sizes in App Store Connect:

- Route tab with valid addresses, route preview, and route weather.
- Alarm tab with weekday selection, alarm time, rain lead-time slider, rain threshold, and sound picker.
- Optional: address validation state showing the actual address in use.
