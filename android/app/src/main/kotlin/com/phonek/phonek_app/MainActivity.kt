package com.phonek.phonek_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.io.File
import java.io.FileInputStream
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "phonek/update_permissions"
    private val levelUpChannelName = "phonek/level_up"
    private val installStatusChannelName = "phonek/update_status"

    companion object {
        @Volatile
        private var installStatusSink: EventChannel.EventSink? = null

        fun publishInstallStatus(status: Int, statusMessage: String) {
            installStatusSink?.success(
                mapOf(
                    "status" to status,
                    "statusMessage" to statusMessage,
                )
            )
        }
    }

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
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, installStatusChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    installStatusSink = events
                }

                override fun onCancel(arguments: Any?) {
                    installStatusSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("filePath")
                var session: PackageInstaller.Session? = null
                try {
                    require(!path.isNullOrBlank()) { "APK path is empty" }
                    val apk = File(path)
                    require(apk.exists() && apk.length() > 0) { "APK file does not exist" }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        result.error(
                            "INSTALL_PERMISSION",
                            "Unknown-source installation permission is not granted",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val packageInstaller = packageManager.packageInstaller
                    val params = PackageInstaller.SessionParams(
                        PackageInstaller.SessionParams.MODE_FULL_INSTALL
                    ).apply {
                        setSize(apk.length())
                        setAppPackageName(packageName)
                    }
                    val sessionId = packageInstaller.createSession(params)
                    val installSession = packageInstaller.openSession(sessionId)
                    session = installSession

                    FileInputStream(apk).use { input ->
                        installSession.openWrite("base.apk", 0, apk.length()).use { output ->
                            input.copyTo(output)
                            installSession.fsync(output)
                        }
                    }

                    val callbackIntent = Intent(
                        this,
                        PhoneKInstallStatusReceiver::class.java,
                    ).apply {
                        action = PhoneKInstallStatusReceiver.ACTION_INSTALL_STATUS
                        putExtra(
                            PhoneKInstallStatusReceiver.EXTRA_SESSION_ID,
                            sessionId,
                        )
                    }
                    val pendingIntentFlags =
                        PendingIntent.FLAG_UPDATE_CURRENT or
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                PendingIntent.FLAG_IMMUTABLE
                            } else {
                                0
                            }
                    val pendingIntent = PendingIntent.getBroadcast(
                        this,
                        sessionId,
                        callbackIntent,
                        pendingIntentFlags,
                    )

                    installSession.commit(pendingIntent.intentSender)
                    result.success(null)
                } catch (error: Exception) {
                    session?.abandon()
                    result.error(
                        "INSTALL_ERROR",
                        error.javaClass.simpleName + ": " + (error.message ?: ""),
                        null,
                    )
                } finally {
                    session?.close()
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
                    if (!applicationInfo.splitSourceDirs.isNullOrEmpty()) {
                        // Split APK installations are not a valid byte-for-byte base
                        // for the incremental patch format used by PhoneK.
                        result.success(null)
                        return@setMethodCallHandler
                    }
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
class PhoneKInstallStatusReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_INSTALL_STATUS =
            "com.phonek.phonek_app.ACTION_INSTALL_STATUS"
        const val EXTRA_SESSION_ID =
            "com.phonek.phonek_app.EXTRA_SESSION_ID"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val statusMessage =
            intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE).orEmpty()

        MainActivity.publishInstallStatus(status, statusMessage)

        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val userActionIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(
                    Intent.EXTRA_INTENT,
                    Intent::class.java,
                )
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
            }

            if (userActionIntent != null) {
                userActionIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(userActionIntent)
                } catch (error: Exception) {
                    MainActivity.publishInstallStatus(
                        PackageInstaller.STATUS_FAILURE,
                        error.javaClass.simpleName + ": " + (error.message ?: ""),
                    )
                }
            } else {
                MainActivity.publishInstallStatus(
                    PackageInstaller.STATUS_FAILURE,
                    "Android did not provide the installer confirmation intent.",
                )
            }
        }
    }
}

