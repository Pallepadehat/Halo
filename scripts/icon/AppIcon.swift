// Draws Halo's app icon: an iPad at night, its screen dark but for a halo of light running
// round the inside of its edge, warm at the top and cool at the sides.
//
//   swiftc -O scripts/icon/AppIcon.swift -o build/AppIcon
//   build/AppIcon ios  out.png   full bleed; iOS masks the corners itself
//   build/AppIcon mac  out.png   inside the macOS rounded square, with its shadow
//
// scripts/make-icons.sh compiles it (the conic gradient is computed per pixel) and runs both.

import AppKit
import CoreImage
import SwiftUI

let arguments = CommandLine.arguments
guard arguments.count == 3, ["ios", "mac"].contains(arguments[1]) else {
    print("usage: AppIcon ios|mac out.png")
    exit(64)
}
let isMac = arguments[1] == "mac"
let canvas: CGFloat = 1024
let full = CGRect(x: 0, y: 0, width: canvas, height: canvas)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func makeLayer() -> CGContext {
    CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let ciContext = CIContext()
func blurred(_ image: CGImage, _ radius: CGFloat) -> CGImage {
    let output = CIImage(cgImage: image).clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: full)
    return ciContext.createCGImage(output, from: full)!
}

func continuous(_ rect: CGRect, radius: CGFloat) -> CGPath {
    RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
}

// The macOS icon grid: an 824-point rounded square, centred. iOS fills the canvas.
let body = isMac ? CGRect(x: 100, y: 100, width: 824, height: 824) : full
let unit = body.width / 824
let center = CGPoint(x: body.midX, y: body.midY)

// The iPad, in landscape at its real 4:3, with Apple's continuous corners.
let device = CGRect(x: center.x - 330 * unit, y: center.y - 250 * unit, width: 660 * unit, height: 500 * unit)
let deviceRadius = 70 * unit
let screen = device.insetBy(dx: 14 * unit, dy: 14 * unit)
let screenRadius = deviceRadius - 12 * unit

// The halo's colours, clockwise from the top: amber, coral, rose, violet, sky.
let stops: [(CGFloat, UInt32)] = [(0, 0xFFC46B), (0.2, 0xFF7A59), (0.4, 0xF2508C), (0.6, 0xA06BFF), (0.8, 0x4FB8FF), (1, 0xFFC46B)]

/// A conic gradient over the whole canvas. Core Graphics has none, so it's computed per pixel.
let conic: CGImage = {
    let side = Int(canvas)
    var pixels = [UInt8](repeating: 255, count: side * side * 4)
    func channel(_ value: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((value >> shift) & 0xFF) }
    for y in 0..<side {
        for x in 0..<side {
            var t = atan2(CGFloat(x) - center.x, -(CGFloat(y) - center.y)) / (2 * .pi)
            if t < 0 { t += 1 }
            let upper = stops.firstIndex { $0.0 >= t } ?? stops.count - 1
            let (t1, c1) = stops[max(upper - 1, 0)], (t2, c2) = stops[upper]
            let f = t2 > t1 ? (t - t1) / (t2 - t1) : 0
            let index = (y * side + x) * 4
            for (offset, shift) in [UInt32(16), 8, 0].enumerated() {
                pixels[index + offset] = UInt8(channel(c1, shift) + (channel(c2, shift) - channel(c1, shift)) * f)
            }
        }
    }
    return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: space,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                   provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
}()

/// The conic colours wherever `shape` paints white, on a transparent layer.
func lit(_ shape: (CGContext) -> Void) -> CGImage {
    let mask = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    mask.setFillColor(gray: 0, alpha: 1)
    mask.fill(full)
    shape(mask)
    let layer = makeLayer()
    layer.clip(to: full, mask: mask.makeImage()!)
    layer.draw(conic, in: full)
    return layer.makeImage()!
}

let context = makeLayer()

func glow(_ image: CGImage, alpha: CGFloat) {
    context.saveGState()
    context.setBlendMode(.screen)
    context.setAlpha(alpha)
    context.draw(image, in: full)
    context.restoreGState()
}

let bodyPath = isMac ? continuous(body, radius: 185) : CGPath(rect: body, transform: nil)
if isMac {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.35))
    context.addPath(bodyPath)
    context.setFillColor(color(0x0A0C11))
    context.fillPath()
    context.restoreGState()
}
context.addPath(bodyPath)
context.clip()

// Night, lifted a touch at the top as if lit from above.
let night = CGGradient(colorsSpace: space, colors: [color(0x1A1F2B), color(0x0A0C11), color(0x040507)] as CFArray, locations: [0, 0.5, 1])!
context.drawLinearGradient(night, start: CGPoint(x: body.midX, y: body.maxY), end: CGPoint(x: body.midX, y: body.minY), options: [])

let edge = lit { mask in
    mask.addPath(continuous(screen, radius: screenRadius))
    mask.setLineWidth(30 * unit)
    mask.setStrokeColor(gray: 1, alpha: 1)
    mask.strokePath()
}

// Some of the light spills past the bezel onto the night around it.
glow(blurred(edge, 90 * unit), alpha: 0.45)

// The iPad: a black slab with a soft shadow beneath.
let devicePath = continuous(device, radius: deviceRadius)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 30 * unit, color: color(0x000000, 0.6))
context.addPath(devicePath)
context.setFillColor(color(0x07080B))
context.fillPath()
context.restoreGState()

// The bezel's edge catches the light along the top and fades away below.
context.saveGState()
context.addPath(devicePath)
context.setLineWidth(3 * unit)
context.replacePathWithStrokedPath()
context.clip()
let rim = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.6), color(0xFFFFFF, 0.06)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(rim, start: CGPoint(x: device.midX, y: device.maxY), end: CGPoint(x: device.midX, y: device.minY), options: [])
context.restoreGState()

// The front camera, centred on the long top edge as on a current iPad.
context.addEllipse(in: CGRect(x: device.midX - 3.5 * unit, y: device.maxY - 10.5 * unit, width: 7 * unit, height: 7 * unit))
context.setFillColor(color(0x1C2230))
context.fillPath()

// The screen: dark glass, with the halo glowing in from its edges.
let screenPath = continuous(screen, radius: screenRadius)
context.saveGState()
context.addPath(screenPath)
context.clip()
let glass = CGGradient(colorsSpace: space, colors: [color(0x161A24), color(0x0A0C11), color(0x050608)] as CFArray, locations: [0, 0.5, 1])!
context.drawLinearGradient(glass, start: CGPoint(x: screen.minX, y: screen.maxY), end: CGPoint(x: screen.maxX, y: screen.minY), options: [])
glow(blurred(edge, 40 * unit), alpha: 1)
glow(blurred(edge, 12 * unit), alpha: 1)
// A faint sheen across the upper left of the glass.
let sheen = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.07), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(sheen, start: CGPoint(x: screen.minX, y: screen.maxY), end: CGPoint(x: screen.midX, y: screen.midY), options: [])
context.restoreGState()

let image = context.makeImage()!
try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(filePath: arguments[2]))
