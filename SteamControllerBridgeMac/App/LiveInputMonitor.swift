import Foundation
import Combine
import CoreGraphics
import QuartzCore

/// Bridges the input pipeline to the settings window's "Test Controls" tab:
/// the raw physical state alongside exactly what was relayed (virtual pad
/// report + kb/m). Publishes only while a view is observing, throttled to
/// display rate, so it costs nothing when the tab is closed.
@MainActor
final class LiveInputMonitor: ObservableObject {
    struct Snapshot {
        var input = InputState()
        var output = MappedOutput()
    }

    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var connectionText = "Bridge off"
    @Published private(set) var connected = false
    /// The profile the engine is currently running (not unsaved edits).
    @Published var appliedProfile: Profile = .defaultProfile
    /// Most recent button press/release events, newest first. Tracked on
    /// every report (not throttled) so quick taps are never missed.
    @Published private(set) var events: [String] = []
    private var pendingEvents: [String] = []
    private var lastRawButtons: UInt32 = 0
    private let maxEvents = 8

    private var observers = 0
    private var lastPublish = 0.0
    private let publishInterval = 1.0 / 60.0

    func beginObserving() { observers += 1 }
    func endObserving() { observers = max(observers - 1, 0) }

    func record(input: InputState, output: MappedOutput) {
        guard observers > 0 else { return }
        let raw = input.buttons.rawValue
        if raw != lastRawButtons {
            let changed = raw ^ lastRawButtons
            for bit in 0..<32 where changed & (1 << UInt32(bit)) != 0 {
                let down = raw & (1 << UInt32(bit)) != 0
                pendingEvents.append(String(format: "%@ bit %2d  %@",
                                            down ? "▼ press  " : "▲ release",
                                            bit, ButtonBitNames.label(bit)))
            }
            lastRawButtons = raw
        }
        let now = CACurrentMediaTime()
        guard now - lastPublish >= publishInterval else { return }
        lastPublish = now
        snapshot = Snapshot(input: input, output: output)
        if !pendingEvents.isEmpty {
            events = Array((pendingEvents.reversed() + events).prefix(maxEvents))
            pendingEvents.removeAll()
        }
    }

    func setConnection(_ text: String, connected: Bool) {
        connectionText = text
        self.connected = connected
        if !connected {
            snapshot = Snapshot()
            lastRawButtons = 0
        }
    }
}
