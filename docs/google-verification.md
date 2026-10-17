# Google OAuth verification: AdPocket

Material for Google Auth Platform → Verification Center (project
`adpocket-publishing`). No secrets in this file.

## Branding

| Field | Value |
|---|---|
| App name | AdPocket |
| User support email | robtdyn@gmail.com |
| App logo | `site/public/img/icon-120.png` (120×120) |
| Application home page | https://adpocket-app.web.app |
| Privacy policy | https://adpocket-app.web.app/privacy |
| Terms of service | (optional, leave empty) |
| Authorized domains | `adpocket-app.web.app` |
| Developer contact | robtdyn@gmail.com |

The homepage domain must be verified in Google Search Console by an owner or
editor of the Cloud project: add a "URL prefix" property for
`https://adpocket-app.web.app/` and verify it with the HTML file. The file is
deployed to `site/public/` and must stay there.

## Scope

`https://www.googleapis.com/auth/admob.readonly` (sensitive).

### Scope justification (Data Access → justification field)

AdPocket is a mobile app (Android, iOS) that shows app publishers their own
advertising statistics. When a user connects an AdMob account, the app uses
admob.readonly to call the AdMob API from the user's device. It calls
accounts.list to let the user pick their publisher account, accounts.apps.list
to name apps and offer an "App" filter, and networkReport:generate and
mediationReport:generate to show earnings, impressions, clicks, requests and
eCPM. This data appears on the overview screen, the reports screen and the
home-screen widget. The access is read-only and AdPocket never changes AdMob
settings. There is no AdPocket server. Google user data goes only from Google's
API to the user's device, is cached only on that device, and is never
transferred to the developer or third parties. No narrower scope gives access
to AdMob reports: admob.readonly is the minimum scope for the AdMob API's
report methods.

### How the data is used (short form)

Read-only display of the user's own AdMob earnings and reports inside the app
and its home-screen widget. No storage off the device, no sharing, no ads, no
AI training.

## Demo video (YouTube, unlisted, English UI)

Google needs to see the full OAuth flow and where the data is used. Record on
the Android emulator with the app language set to English:

1. Open AdPocket → Settings → Accounts → Add account. Show the
   "Connect AdMob with Google" button and open it.
2. Tap "Sign in with Google". Show the Google account picker and the consent
   screen. The app name "AdPocket" and the AdMob permission must be readable;
   pause on the consent screen for 2–3 seconds.
3. Grant access. If the account has several AdMob accounts, pick one.
4. Show the Overview: today's earnings, yesterday, 7 days, month, chart and
   top apps, all from AdMob.
5. Open Reports: choose "AdMob Network", group by date and app, run the report,
   then switch to "Mediation".
6. Show the home-screen widget with the AdMob numbers.
7. Settings → Accounts → menu → "Remove account", which revokes access. Then
   show that AdPocket is gone from https://myaccount.google.com/permissions.

About 2–3 minutes, no sound needed.

## Test users while in review

Testing mode keeps working during review for the accounts under Audience →
Test users (max 100). Their grants expire after 7 days.
