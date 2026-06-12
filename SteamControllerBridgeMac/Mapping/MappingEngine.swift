import Foundation
import QuartzCore

/// Translates parsed controller state into virtual gamepad reports,
/// driven by the user's Profile. Stateful: gyro aiming needs drift-bias
/// tracking across reports, and turbo needs a clock.
final class MappingEngine {
    private struct ResolvedBinding {
        let mask: SCButtons
        let output: OutputAction
        let turbo: Bool
    }

    private var bindings: [ResolvedBinding] = []
    private var turboInterval = 0.08
    private var padSticksEnabled = true
    private var padDeadZone = 800
    private var padSensitivity = 100
    private var gyroEnabled = true
    private var gyroActivationThreshold: UInt8 = 64
    private var gyroDeadZone = 45
    private var gyroSensitivity = 26
    /// Bias learning weights from the Windows app: fast on activation,
    /// slow drift-tracking while inactive.
    private let gyroBiasFastWeight = 0.65
    private let gyroBiasSlowWeight = 0.04

    private var gyroBiasYaw = 0.0
    private var gyroBiasPitch = 0.0
    private var gyroWasActive = false

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
        turboInterval = Double(min(max(profile.turboIntervalMs ?? 80, 25), 500)) / 1000.0

        padSticksEnabled = profile.padSticks?.enabled ?? true
        padDeadZone = profile.padSticks?.deadZone ?? 800
        padSensitivity = profile.padSticks?.sensitivityPercent ?? 100
        gyroEnabled = profile.gyro?.enabled ?? true
        gyroActivationThreshold = UInt8(clamping: profile.gyro?.activationThreshold ?? 64)
        gyroDeadZone = profile.gyro?.deadZone ?? 45
        gyroSensitivity = min(max(profile.gyro?.sensitivity ?? 26, 1), 80)
    }

    func map(_ input: InputState) -> GamepadReport {
        var report = GamepadReport()
        var buttons: GamepadReport.Buttons = []
        var dpad = (up: false, down: false, left: false, right: false)

        // Turbo pulses on a shared phase so multiple turbo buttons stay in sync.
        let turboPhaseOn = Int(CACurrentMediaTime() / turboInterval) % 2 == 0

        for binding in bindings where input.buttons.contains(binding.mask) {
            if binding.turbo && !turboPhaseOn { continue }
            switch binding.output {
            case .none: break
            case .a: buttons.insert(.a)
            case .b: buttons.insert(.b)
            case .x: buttons.insert(.x)
            case .y: buttons.insert(.y)
            case .leftBumper: buttons.insert(.leftBumper)
            case .rightBumper: buttons.insert(.rightBumper)
            case .back: buttons.insert(.back)
            case .start: buttons.insert(.start)
            case .guide: buttons.insert(.guide)
            case .leftStickClick: buttons.insert(.leftThumb)
            case .rightStickClick: buttons.insert(.rightThumb)
            case .dpadUp: dpad.up = true
            case .dpadDown: dpad.down = true
            case .dpadLeft: dpad.left = true
            case .dpadRight: dpad.right = true
            }
        }
        report.buttons = buttons
        report.hat = hatValue(up: dpad.up, down: dpad.down, left: dpad.left, right: dpad.right)
        report.leftTrigger = input.leftTrigger
        report.rightTrigger = input.rightTrigger

        // Axes are computed in controller space (Y up-positive) and flipped
        // to the HID convention (Y down-positive) at the end.
        var leftX = Int(input.leftStickX)
        var leftY = Int(input.leftStickY)
        var rightX = Int(input.rightStickX)
        var rightY = Int(input.rightStickY)

        // Trackpads drive their stick while touched.
        if padSticksEnabled {
            if input.buttons.contains(.lPadActive) {
                (leftX, leftY) = padAsStick(x: input.leftPadX, y: input.leftPadY)
            }
            if input.buttons.contains(.rPadActive) {
                (rightX, rightY) = padAsStick(x: input.rightPadX, y: input.rightPadY)
            }
        }

        // Gyro aiming blends into the right stick while L2 is held.
        let (gyroX, gyroY) = gyroDelta(input)
        rightX += gyroX
        rightY += gyroY

        report.leftStickX = Int16(clamping: leftX)
        report.leftStickY = flipY(Int16(clamping: leftY))
        report.rightStickX = Int16(clamping: rightX)
        report.rightStickY = flipY(Int16(clamping: rightY))
        return report
    }

    /// Treats the absolute touch position as stick deflection.
    private func padAsStick(x: Int16, y: Int16) -> (Int, Int) {
        func scale(_ value: Int16) -> Int {
            guard abs(Int(value)) >= padDeadZone else { return 0 }
            return Int(value) * padSensitivity / 100
        }
        return (scale(x), scale(y))
    }

    /// Gyro yaw/pitch → right stick deflection while the left trigger is
    /// held. Bias learns fast at activation and drifts slowly while idle,
    /// so resting orientation never accumulates into aim.
    private func gyroDelta(_ input: InputState) -> (Int, Int) {
        guard gyroEnabled else { return (0, 0) }
        let rawYaw = Double(input.gyroZ)
        let rawPitch = Double(input.gyroX)
        let active = input.leftTrigger >= gyroActivationThreshold

        if !active {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * gyroBiasSlowWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * gyroBiasSlowWeight
        } else if !gyroWasActive {
            gyroBiasYaw += (rawYaw - gyroBiasYaw) * gyroBiasFastWeight
            gyroBiasPitch += (rawPitch - gyroBiasPitch) * gyroBiasFastWeight
        }
        gyroWasActive = active
        guard active else { return (0, 0) }

        func deflection(_ value: Double) -> Int {
            guard abs(value) >= Double(gyroDeadZone) else { return 0 }
            return Int(value * Double(gyroSensitivity))
        }
        return (deflection(-(rawYaw - gyroBiasYaw)),
                deflection(-(rawPitch - gyroBiasPitch)))
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
