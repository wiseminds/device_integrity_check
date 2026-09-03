import 'package:flutter/foundation.dart';

import 'integrity_signal.dart';

/// The result of evaluating every [IntegritySignal] the current platform
/// supports.
///
/// A report separates three outcomes that the previous version of this package
/// conflated into a single `false`:
///
/// * the signal was probed and **fired** — it appears in [detected];
/// * the signal was probed and did **not** fire — it appears in neither set;
/// * the signal **could not be probed** — it appears in [unavailable].
///
/// The third case matters. A check that could not run tells you nothing about
/// the device, and treating it as a clean result is how an unnoticed platform
/// bug turns into a silent hole in your defences. Read [unavailable] (or
/// [isComplete]) before acting on the booleans.
@immutable
class IntegrityReport {
  /// Creates a report from the signals that fired and the ones that could not
  /// be probed.
  IntegrityReport({
    required Set<IntegritySignal> detected,
    required Set<IntegritySignal> unavailable,
    this.platformVersion,
  })  : detected = Set.unmodifiable(detected),
        unavailable = Set.unmodifiable(unavailable);

  /// A report in which nothing fired and nothing could be probed.
  ///
  /// Returned on platforms with no implementation at all, such as web and
  /// desktop.
  factory IntegrityReport.unavailable() => IntegrityReport(
        detected: const {},
        unavailable: IntegritySignal.values.toSet(),
      );

  /// Signals that were probed successfully and fired.
  final Set<IntegritySignal> detected;

  /// Signals that could not be probed on this device.
  ///
  /// A signal lands here when the platform has no implementation for it (for
  /// example [IntegritySignal.developerMode] on iOS), or when the probe failed.
  final Set<IntegritySignal> unavailable;

  /// The host OS and version, or `null` if it could not be read.
  final String? platformVersion;

  /// Whether the device shows evidence of root or jailbreak.
  bool get isRooted => detected.contains(IntegritySignal.rooted);

  /// Whether the app is running on an emulator or simulator.
  bool get isEmulator => detected.contains(IntegritySignal.emulator);

  /// Whether developer options are enabled. Android only.
  bool get isDeveloperModeEnabled =>
      detected.contains(IntegritySignal.developerMode);

  /// Whether any signal at all fired.
  ///
  /// Note this includes [IntegritySignal.developerMode], which many apps
  /// tolerate. Prefer reading [detected] and applying your own policy.
  bool get hasAnySignal => detected.isNotEmpty;

  /// Whether every signal was probed successfully.
  ///
  /// When this is `false` the booleans above are answers to a question that was
  /// only partly asked.
  bool get isComplete => unavailable.isEmpty;

  @override
  String toString() {
    final fired = detected.isEmpty
        ? 'none'
        : detected.map((s) => s.name).toList().join(', ');
    final missing = unavailable.isEmpty
        ? 'none'
        : unavailable.map((s) => s.name).toList().join(', ');
    return 'IntegrityReport(detected: $fired, unavailable: $missing, '
        'platformVersion: $platformVersion)';
  }

  @override
  bool operator ==(Object other) =>
      other is IntegrityReport &&
      setEquals(other.detected, detected) &&
      setEquals(other.unavailable, unavailable) &&
      other.platformVersion == platformVersion;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(detected),
        Object.hashAllUnordered(unavailable),
        platformVersion,
      );
}
