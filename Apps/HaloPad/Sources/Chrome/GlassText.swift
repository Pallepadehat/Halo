import CoreText
import SwiftUI

/// One line of text cut from Liquid Glass, like the Lock Screen's clock. The glyphs become a
/// shape for `glassEffect`, scaled to fit the space it's given, so it never clips.
struct GlassText: View {
    let text: String
    let size: CGFloat
    var weight: UIFont.Weight = .regular
    var glass: Glass = .regular

    var body: some View {
        let shape = TextShape(text: text, font: Self.font(size: size, weight: weight))
        Color.clear
            .aspectRatio(shape.aspectRatio, contentMode: .fit)
            .frame(maxWidth: shape.bounds.width, maxHeight: shape.bounds.height)
            .glassEffect(glass, in: shape)
            .accessibilityElement()
            .accessibilityLabel(text)
    }

    /// SF with monospaced digits, so the clock doesn't shuffle sideways as the minutes turn.
    static func font(size: CGFloat, weight: UIFont.Weight) -> CTFont {
        let base = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return base as CTFont
    }
}

/// Text as outlines, fitted into whatever rect it's drawn in.
struct TextShape: Shape {
    let outline: Path
    let bounds: CGRect

    init(text: String, font: CTFont) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            // A run may fall back to another font for characters SF lacks.
            let runFont = attributes[kCTFontAttributeName] as! CTFont? ?? font
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(), &glyphs)
            CTRunGetPositions(run, CFRange(), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                guard let outline = CTFontCreatePathForGlyph(runFont, glyph, nil) else { continue }
                // Core Text draws upward from the baseline; SwiftUI draws downward.
                path.addPath(outline, transform: CGAffineTransform(translationX: position.x, y: 0).scaledBy(x: 1, y: -1))
            }
        }
        // The line's typographic box, so different times share a baseline and a height.
        var ascent: CGFloat = 0, descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let ink = path.boundingBoxOfPath
        bounds = CGRect(x: 0, y: -CTFontGetCapHeight(font), width: max(width, ink.maxX), height: CTFontGetCapHeight(font))
        outline = Path(path)
    }

    var aspectRatio: CGFloat { bounds.height > 0 ? bounds.width / bounds.height : 1 }

    func path(in rect: CGRect) -> Path {
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        let x = rect.midX - bounds.width * scale / 2
        let y = rect.midY - bounds.height * scale / 2
        let transform = CGAffineTransform(translationX: x, y: y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bounds.minX, y: -bounds.minY)
        return outline.applying(transform)
    }
}
