package io.github.wiseminds.device_integrity_check.root

import android.content.Context
import com.scottyab.rootbeer.RootBeer
import java.io.File

/**
 * Detects evidence of root.
 *
 * Two tiers: RootBeer, which does the substantive work, plus a small set of
 * `su` and Magisk paths RootBeer's binary search does not cover.
 *
 * Two things the previous implementation did are deliberately not done here.
 *
 * It shelled out to `/system/xbin/which su` in two separate classes; that
 * binary has not existed on Android for years, so both calls threw `IOException`
 * and returned false on every device. Path checks replace them.
 *
 * More importantly, it called [RootBeer.isRootedWithBusyBoxCheck] for OnePlus,
 * Motorola, Xiaomi and Oppo devices and [RootBeer.isRooted] for everything
 * else. The busybox variant is `isRooted()` *plus* a busybox binary check, so
 * it reports rooted strictly more often — and RootBeer's own documentation
 * warns that "busybox binary is not always an indication of root, many
 * manufacturers leave this binary on production devices". The special case
 * therefore made stock devices from four major OEMs the most likely to be
 * falsely flagged. It is gone; every device takes the same path.
 */
object RootDetector {

    /**
     * `su` and Magisk locations to test directly.
     *
     * RootBeer checks a similar list, but not `/su/bin/su` or the Magisk
     * daemon paths, and only picked up `/system_ext/bin` in 0.1.2.
     */
    private val ROOT_PATHS = arrayOf(
        "/data/local/bin/su",
        "/data/local/su",
        "/data/local/xbin/su",
        "/sbin/su",
        "/sbin/.magisk",
        "/su/bin/su",
        "/system/app/Superuser.apk",
        "/system/bin/failsafe/su",
        "/system/bin/su",
        "/system/etc/init.d/99SuperSUDaemon",
        "/system/sd/xbin/su",
        "/system/xbin/daemonsu",
        "/system/xbin/su",
        "/system_ext/bin/su",
    )

    fun isRooted(context: Context): Boolean =
        RootBeer(context).isRooted || hasRootPath()

    private fun hasRootPath(): Boolean = ROOT_PATHS.any { path ->
        try {
            File(path).exists()
        } catch (_: SecurityException) {
            false
        }
    }
}
