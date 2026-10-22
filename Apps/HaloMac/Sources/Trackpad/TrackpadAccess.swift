import HaloInput
import Observation

/// Tracks whether the helper may move the pointer. macOS doesn't notify when Accessibility
/// consent changes, so this polls while it's missing and stops once granted.
@MainActor
@Observable
final class TrackpadAccess {
    static let pollInterval: Duration = .seconds(2)

    private(set) var isGranted = InputAccess.isGranted
    @ObservationIgnored var onChange: (Bool) -> Void = { _ in }
    @ObservationIgnored private var polling: Task<Void, Never>?

    func start() {
        guard !isGranted, polling == nil else { return }
        polling = Task {
            while !Task.isCancelled, !isGranted {
                try? await Task.sleep(for: Self.pollInterval)
                refresh()
            }
            polling = nil
        }
    }

    /// Shows the system prompt and adds Halo Helper to the Accessibility list.
    func request() {
        InputAccess.request()
        refresh()
        start()
    }

    private func refresh() {
        let granted = InputAccess.isGranted
        guard granted != isGranted else { return }
        isGranted = granted
        onChange(granted)
    }
}
