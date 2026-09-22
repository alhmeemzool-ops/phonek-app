package com.phonek.phonek_app

import android.content.Intent
import android.content.ClipData
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "phonek/update_permissions"
    private val levelUpChannelName = "phonek/level_up"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, levelUpChannelName).setMethodCallHandler { call, result ->
            if (call.method == "playLevelUpSound") {
                val level = (call.argument<Int>("level") ?: 1).coerceIn(1, 10)
                playLevelUpSound(level)
                result.success(null)
                return@setMethodCallHandler
            }
            result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("filePath")
                try {
                    require(!path.isNullOrBlank()) { "APK path is empty" }
                    val apk = File(path)
                    require(apk.exists() && apk.length() > 0) { "APK file does not exist" }
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.phonek.fileprovider",
                        apk,
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        clipData = ClipData.newRawUri("APK", uri)
                    }
                    if (packageManager.queryIntentActivities(intent, 0).isEmpty()) {
                        throw IllegalStateException("No APK installer found")
                    }
                    startActivity(intent)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("INSTALL_ERROR", error.message, null)
                }
                return@setMethodCallHandler
            }
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
    private fun playLevelUpSound(level: Int) {
        Thread {
            val sampleRate = 44100
            val durationMs = when {
                level >= 10 -> 1800
                level >= 7 -> 1450
                level >= 4 -> 1100
                else -> 750
            }
            val sampleCount = sampleRate * durationMs / 1000
            val buffer = ShortArray(sampleCount)
            val notes = when {
                level >= 10 -> doubleArrayOf(392.0, 523.25, 659.25, 783.99, 1046.5)
                level >= 7 -> doubleArrayOf(392.0, 493.88, 587.33, 783.99)
                level >= 4 -> doubleArrayOf(440.0, 554.37, 659.25)
                else -> doubleArrayOf(523.25, 659.25)
            }
            for (i in 0 until sampleCount) {
                val t = i.toDouble() / sampleRate
                val total = durationMs / 1000.0
                val segment = ((t / total) * notes.size).toInt().coerceAtMost(notes.size - 1)
                val localT = t - segment * (total / notes.size)
                val freq = notes[segment]
                val attack = (localT / 0.035).coerceAtMost(1.0)
                val release = if (t > total - 0.12) ((total - t) / 0.12).coerceIn(0.0, 1.0) else 1.0
                val envelope = attack * release
                val wave = kotlin.math.sin(2.0 * Math.PI * freq * t) * 0.72 + kotlin.math.sin(2.0 * Math.PI * freq * 2.0 * t) * 0.20
                buffer[i] = (wave * envelope * 11000.0).toInt().toShort()
            }
            val minBuffer = android.media.AudioTrack.getMinBufferSize(sampleRate, android.media.AudioFormat.CHANNEL_OUT_MONO, android.media.AudioFormat.ENCODING_PCM_16BIT)
            if (minBuffer <= 0) return@Thread
            val track = android.media.AudioTrack.Builder()
                .setAudioAttributes(android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION).setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                .setAudioFormat(android.media.AudioFormat.Builder().setSampleRate(sampleRate).setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT).setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(maxOf(minBuffer, buffer.size * 2))
                .setTransferMode(android.media.AudioTrack.MODE_STATIC)
                .build()
            try {
                track.write(buffer, 0, buffer.size)
                track.play()
                Thread.sleep(durationMs.toLong() + 80L)
            } finally {
                track.stop()
                track.release()
            }
        }.start()
    }

}
