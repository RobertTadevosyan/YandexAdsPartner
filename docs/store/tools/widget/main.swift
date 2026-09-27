// Renders the iOS widget (MediumView) with store demo figures to PNG, for the
// App Store "widget" screenshot and the promo video. Built together with the
// real ios/AdPocketWidget/Views.swift by render.sh, so the image is the widget.
import SwiftUI
import AppKit

// DATE: set the day shown in the widget to the day the app screenshots were captured.
struct WidgetSnapshot: Equatable {
    var title: String; var revenue: String; var delta: String
    var deltaPositive: Bool; var deltaNeutral: Bool
    var stats: String; var updated: String; var spark: [Double]; var signedIn: Bool
}

@MainActor
func render(_ s: WidgetSnapshot, to path: String) {
    let view = MediumView(s: s)
        .padding(16)
        .frame(width: 364, height: 170)
        .background(Brand.navy)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, .dark)
    let r = ImageRenderer(content: view)
    r.scale = 3
    r.isOpaque = false
    guard let img = r.nsImage, let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("render failed")
    }
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote", path, rep.pixelsWide, "x", rep.pixelsHigh)
}

@main
struct Main {
  @MainActor static func main() {
let spark: [Double] = [4990, 5040, 5620, 5810, 5760, 6185.36, 5432]
let out = CommandLine.arguments[1]

    render(WidgetSnapshot(title: "Today · \(CommandLine.arguments[2])", revenue: "5,432.00 RUB",
                          delta: "-12.2% vs yesterday · 6,185.36 RUB", deltaPositive: false, deltaNeutral: false,
                          stats: "Impressions 42,784 · Clicks 461 · eCPM 126.96", updated: "09:41",
                          spark: spark, signedIn: true), to: out + "/en_ioswidget.png")
    render(WidgetSnapshot(title: "Сегодня · \(CommandLine.arguments[3])", revenue: "5 432,00 RUB",
                          delta: "-12,2% к вчера · 6 185,36 RUB", deltaPositive: false, deltaNeutral: false,
                          stats: "Показы 42 784 · Клики 461 · eCPM 126,96", updated: "09:41",
                          spark: spark, signedIn: true), to: out + "/ru_ioswidget.png")

  }
}
