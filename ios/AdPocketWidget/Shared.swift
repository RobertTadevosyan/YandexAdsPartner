import Foundation

/// Values shared between the Flutter app and the widget through the App Group.
/// The same keys are written by the Android widget code path, so both
/// platforms render identical text.
enum Shared {
    static let appGroup = "group.app.adpocket.yan"
    static let widgetKind = "AdPocketWidget"
    static let keychainService = "flutter_secure_storage_service"
    static let tokenAccount = "oauth_token"
    static let openURL = URL(string: "adpocket://open")!
}

struct WidgetSnapshot: Equatable {
    var title: String
    var revenue: String
    var delta: String
    var deltaPositive: Bool
    var deltaNeutral: Bool
    var stats: String
    var updated: String
    var spark: [Double]
    var signedIn: Bool

    static func signedOut(lang: String) -> WidgetSnapshot {
        WidgetSnapshot(
            title: "AdPocket",
            revenue: "—",
            delta: L10n.signedOut(lang),
            deltaPositive: true,
            deltaNeutral: true,
            stats: "",
            updated: "",
            spark: [],
            signedIn: false
        )
    }

    static let placeholder = WidgetSnapshot(
        title: "Today · 21 Sep",
        revenue: "41.35 RUB",
        delta: "+38.9% vs yesterday · 29.77 RUB",
        deltaPositive: true,
        deltaNeutral: false,
        stats: "Impressions 176 · Clicks 4 · eCPM 234.94",
        updated: "09:30",
        spark: [12, 30, 48, 42, 61, 45, 41],
        signedIn: true
    )
}

/// Reads and writes the snapshot in the App Group defaults.
enum WidgetStore {
    static var defaults: UserDefaults? { UserDefaults(suiteName: Shared.appGroup) }

    static var lang: String { defaults?.string(forKey: "lang") ?? (Locale.current.language.languageCode?.identifier == "ru" ? "ru" : "en") }
    static var currency: String { defaults?.string(forKey: "currency") ?? "RUB" }
    static var vat: Bool { defaults?.bool(forKey: "vat") ?? false }

    static func load() -> WidgetSnapshot? {
        guard let d = defaults, let revenue = d.string(forKey: "revenue") else { return nil }
        let signedIn = d.object(forKey: "signed_in") as? Bool ?? (revenue != "—")
        if !signedIn { return .signedOut(lang: lang) }
        let spark = (d.string(forKey: "spark") ?? "")
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return WidgetSnapshot(
            title: d.string(forKey: "title") ?? "AdPocket",
            revenue: revenue,
            delta: d.string(forKey: "delta") ?? "",
            deltaPositive: d.object(forKey: "delta_positive") as? Bool ?? true,
            deltaNeutral: d.object(forKey: "delta_neutral") as? Bool ?? false,
            stats: d.string(forKey: "stats") ?? "",
            updated: d.string(forKey: "updated") ?? "",
            spark: spark,
            signedIn: true
        )
    }

    static func save(_ s: WidgetSnapshot) {
        guard let d = defaults else { return }
        d.set(s.title, forKey: "title")
        d.set(s.revenue, forKey: "revenue")
        d.set(s.delta, forKey: "delta")
        d.set(s.deltaPositive, forKey: "delta_positive")
        d.set(s.deltaNeutral, forKey: "delta_neutral")
        d.set(s.stats, forKey: "stats")
        d.set(s.updated, forKey: "updated")
        d.set(s.spark.map { String($0) }.joined(separator: ","), forKey: "spark")
        d.set(s.signedIn, forKey: "signed_in")
    }

    static func flag(_ text: String) {
        defaults?.set(text, forKey: "updated")
    }
}

/// The handful of strings the widget needs, mirroring lib/core/strings.dart.
enum L10n {
    static func today(_ lang: String) -> String { lang == "ru" ? "Сегодня" : "Today" }
    static func vsYesterday(_ lang: String) -> String { lang == "ru" ? "к вчера" : "vs yesterday" }
    static func shows(_ lang: String) -> String { lang == "ru" ? "Показы" : "Impressions" }
    static func clicks(_ lang: String) -> String { lang == "ru" ? "Клики" : "Clicks" }
    static func signedOut(_ lang: String) -> String { lang == "ru" ? "Откройте приложение и войдите" : "Open the app and sign in" }
    static func offline(_ lang: String) -> String { lang == "ru" ? "нет сети" : "offline" }
    static func error(_ lang: String) -> String { lang == "ru" ? "ошибка" : "error" }
    static func refresh(_ lang: String) -> String { lang == "ru" ? "Обновить" : "Refresh" }
}

/// Number and date formatting, mirroring lib/core/formatters.dart.
enum Fmt {
    static func locale(_ lang: String) -> Locale { Locale(identifier: lang == "ru" ? "ru_RU" : "en_US") }

    private static func number(_ v: Double, lang: String, fraction: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale(lang)
        f.numberStyle = .decimal
        f.minimumFractionDigits = fraction
        f.maximumFractionDigits = fraction
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    /// Full below one million, compact ("12.3M", "2.49B") above — same rule as the app tiles.
    static func money(_ v: Double, lang: String, currency: String?) -> String {
        let text: String
        let a = abs(v)
        if a >= 1_000_000_000 { text = number(v / 1_000_000_000, lang: lang, fraction: 2) + "B" }
        else if a >= 1_000_000 { text = number(v / 1_000_000, lang: lang, fraction: 1) + "M" }
        else { text = number(v, lang: lang, fraction: 2) }
        guard let c = currency, !c.isEmpty else { return text }
        return "\(text) \(c)"
    }

    static func count(_ v: Double, lang: String) -> String {
        let a = abs(v)
        if a >= 1_000_000_000 { return number(v / 1_000_000_000, lang: lang, fraction: 2) + "B" }
        if a >= 1_000_000 { return number(v / 1_000_000, lang: lang, fraction: 1) + "M" }
        return number(v, lang: lang, fraction: 0)
    }

    static func delta(_ current: Double, _ previous: Double, lang: String) -> String? {
        guard previous != 0 else { return nil }
        let change = (current - previous) / previous * 100
        let sign = change > 0 ? "+" : ""
        return sign + number(change, lang: lang, fraction: 1) + "%"
    }

    static func dayMonth(_ d: Date, lang: String) -> String {
        let f = DateFormatter()
        f.locale = locale(lang)
        f.dateFormat = "d MMM" // same order as the app on both languages
        return f.string(from: d)
    }

    static func time(_ d: Date, lang: String) -> String {
        let f = DateFormatter()
        f.locale = locale(lang)
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    static let moscow = TimeZone(identifier: "Europe/Moscow")!

    /// Calendar date in Moscow time, as the Statistics API reports days.
    static func moscowDay(_ d: Date = Date()) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = moscow
        return cal.dateComponents([.year, .month, .day], from: d)
    }

    static func isoDay(_ c: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
