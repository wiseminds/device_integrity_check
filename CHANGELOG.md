# Changelog

## 1.0.0

First release under the name `device_integrity_check`. This is a rewrite of
`safe_device_check` 0.0.2+4, which was itself a fork of `safe_device`. The API
is new; nothing from the old package carries over.

### Fixed — the package did not work

- **iOS: every check threw.** The Objective-C plugin registered its method
  channel as `safe_device` while Dart called `device_check`, so all three real
  checks raised `MissingPluginException` on every iOS release. The plugin class
  registered without error, so nothing surfaced the mismatch. There is now one
  channel name, asserted by an on-device integration test.
- **Android: the module no longer compiled.** `String.toLowerCase(Locale)` is a
  compile error on current Kotlin, so the plugin could not be built with any
  supported toolchain.
- **`platformVersion` threw on both platforms.** Dart invoked
  `getPlatformVersion`; Android handled `platformVersion`. Method names are now
  derived from a single source (`IntegritySignal.methodName`).

### Fixed — detection logic

- **Emulator detection missed every current AVD.** Eleven of the twelve
  heuristics were built for 2019 fingerprints and matched nothing on a modern
  image; the result rested entirely on one `ro.kernel.qemu` read whose fallback
  path could not work — it passed quote characters into `getprop` as part of the
  property name. Detection now reads `ro.hardware`, `ro.boot.qemu`,
  `ro.build.characteristics` and `ro.hardware.virtual_device`, matches build
  identifiers case-insensitively on substrings, and reads properties through a
  fixed `exec` path.
- **Root detection false-positived on four OEM brands.** OnePlus, Motorola,
  Xiaomi and Oppo devices were routed to RootBeer's busybox variant, which
  reports rooted strictly more often — and which RootBeer documents as unsafe
  precisely because those manufacturers ship busybox on stock ROMs. All devices
  now take the same path.
- **Brand matching was locale-sensitive.** Lowercasing `Build.BRAND` under the
  user's locale broke matching under Turkish. Uses `Locale.ROOT`.
- **Two `su` checks were dead code.** Both shelled out to `/system/xbin/which`,
  absent from Android for years. Replaced with direct path checks that also
  cover `/su/bin/su`, `/system_ext/bin/su` and Magisk locations.
- **iOS jailbreak detection reported every Mac as jailbroken.** The unpinned
  `DTTJailbreakDetection` dependency resolved to 0.4.0 (2014), which checks for
  `/bin/bash` and `/usr/bin/ssh` — present when an iOS app runs on Apple
  Silicon macOS. Upstream's fix was never published, so pinning could not
  obtain it. Detection is now vendored, with `isiOSAppOnMac` and Mac Catalyst
  guards.
- **Developer-mode detection** read a `Settings.Global` key through a deprecated
  `Settings.Secure` redirect, behind version branches unreachable at
  `minSdk 21`. Reads `Settings.Global` directly.
- RootBeer updated to 0.1.2, adding `/system_ext/bin` to its `su` search and
  completing 16 KB page-size support for Android 15/16.

### Fixed — behaviour under failure

- **Probes no longer block the UI thread.** A cold root scan measured 1.8 s on
  the platform thread. All native probes run on a background thread and answer
  on the main thread.
- **Failures are no longer exceptions.** Probes resolve to `false` and report to
  an `onError` callback. Because that hides failures by design, every failed or
  unsupported probe is also recorded in `IntegrityReport.unavailable`.
- **"Could not check" is distinguishable from "clean."** `IntegrityReport`
  reports which signals fired, which did not, and which could not be probed.
  Developer mode on iOS is now `unavailable` rather than a fabricated `false`.

### Changed

- Package renamed to `device_integrity_check`; library is
  `package:device_integrity_check/device_integrity_check.dart`.
- Static getters replaced by `DeviceIntegrity`, an instance-based API behind
  `DeviceIntegrityPlatform`, so it can be faked in tests.
- `isInstalledOnExternalStorage` removed. It read `FLAG_EXTERNAL_STORAGE`, which
  reflects an install mode modern Android no longer offers, so it was
  effectively a constant `false`; its fallback was unreachable.
- Android package is now `io.github.wiseminds.device_integrity_check`;
  `minSdk 21`, `compileSdk 35`, Java 17.
- iOS deployment target raised to 12.0. Swift Package Manager is supported.

### Added

- Swift Package Manager support.
- 24 unit tests (20 for the plugin, 4 for the example) plus a 7-test on-device
  integration suite that asserts the native channel contract. All were run
  against a Pixel 9 Pro AVD (API 37) and an iPhone 17 Pro Max simulator
  (iOS 26).
- Documentation of the trust model: these are unattested client-side
  heuristics, defeated by Magisk DenyList or Frida, and must not be used as an
  authorization decision. See the README and `DeviceIntegrity`'s API docs.
