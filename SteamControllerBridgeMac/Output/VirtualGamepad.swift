import Foundation
import CoreHID
import os.log

/// Publishes the virtual gamepad to the system via CoreHID's HIDVirtualDevice.
///
/// `send(_:)` is callable from any thread/queue; reports are forwarded in
/// order through an AsyncStream to the device actor.
final class VirtualGamepad {
    enum CreationError: LocalizedError {
        case entitlementMissing

        var errorDescription: String? {
            "Could not create the virtual gamepad. The app is missing the "
                + "com.apple.developer.hid.virtual.device entitlement — see the "
                + "README for the Apple Developer portal setup."
        }
    }

    private let log = Logger(subsystem: "com.arvindrao.SteamControllerBridgeMac", category: "virtualpad")
    private var device: HIDVirtualDevice?
    private var continuation: AsyncStream<Data>.Continuation?
    private var pump: Task<Void, Never>?

    var isActive: Bool { device != nil }

    func create() async throws {
        guard device == nil else { return }
        let properties = HIDVirtualDevice.Properties(
            descriptor: Data(GamepadDescriptor.descriptor),
            vendorID: UInt32(GamepadDescriptor.vendorID),
            productID: UInt32(GamepadDescriptor.productID),
            product: GamepadDescriptor.productName,
            manufacturer: "SteamControllerBridgeMac")
        guard let device = HIDVirtualDevice(properties: properties) else {
            throw CreationError.entitlementMissing
        }
        await device.activate(delegate: GamepadEventDelegate(log: log))
        self.device = device

        let (stream, continuation) = AsyncStream<Data>.makeStream()
        self.continuation = continuation
        pump = Task {
            for await data in stream {
                do {
                    try await device.dispatchInputReport(data: data, timestamp: SuspendingClock().now)
                } catch {
                    self.log.warning("dispatchInputReport failed: \(error, privacy: .public)")
                }
            }
        }

        send(GamepadReport()) // neutral initial state
        log.info("Virtual gamepad published")
    }

    func send(_ report: GamepadReport) {
        continuation?.yield(Data(report.packed()))
    }

    func destroy() {
        continuation?.finish()
        continuation = nil
        pump = nil
        device = nil // HIDVirtualDevice tears down on release
        log.info("Virtual gamepad removed")
    }
}

/// Handles get/set report requests from the host side of the virtual device.
private final class GamepadEventDelegate: HIDVirtualDeviceDelegate, Sendable {
    private let log: Logger

    init(log: Logger) {
        self.log = log
    }

    func hidVirtualDevice(_ device: HIDVirtualDevice,
                          receivedSetReportRequestOfType type: HIDReportType,
                          id: HIDReportID?,
                          data: Data) async throws {
        // Future rumble channel: output report ID 2 will be forwarded to the
        // physical controller's haptics.
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        log.info("setReport type=\(String(describing: type), privacy: .public) id=\(String(describing: id), privacy: .public) data=\(hex, privacy: .public)")
    }

    func hidVirtualDevice(_ device: HIDVirtualDevice,
                          receivedGetReportRequestOfType type: HIDReportType,
                          id: HIDReportID?,
                          maxSize: Int) async throws -> Data {
        // Some hosts poll the current input state; reply with neutral.
        Data(GamepadReport().packed())
    }
}
