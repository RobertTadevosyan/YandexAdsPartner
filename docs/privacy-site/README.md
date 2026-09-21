# Privacy policy site

Ready-to-publish static site with one folder per application id, so several
apps can share one repository (for example `github.com/<you>/privacy` published
with GitHub Pages):

```
index.html                     # list of apps
app.adpocket.yan/index.html    # AdPocket — RU + EN, self-contained
```

Publish: copy this folder to the root of a public repository, enable Pages
(branch `main`, folder `/`), and the policy becomes
`https://<you>.github.io/privacy/app.adpocket.yan/`. That URL is referenced by
`privacyPolicyUrl` in `lib/screens/settings_screen.dart` and must be entered in
Google Play Console (App content → Privacy policy) and App Store Connect
(App Privacy → Privacy Policy URL).

Keep the "Last updated" date in the page current whenever the data practices change.
