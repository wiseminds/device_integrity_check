package io.github.wiseminds.device_integrity_check.util

import android.annotation.SuppressLint
import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.reflect.Method

/**
 * Reads Android system properties (`getprop`).
 *
 * Two paths, because neither is reliable alone:
 *
 *  * Reflection into `android.os.SystemProperties`. Fast, but a non-SDK
 *    interface subject to the hidden-API policy, which tightens with each
 *    release and varies by vendor image.
 *  * Shelling out to `getprop`. Slower, but public.
 *
 * The previous implementation of this fallback could never succeed: it built
 * one command string, `getprop "name" ""`, and passed it to
 * `Runtime.exec(String)`, which splits on whitespace with no quote handling.
 * `getprop` therefore received an argument that literally included the quote
 * characters, failed to find a property by that name, and returned the default
 * — so the fallback silently reported every property as absent. It also latched
 * a `failed` flag permanently on first reflection error, returned a
 * possibly-null `readLine()` from a non-null `String` function, and never
 * closed the process streams.
 */
internal object SystemProperties {

    @Volatile
    private var getPropMethod: Method? = null

    @Volatile
    private var reflectionUnavailable = false

    /**
     * Returns the value of [name], or [default] if it is unset or unreadable.
     */
    fun get(name: String, default: String = ""): String =
        readViaReflection(name, default) ?: readViaExec(name) ?: default

    @SuppressLint("PrivateApi")
    private fun readViaReflection(name: String, default: String): String? {
        if (reflectionUnavailable) return null
        return try {
            val method = getPropMethod ?: Class.forName("android.os.SystemProperties")
                .getMethod("get", String::class.java, String::class.java)
                .also { getPropMethod = it }
            method.invoke(null, name, default) as String?
        } catch (_: Exception) {
            // Blocked or absent. Remember that so we do not pay the reflection
            // cost on every property, but keep the exec path available.
            reflectionUnavailable = true
            getPropMethod = null
            null
        }
    }

    private fun readViaExec(name: String): String? {
        var process: Process? = null
        return try {
            // The array form passes `name` as a single argv entry. The string
            // form would not.
            process = Runtime.getRuntime().exec(arrayOf("getprop", name))
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                reader.readLine()?.trim()?.takeIf(String::isNotEmpty)
            }
        } catch (_: Exception) {
            null
        } finally {
            process?.destroy()
        }
    }
}
