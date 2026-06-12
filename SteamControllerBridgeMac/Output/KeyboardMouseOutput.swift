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
