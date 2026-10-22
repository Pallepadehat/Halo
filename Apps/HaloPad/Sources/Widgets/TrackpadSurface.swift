import HaloProtocol
import HaloTrackpad
import SwiftUI
import UIKit

/// SwiftUI wrapper around the raw-touch surface.
struct TrackpadSurface: UIViewRepresentable {
    let onEvents: ([PointerEvent]) -> Void
    /// The person's own gestures, such as a three-finger tap.
    var onGesture: (TrackpadGesture) -> Void = { _ in }
    /// Lets the page stop paging while a finger is on the trackpad.
    var onTouchingChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> TouchSurfaceView {
        TouchSurfaceView()
    }

    func updateUIView(_ view: TouchSurfaceView, context: Context) {
        view.onEvents = onEvents
        view.onGesture = onGesture
        view.onTouchingChanged = onTouchingChanged
    }
}

/// Reads raw touches, not gesture recognizers: recognizers wait to disambiguate, and that
/// wait would come straight out of the latency budget. Every touch change goes through the
/// interpreter immediately, using UIKit's own event timestamps.
final class TouchSurfaceView: UIView {
    var onEvents: ([PointerEvent]) -> Void = { _ in }
    var onTouchingChanged: (Bool) -> Void = { _ in }
    var onGesture: (TrackpadGesture) -> Void = { _ in }

    private var interpreter = TrackpadInterpreter()
    private var activeTouches: Set<UITouch> = []
    private var holdTimer: Task<Void, Never>?
    private var fingerprints: [ObjectIdentifier: CALayer] = [:]
    private var momentum: ScrollMomentum?
    private var momentumLink: CADisplayLink?
    private var hasSentMomentum = false

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
        // A finger landing catches a coasting scroll, as it does on a real trackpad.
        stopMomentum()
        if activeTouches.isEmpty { onTouchingChanged(true) }
        activeTouches.formUnion(touches)
        process(event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        process(event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        process(event)
        if activeTouches.isEmpty { onTouchingChanged(false) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        process(event)
        if activeTouches.isEmpty { onTouchingChanged(false) }
    }

    private func process(_ event: UIEvent?) {
        let time = event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let points = activeTouches.map { touch in
            let location = touch.location(in: self)
            return TouchPoint(id: ObjectIdentifier(touch).hashValue, x: location.x, y: location.y)
        }
        emit(interpreter.update(points, at: time))
        if let launched = interpreter.takeMomentum() { startMomentum(launched) }
        if let gesture = interpreter.takeGesture() {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onGesture(gesture)
        }
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

    // MARK: - Momentum

    /// Coasts at the display's own refresh rate, so the scroll stays as smooth as the screen.
    private func startMomentum(_ launched: ScrollMomentum) {
        momentum = launched
        hasSentMomentum = false
        let link = CADisplayLink(target: self, selector: #selector(stepMomentum))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        momentumLink = link
    }

    @objc private func stepMomentum(_ link: CADisplayLink) {
        guard var current = momentum else { return stopMomentum() }
        guard let step = current.advance(by: link.targetTimestamp - link.timestamp) else { return stopMomentum() }
        momentum = current
        emit([.momentumScroll(dx: step.dx, dy: step.dy, phase: hasSentMomentum ? .changed : .began)])
        hasSentMomentum = true
    }

    private func stopMomentum() {
        momentumLink?.invalidate()
        momentumLink = nil
        momentum = nil
        if hasSentMomentum { emit([.momentumScroll(dx: 0, dy: 0, phase: .ended)]) }
        hasSentMomentum = false
    }

    override func removeFromSuperview() {
        stopMomentum()
        super.removeFromSuperview()
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
        layer.backgroundColor = UIColor.white.withAlphaComponent(0.1).cgColor
        self.layer.addSublayer(layer)
        return layer
    }
}
