# Data safety (Google Play) and App Privacy (App Store)

Ground truth: the app has no backend. It stores the user's OAuth token(s), settings and
cached statistics on the device and talks only to Yandex's API over HTTPS. No analytics,
crash reporting, advertising or push SDKs are included.

## Google Play — Data safety form
| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Yes (HTTPS only) |
| Do you provide a way for users to request that their data is deleted? | Yes — remove the account in Settings or uninstall; nothing is stored off-device |
| Committed to the Play Families policy? | No (not for children) |
| Independent security review? | No |

Rationale: "collection" in Play's definition means transmitting data off the device to the
developer or a third party the developer controls. The token and report parameters go only to
Yandex, the service the user is a customer of, on the user's own behalf; Play's guidance treats
such service-provider transfers initiated by the user as not "collected by the app".
If a reviewer disagrees, declare: *Personal info → Other info (OAuth token)*, purpose *App
functionality*, ephemeral processing **No**, required **Yes**, not shared.

Permissions to justify if asked: INTERNET, POST_NOTIFICATIONS (local summaries),
RECEIVE_BOOT_COMPLETED (re-register scheduled local notifications), USE_BIOMETRIC (app lock).
No battery-optimisation permission is declared: the app only opens the system list via
ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS after an explanation dialog.

## App Store — App Privacy
| Section | Answer |
|---|---|
| Data collection | **Data Not Collected** |
| Tracking | No |
| Privacy policy URL | https://roberttadevosyan.github.io/privacy/app.adpocket.yan/ |

Usage strings present in Info.plist: `NSFaceIDUsageDescription` (app lock).
Encryption: only standard HTTPS → `ITSAppUsesNonExemptEncryption = NO`.

## Review notes (both stores)
"AdPocket is a third-party client for the Yandex Advertising Network Statistics API.
Signing in requires an OAuth token that partners obtain at partner.yandex.ru. For review,
use the attached demo build (all API calls are answered locally with synthetic data;
any text works as the token) or the token provided in this note."
