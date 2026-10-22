// Draws Halo's banner: the icon and wordmark beside the iPad's home screen, with the icon's halo of
// light glowing round the iPad at night.
//
//   swift scripts/banner/Banner.swift <width> <height> <screenshot.png> <icon.png> <out.png>
//
// scripts/make-banner.sh draws the README banner and GitHub's social preview with it.

import AppKit
import CoreImage
import SwiftUI

let arguments = CommandLine.arguments
guard arguments.count == 6, let width = Double(arguments[1]), let height = Double(arguments[2]) else {
    print("usage: swift Banner.swift <width> <height> <screenshot.png> <icon.png> <out.png>")
    exit(64)
}
let size = CGSize(width: width, height: height)
let scale = height / 1280
guard let screenshot = NSImage(contentsOfFile: arguments[3]), let icon = NSImage(contentsOfFile: arguments[4]) else {
    print("Couldn't read the screenshot or the icon.")
    exit(66)
}

let image = NSImage(size: size, flipped: false) { rect in
    guard let context = NSGraphicsContext.current?.cgContext else { return false }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    // Night: the icon's, stretched to a stage.
    let sky = CGGradient(colorsSpace: space, colors: [color(0x1A1F2B), color(0x0A0C11), color(0x040507)] as CFArray, locations: [0, 0.55, 1])!
    context.drawLinearGradient(sky, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: 0), options: [])

    // The iPad: the real home screen in a slim, dark bezel, casting a soft shadow.
    let screenHeight = rect.height * 0.62
    let screenWidth = screenHeight * screenshot.size.width / screenshot.size.height
    let bezel = 22 * scale
    let device = CGRect(x: rect.width - screenWidth - bezel * 2 - rect.width * 0.06,
                        y: (rect.height - screenHeight) / 2 - bezel, width: screenWidth + bezel * 2, height: screenHeight + bezel * 2)
    let deviceRadius = 64 * scale
    func continuous(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
    }

    // The halo: the icon's colours glowing out from round the iPad, warm above and cool below.
    let pixels = CGSize(width: rect.width, height: rect.height)
    let haloLayer = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    haloLayer.addPath(continuous(device, deviceRadius))
    haloLayer.setLineWidth(40 * scale)
    haloLayer.replacePathWithStrokedPath()
    haloLayer.clip()
    let spectrum = CGGradient(colorsSpace: space, colors: [color(0xFFC46B), color(0xFF7A59), color(0xF2508C), color(0xA06BFF), color(0x4FB8FF)] as CFArray,
                              locations: [0, 0.25, 0.5, 0.75, 1])!
    haloLayer.drawLinearGradient(spectrum, start: CGPoint(x: device.maxX, y: device.maxY), end: CGPoint(x: device.minX, y: device.minY), options: [])
    let halo = CIImage(cgImage: haloLayer.makeImage()!).clampedToExtent()
    let extent = CGRect(origin: .zero, size: pixels)
    let ci = CIContext()
    for (radius, alpha) in [(160.0, 0.55), (60.0, 0.6)] {
        let glow = ci.createCGImage(halo.applyingGaussianBlur(sigma: radius * scale).cropped(to: extent), from: extent)!
        context.saveGState()
        context.setBlendMode(.screen)
        context.setAlpha(alpha)
        context.draw(glow, in: rect)
        context.restoreGState()
    }

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -30 * scale), blur: 90 * scale, color: color(0x000000, 0.6))
    context.addPath(continuous(device, deviceRadius))
    context.setFillColor(color(0x0A0B0E))
    context.fillPath()
    context.restoreGState()
    context.addPath(continuous(device.insetBy(dx: 1.5 * scale, dy: 1.5 * scale), deviceRadius))
    context.setStrokeColor(color(0x3A3C42))
    context.setLineWidth(3 * scale)
    context.strokePath()
    let screen = device.insetBy(dx: bezel, dy: bezel)
    context.saveGState()
    context.addPath(continuous(screen, deviceRadius - bezel))
    context.clip()
    screenshot.draw(in: screen)
    context.restoreGState()

    // The wordmark, set like an Apple product page: icon, name, one line.
    let left = rect.width * 0.065
    let iconSide = 170 * scale
    icon.draw(in: CGRect(x: left - 14 * scale, y: rect.height * 0.57, width: iconSide, height: iconSide))

    func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at y: CGFloat, tracking: CGFloat = 0) {
        let font = NSFont.systemFont(ofSize: size * scale, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: tracking * scale]
        NSAttributedString(string: text, attributes: attributes).draw(at: CGPoint(x: left, y: y))
    }
    draw("Halo", size: 150, weight: .semibold, color: .white, at: rect.height * 0.385, tracking: -3)
    draw("Your Mac, at your side.", size: 54, weight: .regular, color: NSColor.white.withAlphaComponent(0.78), at: rect.height * 0.315, tracking: -0.5)
    draw("Agents · Music · Pulse · Trackpad · Deck", size: 30, weight: .medium, color: NSColor.white.withAlphaComponent(0.45),
         at: rect.height * 0.245, tracking: 0.2)
    return true
}

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(70) }
try png.write(to: URL(filePath: arguments[5]))
