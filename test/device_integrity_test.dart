import 'package:device_integrity_check/device_integrity_check.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A platform implementation whose every answer is scripted.
///
/// The point of the platform-interface rewrite: none of these tests could be
/// written against the previous static-only API with a private `const` channel.
class _FakePlatform extends DeviceIntegrityPlatform {
  _FakePlatform({
    this.rooted,
    this.emulator,
    this.developerMode,
    this.version,
    this.throwOn = const {},
  }) : super();

  final bool? rooted;
  final bool? emulator;
  final bool? developerMode;
  final String? version;

  /// Method names that should throw instead of answering.
  final Set<String> throwOn;

  @override
  Future<bool?> isRooted() async => _answer('isRooted', rooted);

  @override
  Future<bool?> isEmulator() async => _answer('isEmulator', emulator);

  @override
  Future<bool?> isDeveloperModeEnabled() async =>
      _answer('isDeveloperModeEnabled', developerMode);

  @override
  Future<String?> platformVersion() async =>
      _answer('getPlatformVersion', version);

  T? _answer<T>(String method, T? value) {
    if (throwOn.contains(method)) {
      throw PlatformException(code: 'probe_failed', message: method);
    }
    return value;
  }
}

/// A platform implementation that does not extend the interface correctly.
class _Unverified implements DeviceIntegrityPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // Required by the MethodChannelDeviceIntegrity group, which installs a
  // mock handler on the real channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntegrityReport', () {
    test('separates fired, clear and unprobed signals', () {
      final report = IntegrityReport(
        detected: {IntegritySignal.rooted},
        unavailable: {IntegritySignal.developerMode},
        platformVersion: 'iOS 26',
      );

      expect(report.isRooted, isTrue);
      expect(report.isEmulator, isFalse, reason: 'probed and did not fire');
      expect(
        report.isDeveloperModeEnabled,
        isFalse,
        reason: 'unavailable reads as false, but is listed in unavailable',
      );
      expect(report.unavailable, contains(IntegritySignal.developerMode));
      expect(report.isComplete, isFalse);
      expect(report.hasAnySignal, isTrue);
    });

    test('isComplete is true only when nothing is unavailable', () {
      expect(
        IntegrityReport(detected: const {}, unavailable: const {}).isComplete,
        isTrue,
      );
      expect(IntegrityReport.unavailable().isComplete, isFalse);
      expect(
        IntegrityReport.unavailable().unavailable,
        hasLength(IntegritySignal.values.length),
      );
    });

    test('exposed sets cannot be mutated by callers', () {
      final report = IntegrityReport(
        detected: {IntegritySignal.rooted},
        unavailable: const {},
      );
      expect(
        () => report.detected.add(IntegritySignal.emulator),
        throwsUnsupportedError,
      );
    });

    test('value equality ignores set ordering', () {
      final a = IntegrityReport(
        detected: {IntegritySignal.rooted, IntegritySignal.emulator},
        unavailable: const {},
      );
      final b = IntegrityReport(
        detected: {IntegritySignal.emulator, IntegritySignal.rooted},
        unavailable: const {},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('DeviceIntegrity.evaluate', () {
    test('reports signals that fired', () async {
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(
          rooted: true,
          emulator: false,
          developerMode: true,
          version: 'Android 17',
        ),
      );

      final report = await integrity.evaluate();

      expect(report.detected, {
        IntegritySignal.rooted,
        IntegritySignal.developerMode,
      });
      expect(report.unavailable, isEmpty);
      expect(report.isComplete, isTrue);
      expect(report.platformVersion, 'Android 17');
    });

    test('a null answer means unavailable, not clean', () async {
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(rooted: false, emulator: false),
      );

      final report = await integrity.evaluate();

      // developerMode was not scripted, so the fake answers null.
      expect(report.unavailable, {IntegritySignal.developerMode});
      expect(report.isDeveloperModeEnabled, isFalse);
      expect(
        report.isComplete,
        isFalse,
        reason: 'the caller must be able to see the check did not run',
      );
    });

    test('a throwing probe is unavailable and does not fail the report',
        () async {
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(
          rooted: true,
          emulator: false,
          developerMode: false,
          throwOn: const {'isRooted'},
        ),
      );

      final report = await integrity.evaluate();

      expect(report.isRooted, isFalse, reason: 'fail-open');
      expect(report.unavailable, contains(IntegritySignal.rooted));
      expect(report.detected, isEmpty);
    });

    test('a throwing platformVersion leaves the field null', () async {
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(
          rooted: false,
          emulator: false,
          developerMode: false,
          throwOn: const {'getPlatformVersion'},
        ),
      );

      final report = await integrity.evaluate();

      expect(report.platformVersion, isNull);
      expect(
        report.isComplete,
        isTrue,
        reason: 'platformVersion is not an integrity signal',
      );
    });
  });

  group('DeviceIntegrity error reporting', () {
    test('every failure reaches onError with its signal', () async {
      final seen = <IntegritySignal?>[];
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(
          throwOn: const {'isRooted', 'isEmulator', 'getPlatformVersion'},
        ),
        onError: (signal, _, __) => seen.add(signal),
      );

      await integrity.evaluate();

      expect(
        seen,
        containsAll(<IntegritySignal?>[
          IntegritySignal.rooted,
          IntegritySignal.emulator,
          null, // platformVersion
        ]),
      );
    });

    test('onError receives the original error and a stack trace', () async {
      Object? captured;
      StackTrace? trace;
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(throwOn: const {'isRooted'}),
        onError: (_, error, stackTrace) {
          captured = error;
          trace = stackTrace;
        },
      );

      await integrity.isRooted();

      expect(captured, isA<PlatformException>());
      expect((captured! as PlatformException).message, 'isRooted');
      expect(trace, isNotNull);
    });
  });

  group('DeviceIntegrity single-signal getters', () {
    test('return false rather than throwing when a probe fails', () async {
      final integrity = DeviceIntegrity(
        platform: _FakePlatform(
          throwOn: const {
            'isRooted',
            'isEmulator',
            'isDeveloperModeEnabled',
          },
        ),
        onError: (_, __, ___) {},
      );

      expect(await integrity.isRooted(), isFalse);
      expect(await integrity.isEmulator(), isFalse);
      expect(await integrity.isDeveloperModeEnabled(), isFalse);
    });

    test('return false when the platform answers null', () async {
      final integrity = DeviceIntegrity(platform: _FakePlatform());

      expect(await integrity.isRooted(), isFalse);
      expect(await integrity.isEmulator(), isFalse);
      expect(await integrity.isDeveloperModeEnabled(), isFalse);
      expect(await integrity.platformVersion(), isNull);
    });
  });

  group('IntegritySignal', () {
    test('method names match the native handlers exactly', () {
      // These strings are the contract with DeviceIntegrityPlugin.kt and
      // DeviceIntegrityPlugin.swift. Changing one without the others is the
      // bug class that made the previous iOS build non-functional.
      expect(IntegritySignal.rooted.methodName, 'isRooted');
      expect(IntegritySignal.emulator.methodName, 'isEmulator');
      expect(
        IntegritySignal.developerMode.methodName,
        'isDeveloperModeEnabled',
      );
    });

    test('every signal has a distinct method name', () {
      final names = IntegritySignal.values.map((s) => s.methodName).toSet();
      expect(names, hasLength(IntegritySignal.values.length));
    });
  });

  group('DeviceIntegrityPlatform', () {
    test('defaults to the method channel implementation', () {
      expect(
        DeviceIntegrityPlatform.instance,
        isA<MethodChannelDeviceIntegrity>(),
      );
    });

    test('rejects an implementation that bypasses the interface', () {
      expect(
        () => DeviceIntegrityPlatform.instance = _Unverified(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('MethodChannelDeviceIntegrity', () {
    late MethodChannelDeviceIntegrity platform;
    final log = <MethodCall>[];

    setUp(() {
      platform = MethodChannelDeviceIntegrity();
      log.clear();
    });

    void handleWith(Future<Object?>? Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelDeviceIntegrity.channel,
              (call) {
        log.add(call);
        return handler(call);
      });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelDeviceIntegrity.channel, null);
    });

    test('invokes the agreed method names on the agreed channel', () async {
      handleWith((_) async => true);

      await platform.isRooted();
      await platform.isEmulator();
      await platform.isDeveloperModeEnabled();

      expect(
        log.map((c) => c.method),
        ['isRooted', 'isEmulator', 'isDeveloperModeEnabled'],
      );
      expect(
        MethodChannelDeviceIntegrity.channelName,
        'device_integrity_check',
      );
    });

    test('maps a missing implementation to null, not false', () async {
      handleWith((_) => throw MissingPluginException('no impl'));

      expect(await platform.isRooted(), isNull);
      expect(await platform.platformVersion(), isNull);
    });

    test('lets real platform errors propagate to the facade', () async {
      handleWith((_) => throw PlatformException(code: 'probe_failed'));

      await expectLater(platform.isRooted(), throwsA(isA<PlatformException>()));
    });

    test('unsupported platforms produce an all-unavailable report', () async {
      handleWith((_) => throw MissingPluginException('no impl'));

      final report = await DeviceIntegrity(platform: platform).evaluate();

      expect(report, equals(IntegrityReport.unavailable()));
      expect(report.isComplete, isFalse);
      expect(report.hasAnySignal, isFalse);
    });
  });
}
