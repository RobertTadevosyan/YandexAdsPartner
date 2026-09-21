import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: WidgetStore.load() ?? .placeholder))
    }

    /// Shows what the app last wrote, then tries to fetch fresh numbers
    /// itself. WidgetKit calls this on its own budget (roughly every 30 min).
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let stored = WidgetStore.load()
            let fresh = await YandexFetcher.refreshStore()
            let snapshot = fresh ?? WidgetStore.load() ?? stored ?? .signedOut(lang: WidgetStore.lang)
            let next = Date().addingTimeInterval(30 * 60)
            completion(Timeline(entries: [Entry(date: Date(), snapshot: snapshot)], policy: .after(next)))
        }
    }
}

@available(iOS 17.0, *)
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh AdPocket"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetStore.flag("…")
        WidgetCenter.shared.reloadTimelines(ofKind: Shared.widgetKind)
        _ = await YandexFetcher.refreshStore()
        WidgetCenter.shared.reloadTimelines(ofKind: Shared.widgetKind)
        return .result()
    }
}

struct AdPocketWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var refreshButton: AnyView? {
        if #available(iOS 17.0, *) {
            return AnyView(
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Brand.amber)
                }
                .buttonStyle(.plain)
            )
        }
        return nil
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallView(s: entry.snapshot)
            case .accessoryRectangular:
                RectangularView(s: entry.snapshot)
            case .accessoryInline:
                InlineView(s: entry.snapshot)
            default:
                MediumView(s: entry.snapshot, refresh: refreshButton)
            }
        }
        .widgetURL(Shared.openURL)
        .modifier(WidgetBackground(isAccessory: family == .accessoryRectangular || family == .accessoryInline))
    }
}

struct WidgetBackground: ViewModifier {
    let isAccessory: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) {
                if !isAccessory { Brand.navy }
            }
        } else {
            content.padding(isAccessory ? 0 : 14).background(isAccessory ? Color.clear : Brand.navy)
        }
    }
}

@main
struct AdPocketWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Shared.widgetKind, provider: Provider()) { entry in
            AdPocketWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AdPocket")
        .description(WidgetStore.lang == "ru"
            ? "Доход за сегодня, изменение к вчера и тренд за 7 дней."
            : "Today's revenue, change vs yesterday and a 7-day trend.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
