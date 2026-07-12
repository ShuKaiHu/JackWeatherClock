# Rainy Clock App Store Submission Checklist

## Current Build

| Item | Status |
| --- | --- |
| App version | `1.3` |
| Build number | `5` |
| TestFlight upload | Uploaded successfully |
| Archive path | `build/RainyClock-1.3-5.xcarchive` |
| Bundle identifier | `com.shukaihu.RainyClock` |
| Primary language | Traditional Chinese |

## Completed

- App name and bundle renamed to Rainy Clock / 雨天鬧鐘.
- App icon is included in the Xcode asset catalog.
- GitHub Pages support and privacy pages exist under `docs/`.
- Weather source is Apple Weather / WeatherKit.
- Route preview uses Apple Maps.
- Bottom ad uses Google AdMob banner placement.
- Local notification alarm scheduling is implemented.
- App Store metadata draft is in `docs/appstore-metadata.md`.

## Still Required Before Public Release

- Upload final App Store screenshots in App Store Connect.
- Complete App Privacy answers in App Store Connect.
- Confirm AdMob/UMP privacy and consent settings, especially whether IDFA tracking is enabled.
- Confirm the Apple Weather / WeatherKit entitlement works in the App Store build.
- Confirm real-device testing on at least one older/smaller iPhone and one current iPhone.
- Fill App Review notes and contact info in App Store Connect.
- Submit the `1.3 (5)` build for App Review when testing is complete.

## Known Review / QA Risks

- iOS local notifications can only play short bundled notification sounds; this app is not a full-screen system alarm replacement.
- Apple Maps may resolve some typed addresses to a nearby suggested location. The app now shows the actual address in use when this happens.
- Google Places fallback requires a valid API key before enabling; `GooglePlacesAPIKey` is currently empty in `RainyClock/Info.plist`.
- Xcode upload may warn about missing dSYM files for Google SDK frameworks. This does not block upload, but Google SDK crash symbolication may be limited.

## Useful URLs

- Support: `https://shukaihu.github.io/RainyClock/support.html`
- Privacy Policy: `https://shukaihu.github.io/RainyClock/privacy-policy.html`
- Repository: `https://github.com/ShuKaiHu/RainyClock`
