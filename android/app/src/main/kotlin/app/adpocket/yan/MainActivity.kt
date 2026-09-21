package app.adpocket.yan

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.adpocket.yan/battery")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Whether the OS may throttle our background work.
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    // The system's battery-optimisation list (no permission needed,
                    // Play-policy safe); the user picks AdPocket -> "Don't optimize".
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(startSafely(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)))
                    }
                    // The app's own settings page, where vendors put their
                    // "battery" / "background activity" switches.
                    "openAppSettings" -> {
                        result.success(startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                        }))
                    }
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSafely(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
