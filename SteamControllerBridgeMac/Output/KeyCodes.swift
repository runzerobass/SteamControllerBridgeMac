import CoreGraphics

/// Human-readable key names (used in profile.json as "key:<name>") mapped to
/// macOS virtual key codes (ANSI layout).
enum KeyCodes {
    static let byName: [String: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
        "equal": 0x18, "9": 0x19, "7": 0x1A, "minus": 0x1B, "8": 0x1C, "0": 0x1D,
        "rightbracket": 0x1E, "o": 0x1F, "u": 0x20, "leftbracket": 0x21,
        "i": 0x22, "p": 0x23, "return": 0x24, "enter": 0x24,
        "l": 0x25, "j": 0x26, "quote": 0x27, "k": 0x28, "semicolon": 0x29,
        "backslash": 0x2A, "comma": 0x2B, "slash": 0x2C, "n": 0x2D, "m": 0x2E,
        "period": 0x2F, "tab": 0x30, "space": 0x31, "grave": 0x32,
        "backspace": 0x33, "delete": 0x33, "escape": 0x35,
        "command": 0x37, "shift": 0x38, "capslock": 0x39, "option": 0x3A,
        "alt": 0x3A, "control": 0x3B, "ctrl": 0x3B,
        "rightshift": 0x3C, "rightoption": 0x3D, "rightcontrol": 0x3E,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f3": 0x63, "f8": 0x64, "f9": 0x65,
        "f11": 0x67, "f10": 0x6D, "f12": 0x6F,
        "home": 0x73, "pageup": 0x74, "forwarddelete": 0x75, "f4": 0x76,
        "end": 0x77, "f2": 0x78, "pagedown": 0x79, "f1": 0x7A,
        "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
    ]

    /// Display/encode order; excludes aliases (enter, delete, ctrl, alt) so
    /// round-tripping a code back to a name is deterministic.
    static let canonicalNames: [String] = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
        "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "space", "return", "tab", "escape",
        "shift", "control", "option", "command",
        "rightshift", "rightcontrol", "rightoption", "capslock",
        "backspace", "forwarddelete",
        "up", "down", "left", "right",
        "home", "end", "pageup", "pagedown",
        "grave", "minus", "equal", "leftbracket", "rightbracket",
        "backslash", "semicolon", "quote", "comma", "period", "slash",
        "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12",
    ]

    static func name(for code: CGKeyCode) -> String? {
        canonicalNames.first { byName[$0] == code }
            ?? byName.first { $0.value == code }?.key
    }
}

/// Mouse buttons available as binding outputs ("mouse:<name>").
enum MouseButton: String, CaseIterable {
    case left, right, middle

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    func eventType(down: Bool) -> CGEventType {
        switch self {
        case .left: return down ? .leftMouseDown : .leftMouseUp
        case .right: return down ? .rightMouseDown : .rightMouseUp
        case .middle: return down ? .otherMouseDown : .otherMouseUp
        }
    }
}
