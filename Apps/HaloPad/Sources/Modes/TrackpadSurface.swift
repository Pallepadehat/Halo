import HaloProtocol
import HaloTrackpad
import SwiftUI
import UIKit

/// SwiftUI wrapper around the raw-touch surface.
struct TrackpadSurface: UIViewRepresentable {
    let onEvents: ([PointerEvent]) -> Void

    func makeUIView(context: Context) -> TouchSurfaceView {
        TouchSurfaceView()
    }

    func updateUIView(_ view: TouchSurfaceView, context: Context) {
        view.onEvents = onEvents
    }
}

/// Reads raw touches, not gesture recognizers: recognizers wait to disambiguate, and that
/// wait would come straight out of the latency budget. Every touch change goes through the
/// interpreter immediately, using UIKit's own event timestamps.
final class TouchSurfaceView: UIView {
    var onEvents: ([PointerEvent]) -> Void = { _ in }

    private var interpreter = TrackpadInterpreter()
    private var activeTouches: Set<UITouch> = []
    private var holdTimer: Task<Void, Never>?
    private var fingerprints: [ObjectIdentifier: CALayer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = true
        accessibilityLabel = String(localized: "Trackpad")
        accessibilityTraits = .allowsDirectInteraction
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        process(event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        process(event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        process(event)
    }

    private func process(_ event: UIEvent?) {
        let time = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let points = activeTouches.map { touch in
            let location = touch.location(in: self)
            return TouchPoint(id: ObjectIdentifier(touch).hashValue, x: location.x, y: location.y)
        }
        emit(interpreter.update(points, at: time))
        scheduleHoldIfNeeded()
        drawFingerprints()
    }

    private func emit(_ events: [PointerEvent]) {
        guard !events.isEmpty else { return }
        onEvents(events)
    }

    /// A still finger becomes a drag once it's been held long enough.
    private func scheduleHoldIfNeeded() {
        guard interpreter.isAwaitingHold else {
            holdTimer?.cancel()
            holdTimer = nil
            return
        }
        guard holdTimer == nil else { return }
        holdTimer = Task { [weak self, delay = interpreter.configuration.holdToDragDuration] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            holdTimer = nil
            emit(interpreter.holdElapsed(at: ProcessInfo.processInfo.systemUptime))
        }
    }

    // MARK: - Feedback

    /// A soft glow under each finger: enough to see the surface respond, nothing that blinks.
    private func drawFingerprints() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let current = Dictionary(uniqueKeysWithValues: activeTouches.map { (ObjectIdentifier($0), $0) })
        for (id, layer) in fingerprints where current[id] == nil {
            layer.removeFromSuperlayer()
            fingerprints[id] = nil
        }
        for (id, touch) in current {
            let layer = fingerprints[id] ?? makeFingerprint()
            fingerprints[id] = layer
            layer.position = touch.location(in: self)
        }
    }

    private func makeFingerprint() -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
        layer.cornerRadius = 36
        layer.backgroundColor = UIColor(Color.haloInk).withAlphaComponent(0.08).cgColor
        self.layer.addSublayer(layer)
        return layer
    }
}
