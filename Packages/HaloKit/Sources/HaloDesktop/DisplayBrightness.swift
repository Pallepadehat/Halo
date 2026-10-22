#if os(macOS)
import AppKit
import CoreGraphics

/// Display brightness through DisplayServices, the private framework Control Center uses.
/// There's no public API for it; Halo Helper ships outside the App Store, and every call
/// degrades to "unavailable" if the framework or a symbol is missing.
@MainActor
public enum DisplayBrightness {
    private typealias CanChange = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let canChange = symbol("DisplayServicesCanChangeBrightness", as: CanChange.self)
    private static let get = symbol("DisplayServicesGetBrightness", as: Get.self)
    private static let set = symbol("DisplayServicesSetBrightness", as: Set.self)

    public struct State: Sendable, Equatable {
        public let brightness: Double?
        public let displayName: String?
    }

    public static func current() -> State {
        guard let display = controllableDisplay(), let get else { return State(brightness: nil, displayName: nil) }
        var value: Float = 0
        guard get(display, &value) == 0 else { return State(brightness: nil, displayName: nil) }
        return State(brightness: Double(value), displayName: name(of: display))
    }

    public static func setBrightness(_ value: Double) {
        guard let display = controllableDisplay(), let set else { return }
        _ = set(display, Float(min(max(value, 0), 1)))
    }

    /// The main display if it can be dimmed (built-in, Studio Display), else the first that can.
    private static func controllableDisplay() -> CGDirectDisplayID? {
        guard let canChange else { return nil }
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        let main = CGMainDisplayID()
        return ([main] + displays).first(where: canChange)
    }

    private static func name(of display: CGDirectDisplayID) -> String? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
        }?.localizedName
    }

    private static func symbol<Function>(_ name: String, as type: Function.Type) -> Function? {
        guard let framework, let pointer = dlsym(framework, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }
}
#endif
