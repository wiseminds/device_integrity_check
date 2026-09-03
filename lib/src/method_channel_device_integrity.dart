import 'package:flutter/services.dart';

import 'device_integrity_platform.dart';
import 'models/integrity_signal.dart';

/// The default [DeviceIntegrityPlatform], backed by a [MethodChannel].
///
/// There is exactly one channel name and one spelling of each method in this
/// package. The Dart side derives every method name from
/// [IntegritySignal.methodName] rather than repeating string literals, because
/// the previous version of this plugin shipped for years with Dart calling
/// `getPlatformVersion` while Android answered `platformVersion`, and with iOS
/// listening on a channel no caller used.
class MethodChannelDeviceIntegrity extends DeviceIntegrityPlatform {
  /// The channel shared with the Android and iOS implementations.
  ///
  /// Any change here must be made in `DeviceIntegrityPlugin.kt` and
  /// `DeviceIntegrityPlugin.swift` at the same time. The integration test in
  /// `example/integration_test` fails if they disagree.
  static const String channelName = 'device_integrity_check';

  /// The channel used to talk to the platform.
  static const MethodChannel channel = MethodChannel(channelName);

  @override
  Future<bool?> isRooted() => _probe(IntegritySignal.rooted);

  @override
  Future<bool?> isEmulator() => _probe(IntegritySignal.emulator);

  @override
  Future<bool?> isDeveloperModeEnabled() =>
      _probe(IntegritySignal.developerMode);

  @override
  Future<String?> platformVersion() => _invoke<String>('getPlatformVersion');

  Future<bool?> _probe(IntegritySignal signal) =>
      _invoke<bool>(signal.methodName);

  /// Invokes [method], mapping "this platform has no implementation" to `null`.
  ///
  /// A [MissingPluginException] means the plugin is not registered for the
  /// current platform at all — web and desktop, for instance. That is a
  /// legitimate "unknown", so it becomes `null`. Every other failure is left to
  /// propagate: [DeviceIntegrity] logs it before deciding what it means, and
  /// swallowing it here would hide real platform bugs.
  Future<T?> _invoke<T>(String method) async {
    try {
      return await channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    }
  }
}
