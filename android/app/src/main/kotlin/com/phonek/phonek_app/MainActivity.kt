package com.phonek.phonek_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "phonek/update_permissions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "canInstallPackages") {
                result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls())
                return@setMethodCallHandler
            }

            if (call.method == "getInstalledApkPath") {
                // مسار ملف الـ APK الحالي المُثبَّت فعلياً على الجهاز (base.apk).
                // نستخدمه كأساس لتطبيق التحديث التزايدي (patch) دون إعادة تحميله.
                try {
                    val path = applicationInfo.sourceDir
                    result.success(path)
                } catch (error: Exception) {
                    result.success(null)
                }
                return@setMethodCallHandler
            }

            if (call.method != "openInstallPermissionSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            } else {
                startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
            }
            result.success(null)
        }
    }
}
