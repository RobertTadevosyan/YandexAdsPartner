import Foundation
import Security

/// Fetches today's numbers straight from the Yandex Statistics API so the
/// widget stays fresh even when the app has not been opened for a while.
/// The token is read from the keychain access group shared with the app.
enum YandexFetcher {
    enum FetchError: Error { case noToken, unauthorized, http(Int), network, parse }

    static func token() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Shared.keychainService,
            kSecAttrAccount: Shared.tokenAccount,
            kSecAttrAccessGroup: Shared.appGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
        return value
    }

    /// One request: the last 30 days by day. Enough for today, yesterday and
    /// a 7-day sparkline.
    static func fetch(lang: String, currency: String, vat: Bool) async throws -> WidgetSnapshot {
        guard let token = token() else { throw FetchError.noToken }
        var comps = URLComponents(string: "https://partner2.yandex.ru/api/statistics2/get.json")!
        comps.queryItems = [
            .init(name: "lang", value: lang),
            .init(name: "stat_type", value: "main"),
            .init(name: "currency", value: currency),
            .init(name: "vat", value: vat ? "true" : "false"),
            .init(name: "period", value: "30days"),
            .init(name: "field", value: "partner_wo_nds"),
            .init(name: "field", value: "shows"),
            .init(name: "field", value: "clicks"),
            .init(name: "dimension_field", value: "date|day"),
            .init(name: "limits", value: "{\"limit\":100,\"offset\":0}"),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw FetchError.unauthorized }
        guard code == 200 else { throw FetchError.http(code) }
        return try parse(data, lang: lang, now: Date())
    }

    struct Day { let date: String; let revenue: Double; let shows: Double; let clicks: Double }

    static func parse(_ data: Data, lang: String, now: Date) throws -> WidgetSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["data"] as? [String: Any],
              let points = body["points"] as? [[String: Any]] else { throw FetchError.parse }
        var currency: String? = nil
        if let measures = body["measures"] as? [String: Any],
           let rev = measures["partner_wo_nds"] as? [String: Any] {
            currency = rev["currency"] as? String
        }
        var days: [String: Day] = [:]
        for p in points {
            guard let dims = p["dimensions"] as? [String: Any],
                  let m = (p["measures"] as? [[String: Any]])?.first else { continue }
            let rawDate: String
            if let arr = dims["date"] as? [Any], let first = arr.first { rawDate = "\(first)" }
            else if let s = dims["date"] as? String { rawDate = s }
            else { continue }
            let date = String(rawDate.prefix(10))
            days[date] = Day(
                date: date,
                revenue: (m["partner_wo_nds"] as? NSNumber)?.doubleValue ?? 0,
                shows: (m["shows"] as? NSNumber)?.doubleValue ?? 0,
                clicks: (m["clicks"] as? NSNumber)?.doubleValue ?? 0
            )
        }
        return build(days: days, currency: currency, lang: lang, now: now)
    }

    static func build(days: [String: Day], currency: String?, lang: String, now: Date) -> WidgetSnapshot {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Fmt.moscow
        let todayComps = Fmt.moscowDay(now)
        let todayDate = cal.date(from: todayComps) ?? now
        func day(offset: Int) -> Day? {
            let d = cal.date(byAdding: .day, value: -offset, to: todayDate) ?? todayDate
            return days[Fmt.isoDay(cal.dateComponents([.year, .month, .day], from: d))]
        }
        let today = day(offset: 0)
        let yesterday = day(offset: 1)
        let tr = today?.revenue ?? 0, yr = yesterday?.revenue ?? 0
        let ts = today?.shows ?? 0, tc = today?.clicks ?? 0
        let ecpm = ts == 0 ? 0 : tr / ts * 1000
        let deltaText = Fmt.delta(tr, yr, lang: lang)
        let spark = (0..<7).reversed().map { day(offset: $0)?.revenue ?? 0 }
        let vs = "\(L10n.vsYesterday(lang)) · \(Fmt.money(yr, lang: lang, currency: currency))"
        return WidgetSnapshot(
            title: "\(L10n.today(lang)) · \(Fmt.dayMonth(todayDate, lang: lang))",
            revenue: Fmt.money(tr, lang: lang, currency: currency),
            delta: deltaText == nil ? vs : "\(deltaText!) \(vs)",
            deltaPositive: tr >= yr,
            deltaNeutral: deltaText == nil,
            stats: "\(L10n.shows(lang)) \(Fmt.count(ts, lang: lang)) · \(L10n.clicks(lang)) \(Fmt.count(tc, lang: lang)) · eCPM \(Fmt.money(ecpm, lang: lang, currency: nil))",
            updated: Fmt.time(now, lang: lang),
            spark: spark,
            signedIn: true
        )
    }

    /// Refreshes the stored snapshot; on failure keeps the old values and
    /// flags the corner, exactly like the Android widget.
    static func refreshStore() async -> WidgetSnapshot? {
        let lang = WidgetStore.lang
        do {
            let fresh = try await fetch(lang: lang, currency: WidgetStore.currency, vat: WidgetStore.vat)
            WidgetStore.save(fresh)
            return fresh
        } catch FetchError.noToken, FetchError.unauthorized {
            let out = WidgetSnapshot.signedOut(lang: lang)
            WidgetStore.save(out)
            return out
        } catch FetchError.network {
            WidgetStore.flag(L10n.offline(lang))
            return nil
        } catch {
            WidgetStore.flag(L10n.error(lang))
            return nil
        }
    }
}
