package io.github.wiseminds.device_integrity_check.devmode

import android.content.Context
import android.provider.Settings

/**
 * Reports whether developer options are enabled.
 *
 * The previous implementation branched on `SDK_INT` against `JELLY_BEAN`, which
 * is unreachable at `minSdk 21`, and read this `Settings.Global` key through
 * `Settings.Secure.getInt`, which works only via a deprecated
 * moved-to-global redirect. This reads the key where it actually lives.
 */
object DeveloperModeDetector {

    fun isEnabled(context: Context): Boolean = Settings.Global.getInt(
        context.contentResolver,
        Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
        0,
    ) != 0
}
