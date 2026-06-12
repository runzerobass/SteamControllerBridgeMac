import Foundation

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

/// What a physical input produces on the virtual pad.
/// (Keyboard/mouse outputs arrive with the Phase 3 backend.)
enum OutputAction: String, Codable, CaseIterable {
    case none
    case a, b, x, y
    case leftBumper, rightBumper
    case back, start, guide
    case leftStickClick, rightStickClick
    case dpadUp, dpadDown, dpadLeft, dpadRight
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
            .a: .a, .b: .b, .x: .x, .y: .y,
            .leftBumper: .leftBumper, .rightBumper: .rightBumper,
            .view: .back, .menu: .start, .steam: .guide, .quickAccess: .none,
            .leftStickClick: .leftStickClick, .rightStickClick: .rightStickClick,
            .l4: .y, .l5: .x, .r4: .b, .r5: .a,
            .leftGrip: .none, .rightGrip: .none,
            .dpadUp: .dpadUp, .dpadDown: .dpadDown,
            .dpadLeft: .dpadLeft, .dpadRight: .dpadRight,
            .leftPadClick: .leftStickClick, .rightPadClick: .rightStickClick,
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
