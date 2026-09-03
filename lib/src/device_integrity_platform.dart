import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_device_integrity.dart';

/// The interface every platform implementation of this plugin must satisfy.
///
/// Probe methods return `bool?`, where `null` means **could not be determined**
/// — the platform has no implementation for that signal, or the probe failed.
/// Implementations must never substitute `false` for `null`: deciding what an
/// unanswerable check means is the caller's job, and collapsing the two here
/// would take that choice away.
abstract class DeviceIntegrityPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  DeviceIntegrityPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceIntegrityPlatform _instance = MethodChannelDeviceIntegrity();

  /// The registered platform implementation.
  ///
  /// Defaults to [MethodChannelDeviceIntegrity], which talks to the bundled
  /// Android and iOS code.
  static DeviceIntegrityPlatform get instance => _instance;

  /// Registers a platform implementation, replacing the default.
  ///
  /// Tests use this to install a fake. Platform packages use it to register
  /// their own implementation.
  static set instance(DeviceIntegrityPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Whether the device shows evidence of root or jailbreak.
  Future<bool?> isRooted();

  /// Whether the app is running on an emulator or simulator.
  Future<bool?> isEmulator();

  /// Whether developer options are enabled. Android only; `null` elsewhere.
  Future<bool?> isDeveloperModeEnabled();

  /// The host OS and version, or `null` if it could not be read.
  Future<String?> platformVersion();
}
