import AppKit
import Sparkle

/// Keeps Halo Helper up to date with Sparkle. Once a day it reads the appcast on GitHub (one
/// small download; nothing about you is sent). When there's a newer version, Sparkle downloads
/// it, checks it's signed by the same developer and with our EdDSA key, swaps it in and relaunches.
@MainActor
final class Updates {
    static let shared = Updates()

    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    func start() {
        // Builds from Xcode stay as they are, rather than being swapped for the latest release.
        #if !DEBUG
        controller.startUpdater()
        #endif
    }

    /// Checks right now, with Sparkle's window.
    func checkNow() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    var canCheck: Bool {
        controller.updater.canCheckForUpdates
    }
}
