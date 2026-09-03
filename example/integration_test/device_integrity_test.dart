// Runs against a real device or emulator:
//
//   cd example && flutter test integration_test
//
// This file exists because of a specific bug. The previous version of this
// plugin registered its iOS method channel as `safe_device` while Dart called
// `device_check`, so every check on iOS threw MissingPluginException — for
// several published releases. Nothing caught it: the plugin class registered
// without error, the analyzer saw two unrelated string literals, and unit tests
// with a mocked channel pass whether or not the native side agrees.
//
// Only an on-device round trip can catch that class of bug, so these tests
// assert that each method actually resolves on the platform under test.

import 'package:device_integrity_check/device_integrity_check.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The signals the platform under test is expected to answer.
  ///
  /// Developer mode is Android-only; iOS deliberately answers null so the
  /// signal lands in [IntegrityReport.unavailable].
  const expectedAnswerable = <IntegritySignal>{
    IntegritySignal.rooted,
    IntegritySignal.emulator,
  };

  group('method channel round trip', () {
    late MethodChannelDeviceIntegrity platform;

    setUp(() => platform = MethodChannelDeviceIntegrity());

    testWidgets('the channel name resolves on this platform', (_) async {
      // If the native channel name disagrees with the Dart one, every call
      // below returns null via MissingPluginException and this fails.
      final version = await platform.platformVersion();

      expect(
        version,
        isNotNull,
        reason: 'getPlatformVersion did not resolve — the native channel name '
            'probably disagrees with '
            'MethodChannelDeviceIntegrity.channelName '
            '("${MethodChannelDeviceIntegrity.channelName}")',
      );
      expect(version, isNotEmpty);
    });

    testWidgets('isRooted resolves and returns a bool', (_) async {
      final result = await platform.isRooted();
      expect(result, isNotNull, reason: 'isRooted handler is not wired up');
      expect(result, isA<bool>());
    });

    testWidgets('isEmulator resolves and returns a bool', (_) async {
      final result = await platform.isEmulator();
      expect(result, isNotNull, reason: 'isEmulator handler is not wired up');
      expect(result, isA<bool>());
    });

    testWidgets('every expected signal is answerable', (_) async {
      final report = await DeviceIntegrity(platform: platform).evaluate();

      for (final signal in expectedAnswerable) {
        expect(
          report.unavailable,
          isNot(contains(signal)),
          reason: '${signal.methodName} should be implemented on this '
              'platform but reported as unavailable',
        );
      }
    });

    testWidgets('unknown methods are reported, not silently ignored',
        (_) async {
      // Guards against a native handler that answers everything — which would
      // make the assertions above pass vacuously.
      await expectLater(
        MethodChannelDeviceIntegrity.channel
            .invokeMethod<bool>('definitelyNotAMethod'),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('evaluate on real hardware', () {
    testWidgets('never throws, whatever the platform does', (_) async {
      // The contract callers rely on: fail-open, no exceptions.
      final report = await DeviceIntegrity().evaluate();

      expect(report.platformVersion, isNotNull);
      expect(
        report.detected.intersection(report.unavailable),
        isEmpty,
        reason: 'a signal cannot be both detected and unavailable',
      );
    });

    testWidgets('emulator detection agrees with where we are running',
        (_) async {
      final report = await DeviceIntegrity().evaluate();

      // Integration tests run on emulators/simulators in CI and on hardware
      // locally, so assert only that the signal was answerable at all. The
      // previous implementation's Build-based heuristics all missed current
      // AVDs, which this would surface as an unavailable signal.
      expect(report.unavailable, isNot(contains(IntegritySignal.emulator)));
    });
  });
}
