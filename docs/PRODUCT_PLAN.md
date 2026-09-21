# AdPocket (formerly YaAdsPartner) — Product Plan (September 2026)

Core idea: a mobile companion for the **partner.yandex.ru** dashboard. A publisher opens the app
and in a few seconds sees how their sites and apps are earning today, spots trends, drills into
any report the web dashboard can build, and manages mobile ad units — all from a phone.

## 1. Audit of the current app (v1.0.0)

### Bugs found
| # | Severity | Issue | Root cause |
|---|----------|-------|------------|
| 1 | P0 | All Russian labels rendered as `Ð¡Ð°Ð¿Ñ...` (mojibake) | API answers `content-type: application/json` **without a charset**, so `http.Response.body` decodes bytes as Latin‑1. Fix: decode `bodyBytes` as UTF‑8. |
| 2 | P0 | Release build cannot reach the network | `INTERNET` permission only declared in debug/profile manifests. |
| 3 | P1 | Report title shows raw enum `RequestPeriodPreset(preset=TODAY)` | API's `report_title` is not user‑friendly; use `periods` to build a human title. |
| 4 | P1 | "Summary" cards sum every column, including eCPM / fill‑rate | Ratios cannot be summed. The API already returns `totals`; use them. |
| 5 | P1 | Counts shown as `96.00`, money without currency, percents without `%` | No unit‑aware formatting. `measures` metadata has `unit`/`currency`. |
| 6 | P1 | No way to change or remove the token once saved; invalid token = silent failure | No settings screen, no auth error handling. |
| 7 | P2 | Typo "Текущая неделья"; all UI text is Russian only | API supports `lang=en`; app should be bilingual. |
| 8 | P2 | 50 items are silently appended by scroll; totals not visible | Infinite scroll without a "Load more" affordance. |

### What is missing versus the web dashboard
- An at‑a‑glance **overview** (today / yesterday / month, deltas, trend chart, top apps).
- **Filters** (by app, block, OS, country, …) — the tree already returns 30 filter fields.
- **Currency / VAT / language** controls (all supported by the API).
- **Saved report presets** and **export/share**.
- **Mobile ad units** (list, edit caption / CPM floor, archive) via the Inventory API.

## 2. Market review (what similar apps do well)
Third‑party dashboards for AdMob (AdDash, Dash, App Revenue Console, AdMob Earnings) and Appodeal
(Appodeal Revenue Statistics, Ads Analytics) converge on the same feature set:
1. Earnings KPIs for today / yesterday / 7d / month with % change versus the previous period.
2. A revenue trend chart that is the first thing on screen.
3. Breakdown by app and by country, sortable by revenue.
4. Currency selection, pull‑to‑refresh, last‑refresh timestamp, offline cache of the last data.
5. Secure token entry with in‑app instructions on where to get it.

YaAdsPartner can match these with the public Statistics API alone, and go further with ad‑unit
management, which none of the AdMob helper apps can offer.

## 3. Official API capabilities used
Source: https://yandex.ru/dev/partner-statistics/doc/en/ (Statistics API + Advertising Inventory Management API).

| Capability | Endpoint / parameter | Used for |
|---|---|---|
| Field tree | `GET /api/statistics2/tree.json?lang=&stat_type=` | metric / grouping / filter catalogue |
| Report | `GET /api/statistics2/get.json` | dashboard + reports |
| Presets | `period=today|yesterday|thisweek|thismonth|lastmonth|7days|30days|90days|180days|365days|thisyear` or two `period=YYYY-MM-DD` | period chips |
| Grouping | `dimension_field=date|day…`, `entity_field=page_caption…` | group‑by picker |
| Filtering | `filter=["page_id","=","123"]`, `IN`, `LIKE`, `AND`/`OR` | filter sheet |
| Sorting | `order_by=[{"field":"partner_wo_nds","dir":"desc"}]` | top apps, table sort |
| Paging | `limits={"limit":50,"offset":0}`, `is_last_page`, `total_rows` | Load more |
| Money | `currency=RUB|USD|EUR|…`, `vat=true|false` | settings |
| Totals | `data.totals`, `data.measures[*].unit/currency` | KPI cards, correct formatting |
| Ad units | `GET/POST/PATCH/DELETE https://partner.yandex.ru/api/mobile/adunit` (separate token, scope `pi:access-ad-inventory-api`, max 6 concurrent requests) | Ad Units tab |

Verified against the live API on 2026‑09‑20 (tree, report, filters, currency, ordering, `thisweek`).
The Inventory API returns 401 for a statistics token — it needs its own token, so the app stores two.

## 4. Decisions
1. **Four tabs**: Dashboard · Reports · Ad units · Settings. Dashboard is the default tab.
2. **Request budget**: the dashboard costs 2 requests (one 90‑day daily series, one "top apps"),
   cached in memory and on disk; pull‑to‑refresh re‑fetches. Reports fetch only on "Apply" or "Load more".
3. **Bilingual (RU/EN)**: UI strings and API `lang` follow one setting; default follows device locale.
4. **Formatting by unit**: `count` → integer with separators, `money` → 2 decimals + currency code,
   `percent` → 2 decimals + `%`. Dates use locale format.
5. **Filters MVP**: one or more conditions joined with AND; operators `=`, `<>`, `LIKE`, `IN` for text /
   id fields, value pickers for `tree` and `boolean` fields.
6. **Ad units**: list + detail + edit (caption, CPM floor strategy) + archive with confirmation.
   Creation is deferred (needs app IDs the API cannot list); shown as "beta" and gated by a second token.
7. **Theme**: keep the navy/amber brand; add a light variant and a system/light/dark switch.
8. **No heavy state library**: `provider` for settings only; screens own their state.

## 5. Roadmap
### Release 1.1 — this branch
- [x] Fix UTF‑8 decoding, INTERNET permission, report title, totals, formatting, typo.
- [x] Onboarding screen with token instructions and validation; Settings with token management.
- [x] Dashboard: KPI cards with deltas, 30‑day revenue chart, top apps for a selectable period.
- [x] Reports: period chips, metric / grouping / filter bottom sheets, totals strip, chart or table,
      Load more, saved presets, share as CSV.
- [x] Ad units tab (Inventory API, separate token).
- [x] Settings: language, currency, VAT, theme.
- [x] Tests for decoding, formatting, models and the token flow.
- [x] Tokens in Keystore / Keychain (`flutter_secure_storage`) with migration from preferences; optional biometric / PIN app lock.

### Release 1.2 — next
- Country breakdown card on the dashboard (`geo|country`).
- [x] Android home‑screen widget (today's revenue, delta, 7‑day sparkline; 30‑minute background refresh, user‑controlled; refresh button on the widget).
- [x] iOS WidgetKit widget (small / medium / Lock Screen) sharing data via App Group, self‑refreshing from the API with the token from the shared keychain group. Verified on the iPhone 16 simulator; real‑device run needs Apple signing.
- [x] Local notifications: daily and monthly summaries, revenue‑drop and zero‑impressions alerts.
- Create ad units (needs a manual app‑ID input).
- [x] Report types: Main, Mobile Mediation (`stat_type=mm`), SSP, DSP with per-type catalogues and defaults.
- [x] Multiple accounts with per-account cache, presets and widget data.

### Backlog / ideas
- Multiple accounts.
- Compare two periods side by side; anomaly highlighting in the table.
- Deep links to partner.yandex.ru pages for actions the API does not cover (payments, site moderation).
