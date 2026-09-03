import 'package:flutter/foundation.dart';

import 'device_integrity_platform.dart';
import 'models/integrity_report.dart';
import 'models/integrity_signal.dart';

/// Called when a probe fails.
///
/// [signal] is `null` when the failure came from reading the platform version
/// rather than from an integrity signal.
typedef IntegrityErrorCallback = void Function(
  IntegritySignal? signal,
  Object error,
  StackTrace stackTrace,
);

/// Probes device integrity: root/jailbreak, emulator, and developer mode.
///
/// ```dart
/// final integrity = DeviceIntegrity();
/// final report = await integrity.evaluate();
///
/// if (report.isRooted) raiseRiskScore();
/// if (!report.isComplete) log('unprobed: ${report.unavailable}');
/// ```
///
/// ## What these results are worth
///
/// Every check here is a local heuristic — a file-existence test, a system
/// property read, a package scan — executed inside a process that an attacker
/// on a rooted device fully controls. Magisk's DenyList hides the artefacts
/// this looks for; Frida can hook these methods and return whatever it likes;
/// patching the compiled bundle needs no runtime tooling at all.
///
/// Use these signals to raise a risk score or nudge a user. Do **not** use them
/// as an authorization decision. Anything that must actually hold needs
/// server-verified attestation — the Play Integrity API on Android, App Attest
/// or DeviceCheck on iOS — with the verdict checked on your own backend. This
/// package uses none of those and cannot substitute for them.
///
/// ## Failure behaviour
///
/// Probes that fail resolve to `false` rather than throwing, so a platform bug
/// cannot crash a caller. That choice hides failures by design, which is why
/// every failure is also reported to [onError] and recorded in
/// [IntegrityReport.unavailable]. Pass an [onError] handler in production, and
/// check [IntegrityReport.isComplete] before trusting a clean result.
class DeviceIntegrity {
  /// Creates a probe.
  ///
  /// Pass [platform] to supply a fake in tests. Pass [onError] to observe
  /// probe failures, which are otherwise silent.
  DeviceIntegrity({
    DeviceIntegrityPlatform? platform,
    IntegrityErrorCallback? onError,
  })  : _platform = platform ?? DeviceIntegrityPlatform.instance,
        _onError = onError;

  final DeviceIntegrityPlatform _platform;
  final IntegrityErrorCallback? _onError;

  /// Probes every signal and returns them together.
  ///
  /// Probes run concurrently, so this costs roughly as much as the slowest
  /// single check rather than the sum of all of them.
  Future<IntegrityReport> evaluate() async {
    final detected = <IntegritySignal>{};
    final unavailable = <IntegritySignal>{};

    final results = await Future.wait([
      _probe(IntegritySignal.rooted, _platform.isRooted),
      _probe(IntegritySignal.emulator, _platform.isEmulator),
      _probe(IntegritySignal.developerMode, _platform.isDeveloperModeEnabled),
    ]);

    for (final (signal, value) in results) {
      switch (value) {
        case null:
          unavailable.add(signal);
        case true:
          detected.add(signal);
        case false:
          break;
      }
    }

    return IntegrityReport(
      detected: detected,
      unavailable: unavailable,
      platformVersion: await platformVersion(),
    );
  }

  /// Whether the device shows evidence of root or jailbreak.
  ///
  /// Returns `false` if the check could not run. Use [evaluate] when you need
  /// to tell "not rooted" from "could not tell".
  Future<bool> isRooted() async =>
      (await _probe(IntegritySignal.rooted, _platform.isRooted)).$2 ?? false;

  /// Whether the app is running on an emulator or simulator.
  ///
  /// Returns `false` if the check could not run.
  Future<bool> isEmulator() async =>
      (await _probe(IntegritySignal.emulator, _platform.isEmulator)).$2 ??
      false;

  /// Whether developer options are enabled.
  ///
  /// Android only. Returns `false` everywhere else, and on Android if the
  /// check could not run.
  Future<bool> isDeveloperModeEnabled() async =>
      (await _probe(
        IntegritySignal.developerMode,
        _platform.isDeveloperModeEnabled,
      ))
          .$2 ??
      false;

  /// The host OS and version, or `null` if it could not be read.
  Future<String?> platformVersion() async {
    try {
      return await _platform.platformVersion();
    } catch (error, stackTrace) {
      _report(null, error, stackTrace);
      return null;
    }
  }

  Future<(IntegritySignal, bool?)> _probe(
    IntegritySignal signal,
    Future<bool?> Function() probe,
  ) async {
    try {
      return (signal, await probe());
    } catch (error, stackTrace) {
      _report(signal, error, stackTrace);
      return (signal, null);
    }
  }

  void _report(IntegritySignal? signal, Object error, StackTrace stackTrace) {
    final handler = _onError;
    if (handler != null) {
      handler(signal, error, stackTrace);
      return;
    }
    // No handler installed. Fail-open means the caller sees `false` either
    // way, so surface it where a developer will at least notice in debug.
    assert(() {
      debugPrint(
        'device_integrity_check: ${signal?.name ?? 'platformVersion'} '
        'probe failed: $error',
      );
      return true;
    }());
  }
}
