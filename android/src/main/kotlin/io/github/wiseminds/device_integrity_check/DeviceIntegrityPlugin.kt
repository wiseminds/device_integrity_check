package io.github.wiseminds.device_integrity_check

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.github.wiseminds.device_integrity_check.devmode.DeveloperModeDetector
import io.github.wiseminds.device_integrity_check.emulator.EmulatorDetector
import io.github.wiseminds.device_integrity_check.root.RootDetector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors

/**
 * Android implementation of the `device_integrity_check` plugin.
 *
 * Every probe here touches the filesystem, spawns processes, or enumerates
 * installed packages. Method-channel handlers run on the platform main thread,
 * so doing that work inline blocks frame production — a full root scan was
 * measured at 1.8 seconds on a cold start. All probes therefore run on a
 * background executor and post their result back to the main thread, which is
 * where [Result] must be answered.
 */
class DeviceIntegrityPlugin : FlutterPlugin, MethodCallHandler {

    private companion object {
        /**
         * Must match `MethodChannelDeviceIntegrity.channelName` in Dart and the
         * channel name in `DeviceIntegrityPlugin.swift`.
         */
        const val CHANNEL_NAME = "device_integrity_check"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null

    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "device-integrity-check").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).apply {
            setMethodCallHandler(this@DeviceIntegrityPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" ->
                result.success("Android ${android.os.Build.VERSION.RELEASE}")

            "isRooted" -> offload(result) { ctx -> RootDetector.isRooted(ctx) }

            "isEmulator" -> offload(result) { EmulatorDetector.isEmulator() }

            "isDeveloperModeEnabled" ->
                offload(result) { ctx -> DeveloperModeDetector.isEnabled(ctx) }

            else -> result.notImplemented()
        }
    }

    /**
     * Runs [probe] on the background executor and answers [result] on the main
     * thread.
     *
     * A probe that throws is reported as a channel error rather than being
     * swallowed. The Dart layer decides what an unanswerable check means; it
     * cannot do that if the failure never reaches it.
     */
    private fun offload(result: Result, probe: (Context) -> Boolean) {
        val ctx = context
        if (ctx == null) {
            result.error(
                "no_context",
                "Plugin is not attached to an engine.",
                null,
            )
            return
        }
        worker.execute {
            val outcome = runCatching { probe(ctx) }
            mainHandler.post {
                outcome
                    .onSuccess(result::success)
                    .onFailure { error ->
                        result.error(
                            "probe_failed",
                            error.message ?: error::class.java.simpleName,
                            null,
                        )
                    }
            }
        }
    }
}
