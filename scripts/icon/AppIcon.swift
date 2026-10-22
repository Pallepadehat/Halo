// Draws Halo's app icon: a ring of warm-to-cool light over a dusk sky.
//
//   swift scripts/icon/AppIcon.swift ios  out.png   full bleed; iOS masks the corners itself
//   swift scripts/icon/AppIcon.swift mac  out.png   inside the macOS rounded square, with its shadow
//
// scripts/make-icons.sh runs both and fills the asset catalogs.

import AppKit
import CoreImage

let arguments = CommandLine.arguments
guard arguments.count == 3, ["ios", "mac"].contains(arguments[1]) else {
    print("usage: swift AppIcon.swift ios|mac out.png")
    exit(64)
}
let isMac = arguments[1] == "mac"
let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// The macOS icon grid: an 824-point rounded square, centred, with Apple's soft drop shadow.
let body = isMac ? CGRect(x: 100, y: 100, width: 824, height: 824) : CGRect(x: 0, y: 0, width: canvas, height: canvas)
let bodyPath = CGPath(roundedRect: body, cornerWidth: isMac ? 185 : 0, cornerHeight: isMac ? 185 : 0, transform: nil)
if isMac {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(bodyPath)
    context.setFillColor(color(0x10141F))
    context.fillPath()
    context.restoreGState()
}
context.addPath(bodyPath)
context.clip()

// Sky: slate above, deep navy below, a low amber sun behind the ring.
let sky = CGGradient(colorsSpace: space, colors: [color(0x3A4E63), color(0x1A2333), color(0x0B1019)] as CFArray, locations: [0, 0.55, 1])!
context.drawLinearGradient(sky, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.minY), options: [])
let sun = CGGradient(colorsSpace: space, colors: [color(0xF4B678, 0.85), color(0xF4B678, 0)] as CFArray, locations: [0, 1])!
let center = CGPoint(x: body.midX, y: body.midY)
context.drawRadialGradient(sun, startCenter: center, startRadius: 0, endCenter: center, endRadius: body.width * 0.46, options: [])

// The halo: a ring whose light turns from amber through coral and violet to sky, drawn as many
// short arcs since Core Graphics has no conic gradient.
let stops: [(CGFloat, UInt32)] = [(0, 0xFFC46B), (0.28, 0xFF7A5C), (0.55, 0xB07CFF), (0.8, 0x6EC8FF), (1, 0xFFC46B)]
func ringColor(at t: CGFloat, alpha: CGFloat) -> CGColor {
    let upper = stops.firstIndex { $0.0 >= t } ?? stops.count - 1
    let (t1, c1) = stops[max(upper - 1, 0)], (t2, c2) = stops[upper]
    let f = t2 > t1 ? (t - t1) / (t2 - t1) : 0
    func channel(_ shift: UInt32) -> CGFloat {
        let a = CGFloat((c1 >> shift) & 0xFF), b = CGFloat((c2 >> shift) & 0xFF)
        return (a + (b - a) * f) / 255
    }
    return CGColor(srgbRed: channel(16), green: channel(8), blue: channel(0), alpha: alpha)
}

let radius = body.width * 0.29
let segments = 720

/// The ring alone, on a transparent layer the size of the canvas.
func ringLayer(width: CGFloat) -> CGImage {
    let layer = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    layer.setLineCap(.butt)
    layer.setLineWidth(width)
    for index in 0..<segments {
        let t = CGFloat(index) / CGFloat(segments)
        let start = .pi / 2 - t * 2 * .pi
        // A hair of overlap hides the joins between arcs; the ring is opaque, so no seams show.
        let end = start - 2 * .pi / CGFloat(segments) - 0.002
        layer.setStrokeColor(ringColor(at: t, alpha: 1))
        layer.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        layer.strokePath()
    }
    return layer.makeImage()!
}

let ring = ringLayer(width: body.width * 0.085)

// The glow: the same ring, blurred wide and laid underneath at partial strength.
let blur = CIFilter(name: "CIGaussianBlur")!
blur.setValue(CIImage(cgImage: ring), forKey: kCIInputImageKey)
blur.setValue(body.width * 0.07, forKey: kCIInputRadiusKey)
let glow = CIContext().createCGImage(blur.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: canvas, height: canvas)),
                                     from: CGRect(x: 0, y: 0, width: canvas, height: canvas))!
context.saveGState()
context.setAlpha(0.85)
context.draw(glow, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))
context.restoreGState()
context.draw(ring, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

// A thin bright rim on the ring's upper left, where light would catch it.
context.saveGState()
context.setLineWidth(body.width * 0.012)
context.setStrokeColor(color(0xFFFFFF, 0.55))
context.setLineCap(.round)
context.addArc(center: center, radius: radius + body.width * 0.03, startAngle: .pi * 0.62, endAngle: .pi * 0.92, clockwise: false)
context.strokePath()
context.restoreGState()

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(filePath: arguments[2]))
