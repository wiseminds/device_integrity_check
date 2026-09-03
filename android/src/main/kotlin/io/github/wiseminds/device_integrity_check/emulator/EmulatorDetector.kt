package io.github.wiseminds.device_integrity_check.emulator

import android.os.Build
import io.github.wiseminds.device_integrity_check.util.SystemProperties

/**
 * Detects whether the app is running on an emulator.
 *
 * The previous implementation was twelve OR'd clauses built around fingerprints
 * from around 2019. Measured against a current Android Studio AVD, eleven of
 * the twelve were false: the fingerprint tests required `sdk_gphone_` with a
 * trailing underscore and `:user/release-keys`, while a current image reports
 * `sdk_gphone16k_arm64` and `dev-keys`. The whole result rested on a single
 * `ro.kernel.qemu` read whose fallback path could not work.
 *
 * This version checks the properties an emulator actually sets today, each of
 * which is independently sufficient, so no single blocked read decides the
 * answer.
 */
object EmulatorDetector {

    /** `ro.hardware` values used by emulator kernels. */
    private val EMULATOR_HARDWARE = setOf(
        "goldfish",   // original QEMU-based emulator
        "ranchu",     // current Android emulator
        "vbox86",     // Genymotion / VirtualBox
        "cheets",     // ARC++
    )

    /** Substrings that appear in emulator device/product/model identifiers. */
    private val EMULATOR_NAME_HINTS = listOf(
        "sdk_gphone",  // matches sdk_gphone_x86, sdk_gphone64_arm64, sdk_gphone16k_arm64
        "google_sdk",
        "sdk_google",
        "emulator",
        "android sdk built for",
        "droid4x",
        "nox",
        "bluestacks",
        "genymotion",
        "vbox",
    )

    fun isEmulator(): Boolean =
        hasEmulatorProperty() || hasEmulatorBuildIdentifier() || hasEmulatorHardware()

    /**
     * Properties the emulator sets explicitly. Checked first: they are the
     * strongest signals and the cheapest to read.
     */
    private fun hasEmulatorProperty(): Boolean =
        SystemProperties.get("ro.kernel.qemu") == "1" ||
            SystemProperties.get("ro.boot.qemu") == "1" ||
            SystemProperties.get("ro.build.characteristics").contains("emulator") ||
            SystemProperties.get("ro.hardware.virtual_device").isNotEmpty()

    /**
     * Build identifiers. Matched case-insensitively on substrings rather than
     * exact strings, so a new image variant does not silently stop matching.
     */
    private fun hasEmulatorBuildIdentifier(): Boolean {
        val identifiers = listOf(
            Build.FINGERPRINT,
            Build.MODEL,
            Build.PRODUCT,
            Build.DEVICE,
            Build.MANUFACTURER,
            Build.BRAND,
            Build.HARDWARE,
        ).joinToString(" ") { it.orEmpty() }.lowercase()

        if (EMULATOR_NAME_HINTS.any { it in identifiers }) return true

        // Generic AOSP builds: only conclusive when brand *and* device agree,
        // since "generic" alone appears on some real low-cost hardware.
        return Build.BRAND.orEmpty().startsWith("generic", ignoreCase = true) &&
            Build.DEVICE.orEmpty().startsWith("generic", ignoreCase = true)
    }

    private fun hasEmulatorHardware(): Boolean {
        val hardware = Build.HARDWARE.orEmpty().lowercase()
        return EMULATOR_HARDWARE.any { hardware.startsWith(it) }
    }
}
