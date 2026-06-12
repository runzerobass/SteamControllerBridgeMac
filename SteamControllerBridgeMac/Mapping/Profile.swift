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

    struct PadSticks: Codable {
        var enabled: Bool?
        /// Pad deflection below this is ignored (raw units).
        var deadZone: Int?
        var sensitivityPercent: Int?
    }

    struct Gyro: Codable {
        var enabled: Bool?
        /// Left-trigger value (0-255) that turns gyro aiming on.
        var activationThreshold: Int?
        var deadZone: Int?
        var sensitivity: Int?
    }

    var name: String?
    /// Turbo pulse interval in milliseconds (clamped 25-500).
    var turboIntervalMs: Int?
    /// Keys are PhysicalInput raw values; unknown keys are ignored.
    var bindings: [String: Binding]?
    var padSticks: PadSticks?
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
            padSticks: PadSticks(enabled: true, deadZone: 800, sensitivityPercent: 100),
            gyro: Gyro(enabled: true, activationThreshold: 64, deadZone: 45, sensitivity: 26))
    }
}
