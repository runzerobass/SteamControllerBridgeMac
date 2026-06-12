import Foundation
import CoreGraphics

/// A mappable physical control on the Steam Controller.
enum PhysicalInput: String, Codable, CaseIterable {
    case a, b, x, y
    case leftBumper, rightBumper
    case view, menu, steam, quickAccess
    case leftStickClick, rightStickClick
    case l4, l5, r4, r5
    case leftGrip, rightGrip
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftPadClick, rightPadClick
    case leftTriggerFull, rightTriggerFull

    var buttonMask: SCButtons {
        switch self {
        case .a: return .btnA
        case .b: return .btnB
        case .x: return .btnX
        case .y: return .btnY
        case .leftBumper: return .btnLB
        case .rightBumper: return .btnRB
        case .view: return .btnSelect
        case .menu: return .btnStart
        case .steam: return .btnSteam
        case .quickAccess: return .btnQAM
        case .leftStickClick: return .lStickClick
        case .rightStickClick: return .rStickClick
        case .l4: return .btnL4
        case .l5: return .btnL5
        case .r4: return .btnR4
        case .r5: return .btnR5
        case .leftGrip: return .lGrip
        case .rightGrip: return .rGrip
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .leftPadClick: return .lPadClick
        case .rightPadClick: return .rPadClick
        case .leftTriggerFull: return .lTrigFull
        case .rightTriggerFull: return .rTrigFull
        }
    }
}

enum DpadDirection: String {
    case up, down, left, right
}

/// What a physical input produces: a virtual pad button, a dpad direction,
/// a keyboard key, or a mouse button. Encoded in JSON as a single string:
/// gamepad names ("a", "leftBumper", "dpadUp", …), "key:<name>" (e.g.
/// "key:space"), or "mouse:left|right|middle".
enum OutputAction: Codable, Equatable {
    case none
    case button(GamepadReport.Buttons)
    case dpad(DpadDirection)
    case key(CGKeyCode)
    case mouse(MouseButton)

    private static let buttonNames: [String: GamepadReport.Buttons] = [
        "a": .a, "b": .b, "x": .x, "y": .y,
        "leftBumper": .leftBumper, "rightBumper": .rightBumper,
        "back": .back, "start": .start, "guide": .guide,
        "leftStickClick": .leftThumb, "rightStickClick": .rightThumb,
    ]

    init?(string: String) {
        if string == "none" {
            self = .none
        } else if let button = Self.buttonNames[string] {
            self = .button(button)
        } else if string.hasPrefix("dpad"),
                  let direction = DpadDirection(rawValue: String(string.dropFirst(4)).lowercased()) {
            self = .dpad(direction)
        } else if string.hasPrefix("key:"),
                  let code = KeyCodes.byName[String(string.dropFirst(4)).lowercased()] {
            self = .key(code)
        } else if string.hasPrefix("mouse:"),
                  let button = MouseButton(rawValue: String(string.dropFirst(6)).lowercased()) {
            self = .mouse(button)
        } else {
            return nil
        }
    }

    var stringValue: String {
        switch self {
        case .none: return "none"
        case .button(let b): return Self.buttonNames.first { $0.value == b }?.key ?? "none"
        case .dpad(let d): return "dpad" + d.rawValue.prefix(1).uppercased() + d.rawValue.dropFirst()
        case .key(let code): return "key:" + (KeyCodes.name(for: code) ?? "none")
        case .mouse(let b): return "mouse:" + b.rawValue
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let action = OutputAction(string: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown output \"\(raw)\" — see README for valid outputs"))
        }
        self = action
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

/// User-editable mapping profile, stored as JSON. All fields are optional so
/// hand-edited files with missing keys fall back to defaults gracefully.
struct Profile: Codable {
    struct Binding: Codable {
        var output: OutputAction
        var turbo: Bool?
    }

    struct Sticks: Codable {
        /// Radial deadzone for the physical sticks' virtual-pad output
        /// (raw units, rescaled so motion ramps smoothly from the edge).
        var deadZone: Int?
    }

    struct PadSticks: Codable {
        var enabled: Bool?
        /// Pad deflection below this is ignored (raw units).
        var deadZone: Int?
        var sensitivityPercent: Int?
    }

    struct StickKeys: Codable {
        var enabled: Bool?
        /// Which stick: "left" (default) or "right".
        var stick: String?
        /// Deflection below this is ignored (raw units).
        var deadZone: Int?
        /// Output per cardinal direction; any output form works
        /// (keys, mouse buttons, even gamepad buttons).
        var up: OutputAction?
        var down: OutputAction?
        var left: OutputAction?
        var right: OutputAction?
    }

    struct StickMouse: Codable {
        var enabled: Bool?
        /// Which stick: "left" or "right" (default).
        var stick: String?
        var deadZone: Int?
        /// Cursor speed in pixels/second at full deflection.
        var maxSpeed: Double?
    }

    struct PadMouse: Codable {
        var enabled: Bool?
        /// Which pad drives the cursor: "left" or "right".
        var pad: String?
        /// Finger-travel divisor; lower = faster cursor (default 65).
        var sensitivityDivisor: Int?
    }

    struct Gyro: Codable {
        var enabled: Bool?
        /// Where gyro aim goes: "rightStick" (default) or "mouse".
        var output: String?
        /// What gates gyro aiming: "always", "leftTrigger" (default),
        /// "rightTrigger", "leftPadTouch", "rightPadTouch",
        /// "leftStickTouch", "rightStickTouch", or any physical input name.
        var activation: String?
        /// "hold" (default): gyro is on while the activator is held.
        /// "suppress": gyro is on except while the activator is held.
        var activationMode: String?
        /// Trigger value (0-255) that counts as held, for trigger activators.
        var activationThreshold: Int?
        var deadZone: Int?
        /// Right-stick deflection multiplier (used when output is rightStick).
        var sensitivity: Int?
        /// Pixels per raw gyro unit (used when output is mouse).
        var mouseSensitivity: Double?
    }

    var name: String?
    /// Turbo pulse interval in milliseconds (clamped 25-500).
    var turboIntervalMs: Int?
    /// Keys are PhysicalInput raw values; unknown keys are ignored.
    var bindings: [String: Binding]?
    var sticks: Sticks?
    var padSticks: PadSticks?
    var padMouse: PadMouse?
    var stickKeys: StickKeys?
    var stickMouse: StickMouse?
    var gyro: Gyro?

    /// The built-in layout: the Windows app's defaults (paddles double as
    /// face buttons), pads-as-sticks and gyro aiming enabled.
    static var defaultProfile: Profile {
        var bindings: [String: Binding] = [:]
        let defaults: [PhysicalInput: OutputAction] = [
            .a: .button(.a), .b: .button(.b), .x: .button(.x), .y: .button(.y),
            .leftBumper: .button(.leftBumper), .rightBumper: .button(.rightBumper),
            .view: .button(.back), .menu: .button(.start), .steam: .button(.guide),
            .quickAccess: .none,
            .leftStickClick: .button(.leftThumb), .rightStickClick: .button(.rightThumb),
            .l4: .button(.y), .l5: .button(.x), .r4: .button(.b), .r5: .button(.a),
            .leftGrip: .none, .rightGrip: .none,
            .dpadUp: .dpad(.up), .dpadDown: .dpad(.down),
            .dpadLeft: .dpad(.left), .dpadRight: .dpad(.right),
            .leftPadClick: .button(.leftThumb), .rightPadClick: .button(.rightThumb),
            .leftTriggerFull: .none, .rightTriggerFull: .none,
        ]
        for (input, output) in defaults {
            bindings[input.rawValue] = Binding(output: output, turbo: false)
        }
        return Profile(
            name: "Default",
            turboIntervalMs: 80,
            bindings: bindings,
            sticks: Sticks(deadZone: 2500),
            padSticks: PadSticks(enabled: true, deadZone: 800, sensitivityPercent: 100),
            padMouse: PadMouse(enabled: false, pad: "right", sensitivityDivisor: 65),
            stickKeys: StickKeys(enabled: false, stick: "left", deadZone: 1500,
                                 up: .key(KeyCodes.byName["w"]!), down: .key(KeyCodes.byName["s"]!),
                                 left: .key(KeyCodes.byName["a"]!), right: .key(KeyCodes.byName["d"]!)),
            stickMouse: StickMouse(enabled: false, stick: "right", deadZone: 1500, maxSpeed: 1200),
            gyro: Gyro(enabled: true, output: "rightStick", activation: "leftTrigger",
                       activationMode: "hold", activationThreshold: 64,
                       deadZone: 45, sensitivity: 26, mouseSensitivity: 0.018))
    }
}

// MARK: - Presets

extension Profile {
    static let presets: [(name: String, profile: Profile)] = [
        ("Default", .defaultProfile),
        ("Nintendo Swap", .nintendoSwap),
        ("Desktop Mouse", .desktopMouse),
        ("FPS Keyboard & Mouse", .fpsKeyboardMouse),
    ]

    /// Physical A/B and X/Y swapped for Nintendo-style layouts.
    static var nintendoSwap: Profile {
        var preset = defaultProfile
        preset.name = "Nintendo Swap"
        preset.bindings?[PhysicalInput.a.rawValue] = Binding(output: .button(.b), turbo: false)
        preset.bindings?[PhysicalInput.b.rawValue] = Binding(output: .button(.a), turbo: false)
        preset.bindings?[PhysicalInput.x.rawValue] = Binding(output: .button(.y), turbo: false)
        preset.bindings?[PhysicalInput.y.rawValue] = Binding(output: .button(.x), turbo: false)
        preset.bindings?[PhysicalInput.r5.rawValue] = Binding(output: .button(.b), turbo: false)
        preset.bindings?[PhysicalInput.r4.rawValue] = Binding(output: .button(.a), turbo: false)
        preset.bindings?[PhysicalInput.l5.rawValue] = Binding(output: .button(.y), turbo: false)
        preset.bindings?[PhysicalInput.l4.rawValue] = Binding(output: .button(.x), turbo: false)
        return preset
    }

    /// Drive macOS: pads/sticks move the cursor, triggers click, dpad arrows.
    static var desktopMouse: Profile {
        var preset = defaultProfile
        preset.name = "Desktop Mouse"
        preset.padMouse = PadMouse(enabled: true, pad: "right", sensitivityDivisor: 65)
        preset.stickMouse = StickMouse(enabled: true, stick: "right", deadZone: 1500, maxSpeed: 1200)
        preset.gyro?.enabled = false
        var b = preset.bindings ?? [:]
        b[PhysicalInput.a.rawValue] = Binding(output: .mouse(.left), turbo: false)
        b[PhysicalInput.b.rawValue] = Binding(output: .mouse(.right), turbo: false)
        b[PhysicalInput.rightPadClick.rawValue] = Binding(output: .mouse(.left), turbo: false)
        b[PhysicalInput.rightTriggerFull.rawValue] = Binding(output: .mouse(.left), turbo: false)
        b[PhysicalInput.leftTriggerFull.rawValue] = Binding(output: .mouse(.right), turbo: false)
        b[PhysicalInput.dpadUp.rawValue] = Binding(output: .key(KeyCodes.byName["up"]!), turbo: false)
        b[PhysicalInput.dpadDown.rawValue] = Binding(output: .key(KeyCodes.byName["down"]!), turbo: false)
        b[PhysicalInput.dpadLeft.rawValue] = Binding(output: .key(KeyCodes.byName["left"]!), turbo: false)
        b[PhysicalInput.dpadRight.rawValue] = Binding(output: .key(KeyCodes.byName["right"]!), turbo: false)
        b[PhysicalInput.menu.rawValue] = Binding(output: .key(KeyCodes.byName["return"]!), turbo: false)
        b[PhysicalInput.view.rawValue] = Binding(output: .key(KeyCodes.byName["escape"]!), turbo: false)
        preset.bindings = b
        return preset
    }

    /// Keyboard/mouse FPS controls: WASD, pad+gyro aim, trigger clicks.
    static var fpsKeyboardMouse: Profile {
        var preset = defaultProfile
        preset.name = "FPS Keyboard & Mouse"
        preset.stickKeys = StickKeys(enabled: true, stick: "left", deadZone: 1500,
                                     up: .key(KeyCodes.byName["w"]!), down: .key(KeyCodes.byName["s"]!),
                                     left: .key(KeyCodes.byName["a"]!), right: .key(KeyCodes.byName["d"]!))
        preset.padMouse = PadMouse(enabled: true, pad: "right", sensitivityDivisor: 65)
        preset.gyro = Gyro(enabled: true, output: "mouse", activation: "rightPadTouch",
                           activationMode: "hold", activationThreshold: 64,
                           deadZone: 45, sensitivity: 26, mouseSensitivity: 0.018)
        var b = preset.bindings ?? [:]
        b[PhysicalInput.a.rawValue] = Binding(output: .key(KeyCodes.byName["space"]!), turbo: false)
        b[PhysicalInput.b.rawValue] = Binding(output: .key(KeyCodes.byName["control"]!), turbo: false)
        b[PhysicalInput.x.rawValue] = Binding(output: .key(KeyCodes.byName["r"]!), turbo: false)
        b[PhysicalInput.y.rawValue] = Binding(output: .key(KeyCodes.byName["f"]!), turbo: false)
        b[PhysicalInput.leftBumper.rawValue] = Binding(output: .key(KeyCodes.byName["q"]!), turbo: false)
        b[PhysicalInput.rightBumper.rawValue] = Binding(output: .key(KeyCodes.byName["e"]!), turbo: false)
        b[PhysicalInput.leftStickClick.rawValue] = Binding(output: .key(KeyCodes.byName["shift"]!), turbo: false)
        b[PhysicalInput.rightTriggerFull.rawValue] = Binding(output: .mouse(.left), turbo: false)
        b[PhysicalInput.leftTriggerFull.rawValue] = Binding(output: .mouse(.right), turbo: false)
        b[PhysicalInput.menu.rawValue] = Binding(output: .key(KeyCodes.byName["escape"]!), turbo: false)
        preset.bindings = b
        return preset
    }
}
