# Store package

Everything the store consoles ask for, in one place. Regenerate images with
`docs/store/tools/build.sh` (needs Google Chrome for headless rendering and
`sips`, both present on macOS). The iPhone/iPad/tablet source renders come from

```
flutter test --update-goldens --dart-define=STORE_SHOTS=true \
  --dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store \
  test/store_screenshots_test.dart
```

and the phone JPEGs from a Pixel 9 emulator running the same demo build.

```
listing/ru.md, listing/en.md   texts: title, short/long description, keywords, release notes
data-safety.md                 Google Play Data safety and App Store privacy answers
screenshots/src/               raw captures: phone JPEGs from the emulator plus PNG renders
                               produced by `test/store_screenshots_test.dart` at real iPhone 6.7",
                               iPad 13" and 10" tablet sizes (`store` demo profile — no real data)
screenshots/play/<lang>/       1080×1920 phone screenshots for Google Play / RuStore
screenshots/play-tablet/<lang>/ 2560×1600 10" tablet screenshots for Google Play
screenshots/appstore/<lang>/   1290×2796 iPhone 6.7" screenshots for the App Store (iPhone frame)
screenshots/appstore-ipad/<lang>/ 2064×2752 iPad 13" screenshots for the App Store
feature_graphic.png            1024×500 Google Play feature graphic
icon_512.png                   512×512 Play store icon (App Store uses the 1024 px asset in ios/)
tools/                         HTML templates and the build script
```

## Ad units tab

The Inventory API tab is hidden in store builds: Yandex issues that token to
few partners and reviewers cannot exercise the tab. It appears automatically
for a user who already holds an inventory token, and for development builds
with `--dart-define=ADPOCKET_AD_UNITS=true`.

## Promo video

`video/` holds a 26-second promo built from the real UI: the overview cards fly
in and assemble on an iPhone, the page scrolls, swipes to Reports, opens the
accounts sheet, shows the home-screen widget and closes on the logo.

```
video/en_promo_1080x1920.mp4      Google Play (upload to YouTube, link in the listing)
video/ru_promo_1080x1920.mp4
video/en_preview_886x1920.mp4     App Store app preview, 6.7"/6.5" iPhone
video/ru_preview_886x1920.mp4
video/src/                         3x renders from test/video_renders_test.dart
video/layers/                      card slices produced by tools/video/prep.py
```

Rebuild:

```
flutter test --dart-define=VIDEO_SHOTS=true --dart-define=STORE_SHOTS=true \
  --dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store \
  test/video_renders_test.dart
cd docs/store/tools/video && python3 prep.py            # needs Pillow
npm i puppeteer-core && pip3 install imageio-ffmpeg       # once
node render.js --lang en --out ../../video/en_promo_1080x1920.mp4
node render.js --lang en --w 886 --h 1920 --out ../../video/en_preview_886x1920.mp4
```

`promo.html` is the storyboard: every element is a pure function of time
(`window.seek(t)`), so frames are deterministic. Open it in a browser with
`?lang=ru&t=8.5` to inspect a moment. Google Play accepts only a YouTube link;
App Store previews are uploaded per device size in App Store Connect.

## Google Play Console checklist
| Field | Value |
|---|---|
| App name | AdPocket |
| Default language | Russian (ru-RU); add English (en-US) translation |
| Category | Business |
| Tags | Statistics, Advertising |
| Contact e-mail | robtdyn@gmail.com |
| Privacy policy URL | https://roberttadevosyan.github.io/privacy/app.adpocket.yan/ |
| App access | "All functionality is available without special access" is **not** true — provide test instructions: the reviewer needs a YAN Statistics API token. Use the demo build (`--dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store`) for review, or explain that any token from partner.yandex.ru works. |
| Ads | No, the app contains no ads |
| Content rating | IARC questionnaire: no violence, no user-generated content, no gambling, no data sharing → Everyone / 3+ |
| Target audience | 18 and over |
| Data safety | see `data-safety.md` |
| Government apps / Financial features | No |
| Screenshots | phone from `screenshots/play/`, 10" tablet from `screenshots/play-tablet/` (also accepted for 7") |
| Release | Production track (or Internal testing first for a smoke test); upload `app-release.aab`, add the release notes from the listing files |

## App Store Connect checklist
| Field | Value |
|---|---|
| Name | AdPocket (30 chars max) |
| Subtitle | see listing files (30 chars max) |
| Primary category | Business; secondary: Finance |
| Age rating | 4+ (no restricted content) |
| Privacy policy URL | as above |
| App privacy | "Data not collected" — see `data-safety.md` |
| Sign-in | Not applicable (no accounts on our side); provide a demo token or the demo build for App Review in the Review Notes |
| Export compliance | Uses only standard HTTPS → exempt (set `ITSAppUsesNonExemptEncryption = NO` in Info.plist) |
| Screenshots | 6.7" (1290×2796) from `screenshots/appstore/`; iPad 13" (2064×2752) from `screenshots/appstore-ipad/` — the app supports iPad, so upload both |

## Release builds

Android (signed with the upload key; `android/key.properties` and
`android/upload-keystore.jks` are git-ignored, back them up outside the repo —
losing the upload key means asking Google to reset it):

```
flutter build appbundle --release      # build/app/outputs/bundle/release/app-release.aab
```

iOS (automatic signing, team set in the Xcode project; the App Group
`group.app.adpocket.yan` must exist in the developer portal — Xcode registers it
from Signing & Capabilities the first time):

```
flutter build ipa --release --export-method app-store   # build/ios/ipa/*.ipa
```

Upload the .ipa with Transporter or `xcrun altool --upload-app`, or archive from
Xcode (Product → Archive → Distribute App).

Bump `version:` in pubspec.yaml before every store upload; both stores reject a
reused build number.

## RuStore checklist
Same texts as Google Play (Russian first), 1080×1920 screenshots, privacy policy URL, category "Бизнес",
age 18+, no in-app purchases. Upload the same signed APK/AAB.

## Trademark note
The listing names Yandex only descriptively ("statistics for Yandex Advertising Network partners")
and states that the app is unofficial. Do not use the Yandex logo anywhere in the listing.
