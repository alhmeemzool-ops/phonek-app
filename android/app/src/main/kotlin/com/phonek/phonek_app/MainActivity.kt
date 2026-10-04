package com.phonek.phonek_app

import android.content.Intent
import android.content.ClipData
import android.content.pm.PackageManager
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
        val updateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        PhoneKInstaller.channel = updateChannel
        updateChannel.setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                handleInstallApk(call.argument<String>("filePath"), result)
                return@setMethodCallHandler
            }
            if (call.method == "getLastInstallResult") {
                result.success(PhoneKInstaller.lastResult(this))
                return@setMethodCallHandler
            }
            if (call.method == "clearInstallResult") {
                PhoneKInstaller.clearResult(this)
                result.success(null)
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
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        PhoneKInstaller.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleInstallApk(path: String?, result: MethodChannel.Result) {
        val apk = File(path ?: "")
        val problem: String? = when {
            path.isNullOrBlank() -> "APK path is empty"
            !apk.exists() || apk.length() <= 0L -> "APK file does not exist"
            else -> null
        }
        if (problem != null) {
            result.error("INSTALL_ERROR", problem, null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.error(
                "INSTALL_PERMISSION",
                "Unknown-source installation permission is not granted",
                null,
            )
            return
        }

        // فحص مسبق: يمنع محاولة تثبيت ملف سيرفضه النظام (توقيع مختلف / حزمة مختلفة)
        // ويعطي المستخدم سبباً واضحاً بدل رسالة عامة.
        val rejection = preflightApk(apk)
        if (rejection != null) {
            result.error("APK_REJECTED", rejection, null)
            return
        }

        // نسخ ملف كبير يجب ألا يتم على الخيط الرئيسي (يسبب تجمّد).
        Thread {
            val sessionError: String? = try {
                PhoneKInstaller.install(this, apk)
                null
            } catch (error: Exception) {
                error.javaClass.simpleName + ": " + (error.message ?: "")
            }
            runOnUiThread {
                if (sessionError == null) {
                    result.success("session")
                } else {
                    installWithIntent(apk, sessionError, result)
                }
            }
        }.start()
    }

    // خطة احتياط: الطريقة القديمة عبر FileProvider إذا فشلت جلسة PackageInstaller.
    private fun installWithIntent(apk: File, sessionError: String, result: MethodChannel.Result) {
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.phonek.fileprovider",
                apk,
            )
            val installIntents = listOf(
                Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                    clipData = ClipData.newRawUri("APK", uri)
                },
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    clipData = ClipData.newRawUri("APK", uri)
                },
            )

            var lastError: Exception? = null
            for (installIntent in installIntents) {
                try {
                    startActivity(installIntent)
                    result.success("intent")
                    return
                } catch (error: Exception) {
                    lastError = error
                }
            }
            val intentError = if (lastError != null) {
                lastError.javaClass.simpleName + ": " + (lastError.message ?: "")
            } else {
                "no installer activity"
            }
            result.error("INSTALL_ERROR", "session: $sessionError | intent: $intentError", null)
        } catch (error: Exception) {
            result.error(
                "INSTALL_ERROR",
                "session: $sessionError | fileprovider: ${error.javaClass.simpleName}: ${error.message}",
                null,
            )
        }
    }

    // يرجع null إذا كان الملف سليماً (أو إذا تعذر الفحص)، وإلا نص يبدأ برمز السبب.
    @Suppress("DEPRECATION")
    private fun preflightApk(apk: File): String? {
        try {
            val pm = packageManager
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                0
            }
            val archive = pm.getPackageArchiveInfo(apk.absolutePath, flags) ?: return null
            if (archive.packageName != packageName) {
                return "APK_WRONG_PACKAGE: ${archive.packageName}"
            }
            val installed = pm.getPackageInfo(packageName, flags)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val newCode = archive.longVersionCode
                val oldCode = installed.longVersionCode
                if (newCode <= oldCode) {
                    return "APK_NOT_NEWER: $newCode <= $oldCode"
                }
                val newSigners = archive.signingInfo?.apkContentsSigners
                val oldSigners = installed.signingInfo?.apkContentsSigners
                if (newSigners != null && oldSigners != null &&
                    newSigners.isNotEmpty() && oldSigners.isNotEmpty()
                ) {
                    val same = newSigners.any { n -> oldSigners.any { o -> n == o } }
                    if (!same) return "APK_SIGNATURE_MISMATCH"
                }
            } else {
                if (archive.versionCode <= installed.versionCode) {
                    return "APK_NOT_NEWER: ${archive.versionCode} <= ${installed.versionCode}"
                }
            }
            return null
        } catch (error: Exception) {
            return null
        }
    }

    private fun playLevelUpSound(level: Int) {
        Thread {
            val sampleRate = 44100
            val safeLevel = level.coerceIn(1, 10)
            val durations = intArrayOf(620, 700, 780, 900, 1020, 1160, 1320, 1500, 1680, 1950)
            val noteSets = arrayOf(
                doubleArrayOf(523.25, 659.25),
                doubleArrayOf(523.25, 659.25, 783.99),
                doubleArrayOf(392.0, 523.25, 659.25),
                doubleArrayOf(440.0, 554.37, 659.25, 880.0),
                doubleArrayOf(392.0, 493.88, 587.33, 783.99),
                doubleArrayOf(440.0, 523.25, 659.25, 783.99, 1046.5),
                doubleArrayOf(392.0, 493.88, 587.33, 783.99, 987.77),
                doubleArrayOf(349.23, 440.0, 554.37, 659.25, 880.0, 1108.73),
                doubleArrayOf(329.63, 415.30, 523.25, 659.25, 830.61, 1046.5),
                doubleArrayOf(261.63, 329.63, 392.0, 523.25, 659.25, 783.99, 1046.5, 1318.51)
            )
            val durationMs = durations[safeLevel - 1]
            val notes = noteSets[safeLevel - 1]
            val sampleCount = sampleRate * durationMs / 1000
            val buffer = ShortArray(sampleCount)

            for (i in 0 until sampleCount) {
                val t = i.toDouble() / sampleRate
                val total = durationMs / 1000.0
                val progress = (t / total).coerceIn(0.0, 0.999999)
                val segment = (progress * notes.size).toInt().coerceAtMost(notes.size - 1)
                val localT = t - segment * (total / notes.size)
                val freq = notes[segment]
                val attack = (localT / 0.025).coerceAtMost(1.0)
                val release = if (t > total - 0.16) ((total - t) / 0.16).coerceIn(0.0, 1.0) else 1.0
                val shimmer = kotlin.math.sin(2.0 * Math.PI * freq * 2.0 * t) * 0.16
                val tone = kotlin.math.sin(2.0 * Math.PI * freq * t) * 0.68 + shimmer
                val envelope = attack * release
                buffer[i] = (tone * envelope * (9000.0 + safeLevel * 450.0)).toInt().toShort()
            }

            val minBuffer = android.media.AudioTrack.getMinBufferSize(
                sampleRate,
                android.media.AudioFormat.CHANNEL_OUT_MONO,
                android.media.AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) return@Thread

            val track = android.media.AudioTrack.Builder()
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    android.media.AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
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
