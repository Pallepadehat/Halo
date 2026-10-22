// Draws Halo's banner: the icon and wordmark beside the iPad's home screen, over the icon's dusk sky.
//
//   swift scripts/banner/Banner.swift <width> <height> <screenshot.png> <icon.png> <out.png>
//
// scripts/make-banner.sh draws the README banner and GitHub's social preview with it.

import AppKit

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

    // The sky: the icon's, stretched to a stage, with the sun low behind the iPad.
    let sky = CGGradient(colorsSpace: space, colors: [color(0x2E3E52), color(0x141B28), color(0x07090F)] as CFArray, locations: [0, 0.6, 1])!
    context.drawLinearGradient(sky, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: 0), options: [])
    let sunCenter = CGPoint(x: rect.width * 0.66, y: rect.height * 0.5)
    let sun = CGGradient(colorsSpace: space, colors: [color(0xF4B678, 0.42), color(0xF4B678, 0)] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(sun, startCenter: sunCenter, startRadius: 0, endCenter: sunCenter, endRadius: rect.height * 0.75, options: [])

    // The iPad: the real home screen in a slim, dark bezel, casting a soft shadow.
    let screenHeight = rect.height * 0.62
    let screenWidth = screenHeight * screenshot.size.width / screenshot.size.height
    let bezel = 22 * scale
    let device = CGRect(x: rect.width - screenWidth - bezel * 2 - rect.width * 0.06,
                        y: (rect.height - screenHeight) / 2 - bezel, width: screenWidth + bezel * 2, height: screenHeight + bezel * 2)
    let deviceRadius = 64 * scale
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -30 * scale), blur: 90 * scale, color: color(0x000000, 0.6))
    context.addPath(CGPath(roundedRect: device, cornerWidth: deviceRadius, cornerHeight: deviceRadius, transform: nil))
    context.setFillColor(color(0x0A0B0E))
    context.fillPath()
    context.restoreGState()
    context.addPath(CGPath(roundedRect: device.insetBy(dx: 1.5 * scale, dy: 1.5 * scale),
                           cornerWidth: deviceRadius, cornerHeight: deviceRadius, transform: nil))
    context.setStrokeColor(color(0x3A3C42))
    context.setLineWidth(3 * scale)
    context.strokePath()
    let screen = device.insetBy(dx: bezel, dy: bezel)
    context.saveGState()
    context.addPath(CGPath(roundedRect: screen, cornerWidth: deviceRadius - bezel, cornerHeight: deviceRadius - bezel, transform: nil))
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
