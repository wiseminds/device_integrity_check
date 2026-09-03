/// A single device-integrity property this plugin can probe.
///
/// Each signal is reported independently. Whether a given signal should block
/// a user, raise a risk score, or simply be logged is a policy decision that
/// belongs to the calling application, so this package deliberately does not
/// collapse them into one "is the device safe" boolean.
enum IntegritySignal {
  /// The device shows evidence of root (Android) or jailbreak (iOS).
  rooted,

  /// The app is running on an emulator or simulator rather than real hardware.
  emulator,

  /// Developer options are enabled in system settings.
  ///
  /// Android only. On other platforms this signal is always reported as
  /// unavailable rather than as `false`.
  developerMode;

  /// The method-channel name used to probe this signal.
  ///
  /// Kept next to the enum so the Dart and native sides cannot drift apart the
  /// way they did before: there is exactly one spelling of each method name in
  /// this package, and it lives here.
  String get methodName => switch (this) {
        IntegritySignal.rooted => 'isRooted',
        IntegritySignal.emulator => 'isEmulator',
        IntegritySignal.developerMode => 'isDeveloperModeEnabled',
      };
}
