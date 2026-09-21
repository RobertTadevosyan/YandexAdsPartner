import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let scale = CGFloat(size) / 108.0
let amber = CGColor(red: 1.0, green: 0.7569, blue: 0.0275, alpha: 1)   // #FFC107
let navy  = CGColor(red: 0.0627, green: 0.1569, blue: 0.2510, alpha: 1) // #102840
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

func render(path: String, background: CGColor?, barColor: CGColor, lineColor: CGColor) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    if let bg = background {
        ctx.setFillColor(bg)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
    // Flip to SVG-style coordinates (origin top-left, y down) in 108-unit space.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.setAllowsAntialiasing(true)

    // Bars
    ctx.setFillColor(barColor)
    for (x, y, h) in [(27.0, 61.0, 24.0), (47.0, 49.0, 36.0), (67.0, 37.0, 48.0)] {
        let r = CGPath(roundedRect: CGRect(x: x, y: y, width: 13, height: h), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
        ctx.addPath(r); ctx.fillPath()
    }
    // Trend line + arrow head
    ctx.setStrokeColor(lineColor)
    ctx.setLineWidth(5.5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 29, y: 42)); ctx.addLine(to: CGPoint(x: 47, y: 31))
    ctx.addLine(to: CGPoint(x: 59, y: 38)); ctx.addLine(to: CGPoint(x: 80, y: 22))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 69, y: 21)); ctx.addLine(to: CGPoint(x: 81, y: 21)); ctx.addLine(to: CGPoint(x: 81, y: 33))
    ctx.strokePath()

    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

render(path: "icon_flat.png", background: navy, barColor: amber, lineColor: white)
render(path: "icon_foreground.png", background: nil, barColor: amber, lineColor: white)
render(path: "icon_monochrome.png", background: nil, barColor: white, lineColor: white)
print("rendered")
