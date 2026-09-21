import SwiftUI

enum Brand {
    static let amber = Color(red: 1.0, green: 0.7569, blue: 0.0275)
    static let navy = Color(red: 0.0627, green: 0.1569, blue: 0.2510)
    static let muted = Color(red: 0.72, green: 0.77, blue: 0.84)
    static let positive = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let negative = Color(red: 1.0, green: 0.35, blue: 0.37)
}

struct Sparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.000001)
            let n = max(values.count, 2)
            let dx = geo.size.width / CGFloat(n - 1)
            let h = geo.size.height
            let pts: [CGPoint] = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * dx, y: h - 4 - CGFloat(v / maxV) * (h - 8))
            }
            ZStack {
                if pts.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        p.addLine(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Brand.amber.opacity(0.4), Brand.amber.opacity(0)], startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Brand.amber, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    Circle().fill(Brand.amber).frame(width: 6, height: 6).position(pts.last!)
                }
            }
        }
    }
}

struct DeltaText: View {
    let s: WidgetSnapshot
    var body: some View {
        Text(s.delta)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(s.deltaNeutral ? Brand.muted : (s.deltaPositive ? Brand.positive : Brand.negative))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

struct SmallView: View {
    let s: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.title).font(.system(size: 11, weight: .bold)).foregroundColor(Brand.amber).lineLimit(1)
                Spacer(minLength: 4)
                Text(s.updated).font(.system(size: 10)).foregroundColor(Brand.muted.opacity(0.7))
            }
            Text(s.revenue)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            DeltaText(s: s)
            Spacer(minLength: 0)
            if s.signedIn && !s.spark.isEmpty {
                Sparkline(values: s.spark).frame(height: 28)
            }
        }
    }
}

struct MediumView: View {
    let s: WidgetSnapshot
    var refresh: AnyView? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center) {
                Text(s.title).font(.system(size: 12, weight: .bold)).foregroundColor(Brand.amber).lineLimit(1)
                Spacer(minLength: 4)
                Text(s.updated).font(.system(size: 11)).foregroundColor(Brand.muted.opacity(0.7))
                if let r = refresh { r }
            }
            Text(s.revenue)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            DeltaText(s: s)
            if s.signedIn && !s.spark.isEmpty {
                Sparkline(values: s.spark).frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            Text(s.stats).font(.system(size: 11)).foregroundColor(Brand.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

struct RectangularView: View {
    let s: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(s.signedIn ? s.title : "AdPocket").font(.system(size: 11, weight: .semibold)).lineLimit(1)
            Text(s.revenue).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(s.signedIn ? s.delta : L10n.signedOut(WidgetStore.lang)).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct InlineView: View {
    let s: WidgetSnapshot
    var body: some View {
        if s.signedIn {
            Text("AdPocket \(s.revenue) \(s.delta.split(separator: " ").first.map(String.init) ?? "")")
        } else {
            Text("AdPocket · \(L10n.signedOut(WidgetStore.lang))")
        }
    }
}
