import Flutter
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// iOS implementation of the `device_integrity_check` plugin.
///
/// The channel name below must match `MethodChannelDeviceIntegrity.channelName`
/// in Dart and `CHANNEL_NAME` in `DeviceIntegrityPlugin.kt`. The previous
/// version of this plugin registered its channel as `safe_device` while Dart
/// called `device_check`, so every iOS invocation raised
/// `MissingPluginException` — silently, because the plugin class itself
/// registered without error. The integration test in
/// `example/integration_test` exists to catch exactly that.
public class DeviceIntegrityPlugin: NSObject, FlutterPlugin {

    private static let channelName = "device_integrity_check"

    /// Jailbreak probing touches the filesystem, so it runs off the main
    /// thread; results are delivered back on the main queue, where
    /// `FlutterResult` must be called.
    private let probeQueue = DispatchQueue(
        label: "io.github.wiseminds.device_integrity_check.probe",
        qos: .userInitiated
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = DeviceIntegrityPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "isRooted":
            offload(result) { JailbreakDetector.isJailbroken() }

        case "isEmulator":
            result(Self.isSimulator)

        case "isDeveloperModeEnabled":
            // Not a concept on iOS. Answering `nil` rather than `false` puts
            // this signal in IntegrityReport.unavailable, so callers can tell
            // "not enabled" from "cannot be known here".
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Whether the app is running in the simulator.
    ///
    /// Resolved at compile time — there is no runtime check to make, since a
    /// binary built for the simulator cannot run on a device or vice versa.
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func offload(
        _ result: @escaping FlutterResult,
        _ probe: @escaping () -> Bool
    ) {
        probeQueue.async {
            let value = probe()
            DispatchQueue.main.async { result(value) }
        }
    }
}
