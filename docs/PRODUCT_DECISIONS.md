# Product Decisions / 產品決策

## English

### Current Scope

Rainy Clock focuses on one commute profile: home to work. Users choose a commute mode, set a normal alarm time, select weekdays, set a rain lead time, and set a rain probability threshold. If weather around the next scheduled alarm check time meets the rain threshold, the app schedules an earlier local-notification alarm.

### Weather Strategy

The app is structured around a `RouteWeatherService` protocol. The current release path uses `MapKitRouteWeatherService` with Apple Weather / WeatherKit.

The production implementation should:

1. Resolve home and work addresses.
2. Request a route for the selected commute mode.
3. Use the next selected weekday/time, minus the configured lead time, as the weather check time.
4. Query Apple Weather / WeatherKit for home-area and office-area weather around that check time.
5. Return whether either endpoint meets or exceeds the chosen rain probability threshold.

Open-Meteo is not part of the active release path.

### Address Strategy

Address entry should make resolution quality visible:

- If a user selects a dropdown suggestion, treat that result as confirmed.
- If the app resolves typed text without an explicit suggestion selection, show the actual address in use.
- If an address cannot be resolved, mark only that address field as invalid.
- The “Use this location” action should replace the typed address with the resolved address.

Google Places fallback can be added later, but should only run when Apple address resolution fails and after a production API key is configured.

### Alarm Strategy

Local notifications are scheduled through `UNUserNotificationCenter`. iOS does not allow third-party apps to fully replicate the built-in Clock app’s full-screen alarm behavior.

The intended product behavior is to refresh weather at the configured lead-time point. For example, if the normal alarm is 7:30 and the rain lead time is 30 minutes, the app checks the selected route/weather at 7:00. If the threshold is exceeded, the early alarm fires; otherwise, the normal alarm remains.

### Localization Strategy

All user-facing UI text should be backed by localized string resources. Documentation should include both English and Traditional Chinese so product and technical decisions stay aligned across languages.

---

## 繁體中文

### 目前範圍

Rainy Clock 聚焦在單一通勤設定：住家到公司。使用者可以選擇通勤方式、設定平常鬧鐘時間、選擇星期、設定雨天提前時間與降雨機率門檻。若下一次鬧鐘判斷時間附近的天氣達到降雨門檻，App 就會提前安排本機通知鬧鐘。

### 天氣策略

App 以 `RouteWeatherService` protocol 作為路線天氣抽象層。目前上架版本流程使用 `MapKitRouteWeatherService` 與 Apple Weather / WeatherKit。

正式版實作應該：

1. 解析住家與公司地址。
2. 依照使用者選擇的通勤方式查詢路線。
3. 使用下一個符合星期與時間設定的鬧鐘時間，扣掉雨天提前時間，作為天氣判斷時間。
4. 透過 Apple Weather / WeatherKit 查詢該時間附近的住家與公司附近天氣。
5. 回傳任一端點是否達到或超過使用者設定的降雨門檻。

Open-Meteo 已不在目前上架版本的主要流程中。

### 地址策略

地址輸入應清楚顯示解析品質：

- 如果使用者從下拉式建議選單選取，視為已確認地址。
- 如果 App 直接用輸入文字解析出地址，但使用者沒有明確選取建議，顯示實際使用地址。
- 如果某個地址無法解析，只將該地址欄位標示為無效。
- 「使用此位置」按鈕應將輸入文字替換為實際解析出的地址。

Google Places fallback 可在未來加入，但只應在 Apple 地址解析失敗時啟用，且必須先設定正式 API key。

### 鬧鐘策略

本機通知透過 `UNUserNotificationCenter` 排程。iOS 不允許第三方 App 完全複製系統時鐘 App 的全螢幕鬧鐘行為。

預期產品行為是在使用者設定的提前時間點刷新天氣。例如平常鬧鐘是 7:30、雨天提前時間是 30 分鐘，App 應在 7:00 檢查路線與天氣。如果超過門檻，提早鬧鐘響起；否則保留正常鬧鐘。

### 本地化策略

所有使用者可見的 UI 文字都應由本地化字串資源提供。文件應同時提供英文與繁體中文，確保產品與技術決策在兩種語言中保持一致。
