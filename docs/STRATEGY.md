# AdPocket — Market research and strategy (21 September 2026)

Questions answered here: are there alternatives to a mobile YAN partner app, how big is the audience,
should and can the app be monetised, is it a product or a portfolio piece, would Yandex care,
can it be published on Google Play and the App Store legally, and are a web version or a Telegram
bot worth building.

## 1. What exists today

| Product | Platform | Status | Notes |
|---|---|---|---|
| **Yandex Advertising Network** (`ru.yandex.partners`), official | Android | **Discontinued** — Google Play returns 404; AppBrain archive shows ~22 000 lifetime installs | Yandex no longer ships a mobile app for partners. |
| **@YANStatisticsBot**, official Telegram bot | Telegram | Live | Scheduled digests only (3×/week, weekly or monthly): balance, income for the month and yesterday, payout notices, anomaly alerts. No on‑demand queries. Configured from the web interface. |
| **Данные РСЯ / Data YAN** (inettools) | Android (Google Play, RuStore) | Live, v2.2.18 May 2026 | RuStore: 4.8★ (54 ratings), "1 000+" installs. Multi‑account, Yandex Distribution income, themes. Reviews ask for daily impressions, app names in stats, auto‑refresh. |
| **РСЯ.Сводка** (svector) | Android (Google Play, RuStore) | Live, v2.1.1 | RuStore: 4.8★, ≤1 000 installs. Widget, multi‑account, covers Yandex Games income. States it is unofficial. |
| **Доход РСЯ** (mrozon) | Android (Google Play, RuStore) | Live, v1.1.6 Aug 2025 | 4.1★ (RuStore), 3.9 on Play (11 reviews), ≤1 000 installs. Widget; several "critical error" fixes in changelog. |
| **Я Партнер** | iOS | Dead (2017) | Community‑built iOS client; praised, then stopped working after ~4 months (users suspected Yandex cut its access). Cautionary tale about API dependence. |

Findings:
- **No iOS app exists** for YAN partner statistics. AdPocket would be the only one.
- Every competitor is free, Android‑only, has hundreds to low thousands of installs, and shows no monetisation.
- Feature gaps in competitors that AdPocket already covers: report builder with filters, sortable tables, CSV export, secure token storage, app lock, iOS widget, bilingual UI.
- Feature gaps in **AdPocket** relative to them: multiple accounts, Yandex Distribution / Yandex Games income, other statistics levels (RTB sites, Mobile Mediation, DSP/SSP), auto‑refresh cadence in the app.

## 2. Audience size

Yandex does not publish the number of partner sites. Published figures:
- 400 000+ advertisers in the auction (partner.yandex.ru).
- 15 000+ mobile apps connected to YAN (yandex.com/inapp).
- 24 000 Telegram/blog channels monetised through YAN; 5.3 bn RUB paid to them over three years, 1.7 bn RUB in 2024 alone (RB.ru, Forbes, July 2026).
- Yandex group advertising revenue 449 bn RUB in 2025 (+13.5%); "new formats" including YAN for bloggers grew 4.4× (Yandex Q4 2025 results).

Realistic addressable audience for a mobile stats app: tens of thousands of active partners, of whom the
Telegram‑channel cohort is the fastest growing and the most mobile‑first. Competitor install counts
(≈1–3 k each) suggest a first‑year ceiling of roughly 5–20 k installs if AdPocket is on RuStore,
Google Play and the App Store and gets one mention in the YAN community.

## 3. Legal position

Source: Yandex Partner Interface API user agreement, https://yandex.ru/legal/partner_interface_api/

- **3.2** — the API may be used *only inside internet services / programs available for free, open use by an unlimited circle of persons.* A paid app, a subscription, or a paywalled feature set would breach this. A free app is explicitly the permitted form.
- **3.3** — data may be used only within the functionality the service provides (display and analysis of the partner's own statistics is fine; reselling or pooling data across users is not).
- **5.7** — the API key must not be obtained for, transferred to, or provided to third parties. AdPocket satisfies this because each user enters their own token and it never leaves the device. **Any server‑side component (web proxy, Telegram bot) that receives users' tokens would be the app operator holding third‑party keys — a direct conflict with 5.7.**
- **6.1** — Yandex may suspend access at any time without notice. This is the same risk that killed "Я Партнер" in 2017; mitigation is low request volume, no abuse, and a visible contact channel.
- Nothing in the agreement forbids showing ads inside a free app.

Trademarks (https://yandex.ru/company/rules/logotype): the Yandex logo may not be used as part of another
logo or in a way that implies cooperation. The rename to **AdPocket** with its own icon is the right
call; "for Yandex Advertising Network" may be used descriptively in the store subtitle, and the listing
and About screen should carry "Not an official Yandex application" (competitors do the same).

Stores:
- **Google Play**: free apps without Play Billing are unaffected by the December 2024 suspension of seller services for Russian bank accounts; impersonation policy is satisfied by own name, own icon and the disclaimer. A privacy policy URL and the Data‑safety form are required (the app stores the token locally and talks only to Yandex).
- **App Store**: same naming rules (Guideline 5.2 / 4.1); needs an Apple Developer account, which is hard to obtain or pay for from Russia but routine elsewhere.
- **RuStore**: where all three competitors live and where Russian users actually install from. Free listing, no payment restrictions. Should be launched **together with** Google Play.

Verdict: publishing on all three stores is legal and consistent with the API terms **as long as the app stays free and keeps tokens on‑device.**

## 4. Monetisation

Constraints: clause 3.2 rules out paid tiers and subscriptions regardless of store policy; Play Billing is
unavailable for Russian bank accounts anyway. That leaves ads and sponsorship.

Back‑of‑envelope for ads (RU eCPM per App2top / Yandex data, Q2 2024: banner ≈ $0.5 Android / $0.7 iOS,
interstitial ≈ $4.5 / $10.5):

| Scenario | MAU | Banner impressions / month | Revenue / month |
|---|---|---|---|
| Year 1 realistic | 3 000 | ~120 000 | ≈ $60–80 (5–7 k RUB) |
| Optimistic | 15 000 | ~600 000 | ≈ $300–400 |

Interstitials would multiply that but the audience consists of publishers who know exactly what they are
looking at; intrusive ads would cost ratings and trust faster than they earn. Conclusion:

- **Do not add ads at launch.** Ship free, no ads, and measure MAU for three months.
- If MAU passes ~10 k, a single non‑intrusive native banner via the Yandex Mobile Ads SDK on the Reports screen is the only format worth trying (and it doubles as a demo that the developer eats their own cooking).
- Sponsorship is more realistic than ads at this scale: ad‑tech blogs, mediation vendors and SEO tool makers pay for placements in Russian webmaster communities. An "About" screen sponsor slot or a newsletter mention is worth 5–20 k RUB/month once there is an audience.
- A "Support the developer" link (Boosty / CloudTips) costs nothing; expect pocket money.

**Honest framing:** AdPocket is a portfolio and reputation project with a small, loyal audience, not a
revenue source. Its value is (a) a public, well‑engineered Flutter app with real API integration, widgets
on both platforms, secure storage and tests; (b) standing in the YAN partner community; (c) optionality if
Yandex or an ad‑tech company wants the team or the product.

## 5. Would Yandex care?

Yandex retired its own partner app and now invests in Telegram (digest bot, AI bot for channel owners)
rather than mobile. A polished third‑party app fills a gap they chose not to fill. Plausible outcomes,
most to least likely:
1. A mention in the YAN partner Telegram channel / digest if the community asks for it.
2. Nothing, but the API keeps working (the common case).
3. Access restrictions if usage looks abusive (avoid: keep the two‑request dashboard, 30‑minute widget cadence, no scraping).
4. Interest in the author (hiring) or the product — rare, but the app is a credible portfolio artefact for exactly that conversation.

Action: after launch, write to YAN partner support and the @yandex_partners channel admins with a short
note and store links; ask to be listed among "useful tools". Publish a Habr / vc.ru write‑up.

## 6. Web version — no

partner.yandex.ru is usable on desktop; the reviews complain about payouts, moderation and support, not
the interface. A web client would also need a backend proxy because the API has no CORS headers, which
means holding users' tokens on a server (clause 5.7) and running infrastructure for zero revenue.
If a bigger screen is ever wanted, the existing macOS / Windows / Linux targets of the Flutter project
are the cheaper and compliant route.

## 7. Telegram bot — no, but replicate its value in the app

Yandex already runs a digest bot. A third‑party bot would have to receive users' OAuth tokens and store
them server‑side, which conflicts with 5.7 and is a security liability nobody should accept for a stats
toy. A Telegram Mini App keeps the token client‑side but hits the same CORS wall. Instead, deliver the bot's
value inside the app with **local notifications**: daily summary at a chosen time, "yesterday vs the day
before" alerts, revenue‑drop / zero‑impressions anomaly alerts, payout‑day reminder. No server, no token
sharing, works on both platforms.

## 8. Plan

### Phase 0 — Ship (next 2 weeks)
1. Squash the branch into one commit, open the PR, let CI run, merge.
2. Release signing (upload keystore via `key.properties`, out of git), `flutter build appbundle`.
3. Privacy policy page (GitHub Pages), Data‑safety answers, "Not an official Yandex application" in listing and About.
4. Listings: **RuStore + Google Play** now; **App Store** when an Apple account is available. Title
   "AdPocket: YAN partner stats" with the disclaimer; screenshots already in the repo.
5. Support email + GitHub issues link in About.

### Phase 1 — Parity and stickiness (weeks 3–8)
1. **Multiple accounts** (every competitor has it; publishers often run several).
2. **Statistics levels**: read all levels from the tree and let the user switch (RTB sites, mobile mediation, DSP/SSP); today only the first level is used.
3. **Local notifications**: daily summary, anomaly alerts, payout reminder (replaces the Telegram bot idea).
4. **Yandex Distribution / Yandex Games income** if the Partner API exposes them (check `stat_type` list per account).
5. Home‑screen widget polish: Android resizable sizes, iOS lock‑screen tuning.
6. Bug‑fix pass from store reviews; keep the golden tests green.

### Phase 2 — Distribution (weeks 6–12)
1. Posts: searchengines.guru monetisation forum, YAN partner chat, Habr / vc.ru case study ("mobile client for YAN with widgets on both platforms").
2. Ask YAN support / channel admins for a "useful tools" mention.
3. Open‑source hygiene: README with architecture, contribution guide, issue templates (already MIT).

### Phase 3 — Decide (month 4)
Review MAU, retention, ratings. Then choose one:
- ≥10 k MAU → try one native banner or a sponsor slot;
- otherwise keep it free and treat it as the portfolio piece it is.

### KPIs
Installs by store; MAU; D30 retention; widget adoption (% of MAU with a widget); average rating ≥ 4.6;
one Yandex/community mention; zero token‑related support tickets.

### Risks
| Risk | Mitigation |
|---|---|
| API access revoked (6.1) | Low request volume, contact channel, graceful "API unavailable" state, no scraping. |
| API changes / new stat levels | Catalogue is fetched from the tree at runtime; add a level selector. |
| Competitor parity (multi‑account) | Phase 1 item 1. |
| Store account problems (Apple) | Launch on RuStore + Google Play first. |
| Trademark complaint | Own name/icon, descriptive mention only, disclaimer. |

## Sources
- Yandex Partner Interface API agreement — https://yandex.ru/legal/partner_interface_api/
- Yandex logo rules — https://yandex.ru/company/rules/logotype
- Official Telegram digest bot — https://b2b.yandex.ru/adv/news/informatsiya-o-statistike-i-dokhode-v-rsya-teper-v-telegram
- Official app archive (AppBrain) — https://www.appbrain.com/app/yandex-advertising-network/ru.yandex.partners
- Данные РСЯ — https://www.rustore.ru/catalog/app/net.inettools.rsya ; https://play.google.com/store/apps/details?id=net.inettools.rsya
- РСЯ.Сводка — https://www.rustore.ru/catalog/app/com.svector.adbrief
- Доход РСЯ — https://www.rustore.ru/catalog/app/com.mrozon.rewardyas
- "Я Партнер" thread — https://searchengines.guru/ru/forum/961436
- YAN scale — https://partner.yandex.ru/ ; https://yandex.com/inapp/ru ; https://rb.ru/news/reklamnaya-set-yandeksa-vyplatila-blogeram-53-mlrd-za-tri-goda-k-platforme-podklyuchilis-24-tys-avtorov/ ; https://yandex.ru/company/news/17-02-2026
- Google Play seller suspension for Russian accounts — https://support.google.com/googleplay/android-developer/answer/15685001
- Google Play impersonation policy — https://support.google.com/googleplay/android-developer/answer/9888374
- RU eCPM benchmarks — https://app2top.ru/news/analitika-v-rossii-ecpm-voznagrazhdayushhej-reklamy-v-mobil-ny-h-igrah-na-ios-prevy-sila-11-dollarov-221499.html
- partner.yandex.ru reviews — https://otzovik.com/reviews/partner_yandex_ru-reklamnaya_set_yandeksa/
