import Foundation
import IOKit.hid
import os.log

/// Owns the IOHIDManager session for the physical Steam Controller:
/// discovery, seize-open, lizard-mode-off init + heartbeat, input reports,
/// hot-plug, and rumble/restore writes.
///
/// Scheduled on the main run loop (the model the HIDExplorer prototype
/// verified on hardware). Dispatch-queue scheduling is deliberately avoided:
/// IOHIDManagerActivate activates matched devices itself, after which
/// IOHIDDeviceRegisterInputReportCallback asserts. All calls and callbacks
/// are on the main thread; per-report work is microseconds.
@MainActor
final class SteamControllerDevice {
    enum ConnectionState: Equatable {
        case stopped
        case searching
        case connected(name: String)
        case permissionDenied
    }

    /// Called on the main thread for every parsed state report.
    var onInput: ((InputState) -> Void)?
    /// Called on the main thread when connection state changes.
    var onStateChange: ((ConnectionState) -> Void)?
    /// When set, raw reports are dumped (hex) to a file for offset
    /// verification: ~/Library/Application Support/SteamControllerBridgeMac/rawreports.log
    /// (the unified log proved unreliable for retrieving these after the fact).
    var logRawReports = false {
        didSet {
            guard logRawReports != oldValue else { return }
            logRawReports ? openDumpFile() : closeDumpFile()
        }
    }

    private let log = Logger(subsystem: "com.arvindrao.SteamControllerBridgeMac", category: "controller")
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    // Stable storage for IOKit to write incoming reports into; must outlive
    // the input-report callback registration.
    private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
    private var heartbeat: DispatchSourceTimer?
    private var rawLogCounter = 0
    private var dumpFile: FileHandle?

    static let dumpFileURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SteamControllerBridgeMac/rawreports.log")

    deinit {
        reportBuffer.deallocate()
    }

    func start() {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching = SteamControllerProtocol.productIDs.map {
            [kIOHIDVendorIDKey: SteamControllerProtocol.vendorID,
             kIOHIDProductIDKey: $0] as CFDictionary
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let me = Unmanaged<SteamControllerDevice>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { me.deviceMatched(device) }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let me = Unmanaged<SteamControllerDevice>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { me.deviceRemoved(device) }
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Seize so the controller's built-in lizard-mode keyboard/mouse
        // collections don't keep driving the OS cursor alongside us.
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        self.manager = manager

        if result == kIOReturnNotPermitted {
            log.error("IOHIDManagerOpen denied: Input Monitoring permission missing")
            onStateChange?(.permissionDenied)
        } else {
            onStateChange?(.searching)
        }
    }

    /// Stops bridging and restores the controller's default mappings.
    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        if device != nil {
            write(SteamControllerProtocol.restoreDefaultMappings,
                  type: kIOHIDReportTypeFeature,
                  reportID: SteamControllerProtocol.featureReportID)
            device = nil
        }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            self.manager = nil
        }
        onStateChange?(.stopped)
    }

    /// Single-attempt, fire-and-forget: tick haptics are frequent and a
    /// dropped one is imperceptible, so retries would only add latency.
    func sendHapticClick(rightPad: Bool, gainDB: Int8) {
        guard let device else { return }
        let report = SteamControllerProtocol.hapticClick(
            side: rightPad ? SteamControllerProtocol.hapticSideRight
                           : SteamControllerProtocol.hapticSideLeft,
            gainDB: gainDB)
        _ = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x82, $0.baseAddress!, $0.count)
        }
    }

    func sendRumble(intensity: UInt16, leftSpeed: UInt16, leftGain: Int8,
                    rightSpeed: UInt16, rightGain: Int8) {
        let report = SteamControllerProtocol.rumbleReport(
            intensity: intensity, leftSpeed: leftSpeed, leftGain: leftGain,
            rightSpeed: rightSpeed, rightGain: rightGain)
        write(report, type: kIOHIDReportTypeOutput, reportID: 0x80)
    }

    // MARK: - Device lifecycle

    private func deviceMatched(_ device: IOHIDDevice) {
        guard self.device == nil else { return }
        self.device = device

        let name = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String)
            ?? "Steam Controller"
        log.notice("Controller matched: \(name, privacy: .public)")

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device, reportBuffer, 256,
            { context, _, _, _, reportID, report, reportLength in
                guard let context else { return }
                let me = Unmanaged<SteamControllerDevice>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated {
                    me.handleReport(reportID: reportID, bytes: report, length: reportLength)
                }
            }, context)

        sendInitSequence()
        startHeartbeat()
        onStateChange?(.connected(name: name))
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        guard self.device === device else { return }
        log.info("Controller removed")
        heartbeat?.cancel()
        heartbeat = nil
        self.device = nil
        onStateChange?(.searching)
    }

    private func handleReport(reportID: UInt32, bytes: UnsafePointer<UInt8>, length: Int) {
        if logRawReports, let dumpFile {
            // Dump every 8th report to keep the file readable at ~250Hz.
            rawLogCounter += 1
            if rawLogCounter % 8 == 1 {
                let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
                let line = stamp + " " + InputState.hexDump(reportID: reportID, bytes: bytes, length: length) + "\n"
                dumpFile.write(Data(line.utf8))
            }
        }
        guard let state = InputState.parse(reportID: reportID, bytes: bytes, length: length) else { return }
        onInput?(state)
    }

    private func openDumpFile() {
        let url = Self.dumpFileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil) // truncate per session
        dumpFile = try? FileHandle(forWritingTo: url)
        rawLogCounter = 0
    }

    private func closeDumpFile() {
        try? dumpFile?.close()
        dumpFile = nil
    }

    private func sendInitSequence() {
        write(SteamControllerProtocol.clearDigitalMappings,
              type: kIOHIDReportTypeFeature,
              reportID: SteamControllerProtocol.featureReportID)
        write(SteamControllerProtocol.clearMappingsCompanion,
              type: kIOHIDReportTypeFeature,
              reportID: SteamControllerProtocol.featureReportID)
        // Trackpad modes + raw IMU output, needed for gyro aiming.
        write(SteamControllerProtocol.applySettings,
              type: kIOHIDReportTypeFeature,
              reportID: SteamControllerProtocol.featureReportID)
    }

    private func startHeartbeat() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + SteamControllerProtocol.heartbeatInterval,
                       repeating: SteamControllerProtocol.heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.write(SteamControllerProtocol.clearDigitalMappings,
                       type: kIOHIDReportTypeFeature,
                       reportID: SteamControllerProtocol.featureReportID)
        }
        timer.resume()
        heartbeat = timer
    }

    /// Writes a report with crosspuck's retry strategy: BLE writes in
    /// particular can fail transiently (0xE0005000 / 0xE00002ED).
    @discardableResult
    private func write(_ report: [UInt8], type: IOHIDReportType, reportID: CFIndex) -> Bool {
        guard let device else { return false }
        var result = kIOReturnError
        for attempt in 1...SteamControllerProtocol.featureWriteAttempts {
            result = report.withUnsafeBufferPointer {
                IOHIDDeviceSetReport(device, type, reportID, $0.baseAddress!, $0.count)
            }
            if result == kIOReturnSuccess { return true }
            if attempt < SteamControllerProtocol.featureWriteAttempts {
                usleep(SteamControllerProtocol.featureWriteRetryDelayMicroseconds)
            }
        }
        log.warning("Report write failed (type \(type.rawValue), id \(reportID)): 0x\(String(result, radix: 16), privacy: .public)")
        return false
    }
}
