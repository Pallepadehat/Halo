#if os(macOS)
import AppKit
import CoreGraphics

/// Display brightness for whichever display the person is looking at.
///
/// Built-in and Apple displays are dimmed properly, through DisplayServices (the private
/// framework Control Center uses; there's no public API). Any other display is dimmed in
/// software by scaling its gamma, so the slider works everywhere. Software dimming is undone
/// when the helper quits or brightness returns to full.
@MainActor
public enum DisplayBrightness {
    public struct State: Sendable, Equatable {
        public let brightness: Double?
        public let displayName: String?
        public let isSoftware: Bool
    }

    /// Never dim in software below this: a black screen with no way back is worse than no control.
    nonisolated static let softwareFloor = 0.15

    private static var softwareLevels: [CGDirectDisplayID: Double] = [:]

    public static func current() -> State {
        let display = CGMainDisplayID()
        if let level = Hardware.brightness(of: display) {
            return State(brightness: level, displayName: name(of: display), isSoftware: false)
        }
        reapplySoftwareLevelIfReset(on: display)
        let level = softwareLevels[display] ?? 1
        return State(brightness: sliderValue(forSoftwareLevel: level), displayName: name(of: display), isSoftware: true)
    }

    public static func setBrightness(_ value: Double) {
        let display = CGMainDisplayID()
        let value = min(max(value, 0), 1)
        if Hardware.canChange(display) {
            Hardware.setBrightness(value, of: display)
        } else {
            setSoftwareLevel(softwareLevel(for: value), on: display)
        }
    }

    /// Hands every display back to ColorSync. Call when the helper quits.
    public static func restoreSoftwareDimming() {
        guard !softwareLevels.isEmpty else { return }
        softwareLevels.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    // MARK: - Software dimming

    /// Maps the slider's 0...1 onto floor...1, so the bottom of the slider is dim, not black.
    nonisolated static func softwareLevel(for value: Double) -> Double {
        softwareFloor + (1 - softwareFloor) * min(max(value, 0), 1)
    }

    nonisolated static func sliderValue(forSoftwareLevel level: Double) -> Double {
        (level - softwareFloor) / (1 - softwareFloor)
    }

    private static func setSoftwareLevel(_ level: Double, on display: CGDirectDisplayID) {
        if level >= 0.999 {
            softwareLevels[display] = nil
            CGDisplayRestoreColorSyncSettings()
            return
        }
        softwareLevels[display] = level
        applyGamma(level, on: display)
    }

    /// macOS resets gamma on sleep, wake and display changes; put ours back if it went.
    private static func reapplySoftwareLevelIfReset(on display: CGDirectDisplayID) {
        guard let level = softwareLevels[display] else { return }
        var redMin: CGGammaValue = 0, redMax: CGGammaValue = 0, redGamma: CGGammaValue = 0
        var greenMin: CGGammaValue = 0, greenMax: CGGammaValue = 0, greenGamma: CGGammaValue = 0
        var blueMin: CGGammaValue = 0, blueMax: CGGammaValue = 0, blueGamma: CGGammaValue = 0
        CGGetDisplayTransferByFormula(display, &redMin, &redMax, &redGamma, &greenMin, &greenMax, &greenGamma, &blueMin, &blueMax, &blueGamma)
        if abs(Double(redMax) - level) > 0.01 { applyGamma(level, on: display) }
    }

    private static func applyGamma(_ level: Double, on display: CGDirectDisplayID) {
        let max = CGGammaValue(level)
        CGSetDisplayTransferByFormula(display, 0, max, 1, 0, max, 1, 0, max, 1)
    }

    private static func name(of display: CGDirectDisplayID) -> String? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
        }?.localizedName
    }
}

private extension DisplayBrightness {
    /// DisplayServices, resolved at runtime; every call degrades to "can't" if a symbol is missing.
    @MainActor
    enum Hardware {
        private typealias CanChange = @convention(c) (CGDirectDisplayID) -> Bool
        private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32

        private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        private static let canChangeBrightness = symbol("DisplayServicesCanChangeBrightness", as: CanChange.self)
        private static let getBrightness = symbol("DisplayServicesGetBrightness", as: Get.self)
        private static let setBrightness = symbol("DisplayServicesSetBrightness", as: Set.self)

        static func canChange(_ display: CGDirectDisplayID) -> Bool {
            canChangeBrightness?(display) ?? false
        }

        static func brightness(of display: CGDirectDisplayID) -> Double? {
            guard canChange(display), let getBrightness else { return nil }
            var value: Float = 0
            return getBrightness(display, &value) == 0 ? Double(value) : nil
        }

        static func setBrightness(_ value: Double, of display: CGDirectDisplayID) {
            _ = setBrightness?(display, Float(value))
        }

        private static func symbol<Function>(_ name: String, as type: Function.Type) -> Function? {
            guard let framework, let pointer = dlsym(framework, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
    }
}
#endif
