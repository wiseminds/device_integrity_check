/// Root, jailbreak, emulator and developer-mode detection for Flutter.
///
/// Start with [DeviceIntegrity]:
///
/// ```dart
/// final report = await DeviceIntegrity().evaluate();
/// if (report.isRooted) raiseRiskScore();
/// ```
///
/// Read the class documentation on [DeviceIntegrity] before relying on any of
/// these signals — they are unattested client-side heuristics, not an
/// authorization mechanism.
library;

export 'src/device_integrity.dart' show DeviceIntegrity, IntegrityErrorCallback;
export 'src/device_integrity_platform.dart' show DeviceIntegrityPlatform;
export 'src/method_channel_device_integrity.dart'
    show MethodChannelDeviceIntegrity;
export 'src/models/integrity_report.dart' show IntegrityReport;
export 'src/models/integrity_signal.dart' show IntegritySignal;
