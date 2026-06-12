import Foundation
import QuartzCore

/// One frame of mapped output: the virtual pad report plus the keyboard
/// keys and mouse buttons that should currently be held.
struct MappedOutput {
    var report = GamepadReport()
    var keys: Set<CGKeyCode> = []
    var mouseButtons: Set<MouseButton> = []
    /// Cursor movement in pixels for this frame (pad-mouse + gyro-mouse).
    var mouseDX = 0.0
    var mouseDY = 0.0
    /// Trackpad tick haptics to fire this frame (lizard-mode feel).
    var leftPadTick = false
    var rightPadTick = false
}

/// Translates parsed controller state into mapped output, driven by the
/// user's Profile. Stateful: gyro aiming needs drift-bias tracking across
/// reports, and turbo needs a clock.
final class MappingEngine {
    private struct ResolvedBinding {
        let mask: SCButtons
        let output: OutputAction
        let turbo: Bool
    }

    /// True when any binding targets the keyboard or mouse (drives the
    /// Accessibility permission prompt).
    private(set) var usesKeyboardMouse = false

    private var bindings: [ResolvedBinding] = []
    private var turboInterval = 0.08
    private var padSticksEnabled = true
    private var padDeadZone = 800
    private var padSensitivity = 100
    private var padMouseEnabled = false
    private var padMouseIsRight = true
    private var padMouseDivisor = 65
    private var stickKeysEnabled = false
    private var stickKeysIsLeft = true
    private var stickKeysDeadZone = 1500
    private var stickKeysOutputs: (up: OutputAction, down: OutputAction,
                                   left: OutputAction, right: OutputAction) =
        (.none, .none, .none, .none)
    private var stickMouseEnabled = false
    private var stickMouseIsRight = true
    private var stickMouseDeadZone = 1500
    private var stickMouseMaxSpeed = 1200.0
    enum GyroActivator {
        case always
        case leftTrigger
        case rightTrigger
        case buttons(SCButtons)

        /// Parses a profile activation string; see Profile.Gyro.activation.
        static func parse(_ string: String) -> GyroActivator? {
            switch string {
            case "always": return .always
            case "leftTrigger": return .leftTrigger
            case "rightTrigger": return .rightTrigger
            case "leftPadTouch": return .buttons(.lPadActive)
            case "rightPadTouch": return .buttons(.rPadActive)
            case "leftStickTouch": return .buttons(.lStickTouch)
            case "rightStickTouch": return .buttons(.rStickTouch)
            default:
                guard let input = PhysicalInput(rawValue: string) else { return nil }
                return .buttons(input.buttonMask)
            }
        }
    }

    private var gyroEnabled = true
    private var gyroToMouse = false
    private var gyroActivator: GyroActivator = .leftTrigger
    private var gyroSuppressMode = false
    private var gyroActivationThreshold: UInt8 = 64
    private var gyroDeadZone = 45
    private var gyroSensitivity = 26
    private var gyroMouseSensitivity = 0.018
    /// Max cursor movement per report from gyro (pixels), from the Windows app.
    private let gyroMouseClamp = 24.0
    /// Bias learning weights from the Windows app: fast on activation,
    /// slow drift-tracking while inactive.
    private let gyroBiasFastWeight = 0.65
    private let gyroBiasSlowWeight = 0.04

    private var gyroBiasYaw = 0.0
    private var gyroBiasPitch = 0.0
    private var gyroWasActive = false
    private var padMouseWasTouched = false
    private var padMouseLastX = 0
    private var padMouseLastY = 0
    private var lastMapTime: Double?

    /// Finger travel (raw units) per haptic tick, and the tick loudness.
    private let padTickTravel = 1400
    private let padTickGainDB: Int8 = -24
    private let padTickMinInterval = 0.012
    private struct PadTickState {
        var wasTouched = false
        var lastX = 0
        var lastY = 0
        var lastTickTime = 0.0
    }
    private var leftPadTickState = PadTickState()
    private var rightPadTickState = PadTickState()

    init(profile: Profile) {
        apply(profile)
    }

    func apply(_ profile: Profile) {
        var resolved: [ResolvedBinding] = []
        let map = profile.bindings ?? Profile.defaultProfile.bindings!
        for (key, binding) in map {
            guard let input = PhysicalInput(rawValue: key), binding.output != .none else { continue }
            resolved.append(ResolvedBinding(mask: input.buttonMask,
                                            output: binding.output,
                                            turbo: binding.turbo ?? false))
        }
        bindings = resolved
        usesKeyboardMouse = resolved.contains {
            if case .key = $0.output { return true }
            if case .mouse = $0.output { return true }
            return false
        }
        turboInterval = Double(min(max(profile.turboIntervalMs ?? 80, 25), 500)) / 1000.0

        padSticksEnabled = profile.padSticks?.enabled ?? true
        padDeadZone = profile.padSticks?.deadZone ?? 800
        padSensitivity = profile.padSticks?.sensitivityPercent ?? 100
        padMouseEnabled = profile.padMouse?.enabled ?? false
        padMouseIsRight = (profile.padMouse?.pad ?? "right") != "left"
        padMouseDivisor = max(profile.padMouse?.sensitivityDivisor ?? 65, 1)
        stickKeysEnabled = profile.stickKeys?.enabled ?? false
        stickKeysIsLeft = (profile.stickKeys?.stick ?? "left") != "right"
        stickKeysDeadZone = profile.stickKeys?.deadZone ?? 1500
        stickKeysOutputs = (profile.stickKeys?.up ?? .none,
                            profile.stickKeys?.down ?? .none,
                            profile.stickKeys?.left ?? .none,
                            profile.stickKeys?.right ?? .none)
        stickMouseEnabled = profile.stickMouse?.enabled ?? false
        stickMouseIsRight = (profile.stickMouse?.stick ?? "right") != "left"
        stickMouseDeadZone = profile.stickMouse?.deadZone ?? 1500
        stickMouseMaxSpeed = profile.stickMouse?.maxSpeed ?? 1200
        gyroEnabled = profile.gyro?.enabled ?? true
        gyroToMouse = profile.gyro?.output == "mouse"
        gyroActivator = GyroActivator.parse(profile.gyro?.activation ?? "leftTrigger") ?? .leftTrigger
        gyroSuppressMode = profile.gyro?.activationMode == "suppress"
        gyroActivationThreshold = UInt8(clamping: profile.gyro?.activationThreshold ?? 64)
        gyroDeadZone = profile.gyro?.deadZone ?? 45
        gyroSensitivity = min(max(profile.gyro?.sensitivity ?? 26, 1), 80)
        gyroMouseSensitivity = profile.gyro?.mouseSensitivity ?? 0.018

        if padMouseEnabled || stickMouseEnabled || (gyroEnabled && gyroToMouse) {
            usesKeyboardMouse = true
        }
        if stickKeysEnabled {
            for action in [stickKeysOutputs.up, stickKeysOutputs.down,
                           stickKeysOutputs.left, stickKeysOutputs.right] {
                if case .key = action { usesKeyboardMouse = true }
                if case .mouse = action { usesKeyboardMouse = true }
            }
        }
    }

    func map(_ input: InputState) -> MappedOutput {
        var output = MappedOutput()
        var report = GamepadReport()
        var buttons: GamepadReport.Buttons = []
        var dpad = (up: false, down: false, left: false, right: false)

        let now = CACurrentMediaTime()
        // Frame time for velocity-based outputs; clamped so a stall can't
        // fling the cursor.
        let dt = min(max(now - (lastMapTime ?? now), 0), 0.05)
        lastMapTime = now
        // Turbo pulses on a shared phase so multiple turbo buttons stay in sync.
        let turboPhaseOn = Int(now / turboInterval) % 2 == 0

        for binding in bindings where input.buttons.contains(binding.mask) {
            if binding.turbo && !turboPhaseOn { continue }
            emit(binding.output, into: &output, buttons: &buttons, dpad: &dpad)
        }
        report.leftTrigger = input.leftTrigger
        report.rightTrigger = input.rightTrigger

        // Axes are computed in controller space (Y up-positive) and flipped
        // to the HID convention (Y down-positive) at the end.
        var leftX = Int(input.leftStickX)
        var leftY = Int(input.leftStickY)
        var rightX = Int(input.rightStickX)
        var rightY = Int(input.rightStickY)

        // Trackpad tick haptics: a quiet click on touch-down and per unit of
        // finger travel, recreating the lizard-mode feel.
        output.leftPadTick = padTick(&leftPadTickState, now: now,
                                     touched: input.buttons.contains(.lPadActive),
                                     x: Int(input.leftPadX), y: Int(input.leftPadY))
        output.rightPadTick = padTick(&rightPadTickState, now: now,
                                      touched: input.buttons.contains(.rPadActive),
                                      x: Int(input.rightPadX), y: Int(input.rightPadY))

        // Pad-as-mouse: laptop-trackpad-style cursor deltas from finger travel.
        if padMouseEnabled {
            let touched = input.buttons.contains(padMouseIsRight ? .rPadActive : .lPadActive)
            let padX = Int(padMouseIsRight ? input.rightPadX : input.leftPadX)
            let padY = Int(padMouseIsRight ? input.rightPadY : input.leftPadY)
            if touched {
                if padMouseWasTouched {
                    output.mouseDX += Double(padX - padMouseLastX) / Double(padMouseDivisor)
                    output.mouseDY += -Double(padY - padMouseLastY) / Double(padMouseDivisor)
                }
                padMouseLastX = padX
                padMouseLastY = padY
            }
            padMouseWasTouched = touched
        }

        // Trackpads drive their stick while touched (unless on mouse duty).
        if padSticksEnabled {
            if input.buttons.contains(.lPadActive), !(padMouseEnabled && !padMouseIsRight) {
                (leftX, leftY) = padAsStick(x: input.leftPadX, y: input.leftPadY)
            }
            if input.buttons.contains(.rPadActive), !(padMouseEnabled && padMouseIsRight) {
                (rightX, rightY) = padAsStick(x: input.rightPadX, y: input.rightPadY)
            }
        }

        // Gyro aiming while L2 is held: right stick blend or cursor movement.
        if let (yaw, pitch) = gyroCorrected(input) {
            if gyroToMouse {
                output.mouseDX += gyroMouseDelta(-yaw)
                output.mouseDY += gyroMouseDelta(-pitch)
            } else {
                rightX += gyroStickDeflection(-yaw)
                rightY += gyroStickDeflection(-pitch)
            }
        }

        // Stick-to-keys (e.g. WASD): cardinal directions emit outputs and
        // the stick stops driving its virtual axis.
        if stickKeysEnabled {
            let sx = stickKeysIsLeft ? leftX : rightX
            let sy = stickKeysIsLeft ? leftY : rightY
            if sy > stickKeysDeadZone { emit(stickKeysOutputs.up, into: &output, buttons: &buttons, dpad: &dpad) }
            if sy < -stickKeysDeadZone { emit(stickKeysOutputs.down, into: &output, buttons: &buttons, dpad: &dpad) }
            if sx < -stickKeysDeadZone { emit(stickKeysOutputs.left, into: &output, buttons: &buttons, dpad: &dpad) }
            if sx > stickKeysDeadZone { emit(stickKeysOutputs.right, into: &output, buttons: &buttons, dpad: &dpad) }
            if stickKeysIsLeft { (leftX, leftY) = (0, 0) } else { (rightX, rightY) = (0, 0) }
        }

        // Stick-to-mouse: deflection becomes cursor velocity, and the stick
        // stops driving its virtual axis.
        if stickMouseEnabled {
            let sx = stickMouseIsRight ? rightX : leftX
            let sy = stickMouseIsRight ? rightY : leftY
            func velocity(_ value: Int) -> Double {
                guard abs(value) >= stickMouseDeadZone else { return 0 }
                return Double(value) / 32767.0 * stickMouseMaxSpeed
            }
            output.mouseDX += velocity(sx) * dt
            output.mouseDY += -velocity(sy) * dt
            if stickMouseIsRight { (rightX, rightY) = (0, 0) } else { (leftX, leftY) = (0, 0) }
        }

        report.buttons = buttons
        report.hat = hatValue(up: dpad.up, down: dpad.down, left: dpad.left, right: dpad.right)
        report.leftStickX = Int16(clamping: leftX)
        report.leftStickY = flipY(Int16(clamping: leftY))
        report.rightStickX = Int16(clamping: rightX)
        report.rightStickY = flipY(Int16(clamping: rightY))
        output.report = report
        return output
    }

    /// Routes one output action into the right bucket (pad button, dpad,
    /// key, or mouse button).
    private func emit(_ action: OutputAction, into output: inout MappedOutput,
                      buttons: inout GamepadReport.Buttons,
                      dpad: inout (up: Bool, down: Bool, left: Bool, right: Bool)) {
        switch action {
        case .none:
            break
        case .button(let button):
            buttons.insert(button)
        case .dpad(.up): dpad.up = true
        case .dpad(.down): dpad.down = true
        case .dpad(.left): dpad.left = true
        case .dpad(.right): dpad.right = true
        case .key(let code):
            output.keys.insert(code)
        case .mouse(let button):
            output.mouseButtons.insert(button)
        }
    }

    /// The tick gain, exposed so the pipeline sends a consistent loudness.
    var padTickGain: Int8 { padTickGainDB }

    /// True when a haptic tick should fire: on touch-down, then every
    /// `padTickTravel` raw units of finger movement, rate-limited.
    private func padTick(_ state: inout PadTickState, now: Double,
                         touched: Bool, x: Int, y: Int) -> Bool {
        defer { state.wasTouched = touched }
        guard touched else { return false }
        if !state.wasTouched {
            (state.lastX, state.lastY, state.lastTickTime) = (x, y, now)
            return true
        }
        let travel = abs(x - state.lastX) + abs(y - state.lastY)
        guard travel >= padTickTravel,
              now - state.lastTickTime >= padTickMinInterval else { return false }
        (state.lastX, state.lastY, state.lastTickTime) = (x, y, now)
        return true
    }

    /// Treats the absolute touch position as stick deflection.
    private func padAsStick(x: Int16, y: Int16) -> (Int, Int) {
        func scale(_ value: Int16) -> Int {
            guard abs(Int(value)) >= padDeadZone else { return 0 }
            return Int(value) * padSensitivity / 100
        }
        return (scale(x), scale(y))
    }

    /// Bias-corrected gyro yaw/pitch while aiming is active, nil otherwise.
    /// Bias learns fast at activation and drifts slowly while idle, so
    /// resting orientation never accumulates into aim.
    private func gyroCorrected(_ input: InputState) -> (yaw: Double, pitch: Double)? {
        guard gyroEnabled else { return nil }
        let rawYaw = Double(input.gyroZ)
        let rawPitch = Double(input.gyroX)
        let held: Bool
        switch gyroActivator {
        case .always: held = true
        case .leftTrigger: held = input.leftTrigger >= gyroActivationThreshold
        case .rightTrigger: held = input.rightTrigger >= gyroActivationThreshold
        case .buttons(let mask): held = input.buttons.contains(mask)
        }
        let active = gyroSuppressMode ? !held : held

        if !active {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * gyroBiasSlowWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * gyroBiasSlowWeight
        } else if !gyroWasActive {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * gyroBiasFastWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * gyroBiasFastWeight
        }
        gyroWasActive = active
        guard active else { return nil }
        return (rawYaw - gyroBiasYaw, rawPitch - gyroBiasPitch)
    }

    private func gyroStickDeflection(_ value: Double) -> Int {
        guard abs(value) >= Double(gyroDeadZone) else { return 0 }
        return Int(value * Double(gyroSensitivity))
    }

    private func gyroMouseDelta(_ value: Double) -> Double {
        guard abs(value) >= Double(gyroDeadZone) else { return 0 }
        return min(max(value * gyroMouseSensitivity, -gyroMouseClamp), gyroMouseClamp)
    }

    /// Hat values run 0-7 clockwise from north; nil when centered.
    private func hatValue(up: Bool, down: Bool, left: Bool, right: Bool) -> UInt8? {
        switch (up, down, left, right) {
        case (true, false, false, false): return 0
        case (true, false, false, true):  return 1
        case (false, false, false, true): return 2
        case (false, true, false, true):  return 3
        case (false, true, false, false): return 4
        case (false, true, true, false):  return 5
        case (false, false, true, false): return 6
        case (true, false, true, false):  return 7
        default: return nil
        }
    }

    /// Controller axes are up-positive; HID Y axes are down-positive.
    private func flipY(_ value: Int16) -> Int16 {
        value == .min ? .max : -value
    }
}
