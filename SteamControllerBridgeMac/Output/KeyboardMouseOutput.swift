import AppKit
import CoreGraphics

/// Posts keyboard and mouse-button events for kb/m bindings, tracking held
/// state so every press is paired with a release — including across turbo
/// pulses, profile reloads, and bridge shutdown. Requires the Accessibility
/// permission. Main-thread only (called from the input pipeline).
@MainActor
final class KeyboardMouseOutput {
    private var heldKeys: Set<CGKeyCode> = []
    private var heldMouse: Set<MouseButton> = []

    /// Reconciles the currently held keys/buttons against the desired set,
    /// posting only the deltas. Cheap no-op when nothing changed.
    func apply(keys: Set<CGKeyCode>, mouseButtons: Set<MouseButton>) {
        for code in keys.subtracting(heldKeys) { postKey(code, down: true) }
        for code in heldKeys.subtracting(keys) { postKey(code, down: false) }
        heldKeys = keys

        for button in mouseButtons.subtracting(heldMouse) { postMouse(button, down: true) }
        for button in heldMouse.subtracting(mouseButtons) { postMouse(button, down: false) }
        heldMouse = mouseButtons
    }

    func releaseAll() {
        apply(keys: [], mouseButtons: [])
        resetMotion()
    }

    /// Fractional cursor motion not yet emitted. Slow stick/gyro motion is
    /// often well under a pixel per report; without carrying the remainder
    /// forward it would be lost (or rounded unevenly) and fine aim would
    /// feel sticky.
    private var pendingDX = 0.0
    private var pendingDY = 0.0

    /// Moves the cursor by a relative delta. Emits drag events while a
    /// mouse button is held so click-drag works.
    func moveMouse(dx: Double, dy: Double) {
        pendingDX += dx
        pendingDY += dy
        let stepX = pendingDX.rounded(.towardZero)
        let stepY = pendingDY.rounded(.towardZero)
        guard stepX != 0 || stepY != 0 else { return }
        pendingDX -= stepX
        pendingDY -= stepY

        let source = CGEventSource(stateID: .hidSystemState)
        let current = CGEvent(source: nil)?.location ?? .zero
        let position = CGPoint(x: current.x + stepX, y: current.y + stepY)

        let type: CGEventType
        let button: CGMouseButton
        if heldMouse.contains(.left) {
            (type, button) = (.leftMouseDragged, .left)
        } else if heldMouse.contains(.right) {
            (type, button) = (.rightMouseDragged, .right)
        } else if heldMouse.contains(.middle) {
            (type, button) = (.otherMouseDragged, .center)
        } else {
            (type, button) = (.mouseMoved, .left)
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: position, mouseButton: button) else { return }
        // Games that capture the mouse (cursor locked, e.g. FPS camera
        // look) read the relative delta fields, not the absolute position.
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(stepX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(stepY))
        event.post(tap: .cghidEventTap)
    }

    /// Drops any sub-pixel remainder (e.g. when the bridge stops) so stale
    /// motion doesn't leak into the next session.
    func resetMotion() {
        pendingDX = 0
        pendingDY = 0
    }

    private func postKey(_ code: CGKeyCode, down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)?
            .post(tap: .cghidEventTap)
    }

    private func postMouse(_ button: MouseButton, down: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let position = CGEvent(source: nil)?.location ?? .zero
        CGEvent(mouseEventSource: source,
                mouseType: button.eventType(down: down),
                mouseCursorPosition: position,
                mouseButton: button.cgButton)?
            .post(tap: .cghidEventTap)
    }
}
