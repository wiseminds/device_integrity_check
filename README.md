# device_integrity_check

Root, jailbreak, emulator and developer-mode detection for Flutter — for
Android and iOS.

The distinguishing feature is that it tells you when a check **could not run**.
A probe that failed says nothing about the device, and reporting that as a clean
result is how an unnoticed platform bug becomes a silent hole in your defences.

```dart
import 'package:device_integrity_check/device_integrity_check.dart';

final report = await DeviceIntegrity().evaluate();

if (report.isRooted)   riskScore += 40;
if (report.isEmulator) riskScore += 20;

if (!report.isComplete) {
  log('these checks did not run: ${report.unavailable}');
}
```

## Read this before you rely on it

Every check in this package is a local heuristic — a file-existence test, a
system property read, a package scan — executed inside a process that an
attacker on a rooted device fully controls.

- Magisk's DenyList hides the artefacts this looks for.
- Frida can hook these methods and return whatever it likes.
- Patching the compiled bundle needs no runtime tooling at all.

**Use these signals to raise a risk score or nudge a user. Do not use them as an
authorization decision.** Anything that must actually hold needs server-verified
attestation:

| Platform | Use | Verified where |
| --- | --- | --- |
| Android | [Play Integrity API](https://developer.android.com/google/play/integrity) | your backend |
| iOS | [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity) | your backend |

This package implements none of those and cannot substitute for them. Its name
is `device_integrity_check`, not `DeviceCheck` — it does not use Apple's
DeviceCheck framework.

## Install

```yaml
dependencies:
  device_integrity_check: ^1.0.0
```

## API

### `evaluate()`

Probes every signal concurrently and returns an `IntegrityReport`.

```dart
final report = await DeviceIntegrity().evaluate();

report.isRooted;                // bool
report.isEmulator;              // bool
report.isDeveloperModeEnabled;  // bool

report.detected;      // Set<IntegritySignal> — probed, and fired
report.unavailable;   // Set<IntegritySignal> — could not be probed
report.isComplete;    // unavailable.isEmpty
report.hasAnySignal;  // detected.isNotEmpty
report.platformVersion;
```

A signal in neither set was probed and did not fire. That is the distinction the
booleans alone cannot express:

```dart
// "not rooted" and "could not tell" both read as false here
if (!report.isRooted) { ... }

// so check whether the question was actually answered
if (report.unavailable.contains(IntegritySignal.rooted)) { ... }
```

### Individual probes

```dart
final integrity = DeviceIntegrity();

await integrity.isRooted();               // Future<bool>
await integrity.isEmulator();             // Future<bool>
await integrity.isDeveloperModeEnabled(); // Future<bool>
await integrity.platformVersion();        // Future<String?>
```

### Failure behaviour

Probes **never throw**. A failed or unsupported probe resolves to `false`.

That is a deliberate choice, and it hides failures — so pass an `onError`
handler in production:

```dart
final integrity = DeviceIntegrity(
  onError: (signal, error, stackTrace) {
    Sentry.captureException(error, stackTrace: stackTrace);
  },
);
```

Without a handler, failures are printed via `debugPrint` in debug builds only.

## Platform support

| Signal | Android | iOS |
| --- | --- | --- |
| `rooted` | ✔ RootBeer + `su`/Magisk paths | ✔ path, sandbox and scheme checks |
| `emulator` | ✔ emulator properties, build identifiers, hardware | ✔ compile-time simulator check |
| `developerMode` | ✔ `Settings.Global` | *unavailable* — no equivalent on iOS |

`developerMode` on iOS is reported as **unavailable**, not `false`. Earlier
versions of this package returned a fabricated `false`, which is indistinguishable
from a real answer.

Requirements: Android `minSdk 21`, iOS 12.0. On web and desktop the plugin is
not registered, so `evaluate()` returns a report in which every signal is
unavailable — it does not throw.

### Optional: package-manager URL schemes on iOS

One jailbreak check asks whether `cydia://`, `sileo://` or `zbra://` can be
opened. Since iOS 9 that returns false unless *your app* declares the schemes,
so the check is inert by default. To enable it, add to your `Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>cydia</string>
  <string>sileo</string>
  <string>zbra</string>
</array>
```

The other jailbreak checks work without this.

## Testing

The platform layer sits behind `DeviceIntegrityPlatform`, so you can fake it:

```dart
class FakePlatform extends DeviceIntegrityPlatform {
  @override
  Future<bool?> isRooted() async => true;
  @override
  Future<bool?> isEmulator() async => false;
  @override
  Future<bool?> isDeveloperModeEnabled() async => null; // unavailable
  @override
  Future<String?> platformVersion() async => 'Test OS 1.0';
}

// inject directly...
final report = await DeviceIntegrity(platform: FakePlatform()).evaluate();

// ...or globally, for widget tests
DeviceIntegrityPlatform.instance = FakePlatform();
```

Return `null` from a probe to simulate a signal that cannot be checked.

The on-device suite in `example/integration_test` asserts that each method
actually resolves on the platform under test:

```bash
cd example && flutter test integration_test
```

That suite exists for a specific reason. A previous version of this package
registered its iOS method channel under a different name than Dart called, so
every check on iOS threw `MissingPluginException` — across several published
releases. Nothing caught it: the plugin class registered without error, the
analyzer saw two unrelated string literals, and unit tests with a mocked channel
pass whether or not the native side agrees. Only an on-device round trip does.

## Relationship to `safe_device_check`

This is a rewrite of `safe_device_check`, which was a fork of
[`safe_device`](https://github.com/ufukhawk/safe_device). The API shares nothing
with either; see [CHANGELOG.md](CHANGELOG.md) for what was wrong and what
changed. `LICENSE` retains the upstream MIT notices.

## License

MIT. See [LICENSE](LICENSE).
