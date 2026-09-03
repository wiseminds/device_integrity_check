// Widget-level tests for the example app.
//
// The plugin's own logic is tested in ../../test/device_integrity_test.dart.
// These tests cover what the example is for: rendering a report, and telling
// "not detected" apart from "could not be checked".

import 'package:device_integrity_check/device_integrity_check.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform extends DeviceIntegrityPlatform {
  _FakePlatform({this.rooted, this.emulator, this.developerMode});

  // Mutable so a test can change the answers and re-probe, which is what the
  // refresh button does. Swapping DeviceIntegrityPlatform.instance mid-test
  // would not exercise that path.
  bool? rooted;
  bool? emulator;
  bool? developerMode;

  @override
  Future<bool?> isRooted() async => rooted;

  @override
  Future<bool?> isEmulator() async => emulator;

  @override
  Future<bool?> isDeveloperModeEnabled() async => developerMode;

  @override
  Future<String?> platformVersion() async => 'Test OS 1.0';
}

void main() {
  tearDown(() {
    DeviceIntegrityPlatform.instance = MethodChannelDeviceIntegrity();
  });

  testWidgets('renders one tile per signal once probing completes',
      (tester) async {
    DeviceIntegrityPlatform.instance = _FakePlatform(
      rooted: false,
      emulator: true,
      developerMode: false,
    );

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Test OS 1.0'), findsOneWidget);
    expect(find.text('All checks ran.'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(IntegritySignal.values.length));
    expect(find.text('detected'), findsOneWidget);
    expect(find.text('not detected'), findsNWidgets(2));
  });

  testWidgets('shows a spinner while probes are in flight', (tester) async {
    DeviceIntegrityPlatform.instance = _FakePlatform(rooted: false);

    await tester.pumpWidget(const ExampleApp());
    // Not settled yet: the futures have not completed.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('distinguishes an unavailable signal from a clean one',
      (tester) async {
    // developerMode answers null, as iOS does.
    DeviceIntegrityPlatform.instance =
        _FakePlatform(rooted: false, emulator: false);

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('could not be checked'), findsOneWidget);
    expect(find.textContaining('Some checks could not run'), findsOneWidget);
  });

  testWidgets('refresh re-runs the probes', (tester) async {
    final platform = _FakePlatform(
      rooted: true,
      emulator: false,
      developerMode: false,
    );
    DeviceIntegrityPlatform.instance = platform;

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('detected'), findsOneWidget);

    // The device stops looking rooted; a refresh must pick that up.
    platform.rooted = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('detected'), findsNothing);
    expect(find.text('not detected'), findsNWidgets(3));
  });
}
