import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Detects evidence of a jailbreak.
///
/// This replaces the `DTTJailbreakDetection` pod the plugin previously depended
/// on. That dependency was unpinned, and CocoaPods' newest published version of
/// it is 0.4.0 — dated September 2014. That release checks for `/bin/bash`,
/// `/usr/bin/ssh`, `/usr/sbin/sshd` and `/etc/apt`, all of which exist when an
/// iOS app runs on Apple Silicon macOS, so it reported every such device as
/// jailbroken. Upstream added a guard for exactly that case in 2023, on
/// `master`, and never published it — so pinning the pod could not obtain the
/// fix. The ~50 lines are vendored here instead, with the guard in place.
enum JailbreakDetector {

    /// Paths that should not be readable from inside the app sandbox.
    private static let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries",
        "/usr/lib/libsubstrate.dylib",
        "/usr/lib/libhooker.dylib",
        "/usr/lib/libellekit.dylib",
        "/var/jb",
        "/bin/bash",
        "/bin/sh",
        "/usr/sbin/sshd",
        "/usr/bin/ssh",
        "/etc/apt",
        "/private/var/lib/apt",
        "/private/var/lib/cydia",
    ]

    /// Directories outside the sandbox that a sandboxed app cannot write to.
    private static let sandboxEscapeTargets = [
        "/private/jailbreak_probe.txt",
        "/private/var/mobile/jailbreak_probe.txt",
    ]

    static func isJailbroken() -> Bool {
        // The simulator has a Unix filesystem layout, so every path check below
        // matches there. Nothing useful can be concluded, so decline to guess.
        #if targetEnvironment(simulator)
        return false
        #else

        // An iOS app running on Apple Silicon macOS, or as a Mac Catalyst app,
        // legitimately sees /bin/bash and friends. Without this guard the path
        // checks report every Mac as jailbroken.
        if isRunningOnMac() {
            return false
        }

        return hasSuspiciousPath() || canEscapeSandbox() || canOpenPackageManager()
        #endif
    }

    private static func isRunningOnMac() -> Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    private static func hasSuspiciousPath() -> Bool {
        let fileManager = FileManager.default
        for path in suspiciousPaths {
            if fileManager.fileExists(atPath: path) {
                return true
            }
            // `fileExists` respects the sandbox for some paths where a raw
            // `stat` does not, so check both.
            if let handle = fopen(path, "r") {
                fclose(handle)
                return true
            }
        }
        return false
    }

    private static func canEscapeSandbox() -> Bool {
        for path in sandboxEscapeTargets {
            do {
                try ".".write(toFile: path, atomically: true, encoding: .utf8)
                try? FileManager.default.removeItem(atPath: path)
                return true
            } catch {
                continue
            }
        }
        return false
    }

    /// Whether a package-manager URL scheme can be opened.
    ///
    /// Since iOS 9 this returns false unless the *host application* lists the
    /// scheme in `LSApplicationQueriesSchemes`. The previous implementation
    /// relied on this check without documenting that requirement, so it never
    /// fired in any real app. It is kept because it costs nothing when the key
    /// is absent, and the README now tells consumers how to enable it.
    private static func canOpenPackageManager() -> Bool {
        #if canImport(UIKit) && !os(macOS)
        guard Thread.isMainThread else {
            // `UIApplication` is main-thread only. Probes run off the main
            // thread, so skip rather than risk an assertion.
            return false
        }
        for scheme in ["cydia://", "sileo://", "zbra://"] {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        #endif
        return false
    }
}
