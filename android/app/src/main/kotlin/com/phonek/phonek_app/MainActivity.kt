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

    // احتفال الشارة: ضربة فورية + فانفير + تشويق + انفجار + ذيل طويل.
    // الصوت يتدرج من 6.0s إلى 10.5s، بدون كلام أو SystemSound إضافي.
    private fun playLevelUpSound(level: Int) {
        Thread {
            val sampleRate = 44100
            val tier = level.coerceIn(1, 10)
            val durationMs = 6000 + ((tier - 1) * 500)
            val totalSamples = sampleRate * durationMs / 1000
            val raw = DoubleArray(totalSamples)
            val notes = arrayOf(
                doubleArrayOf(261.63, 329.63, 392.00),
                doubleArrayOf(293.66, 369.99, 440.00, 554.37),
                doubleArrayOf(329.63, 415.30, 523.25, 659.25),
                doubleArrayOf(349.23, 440.00, 523.25, 659.25, 783.99),
                doubleArrayOf(392.00, 493.88, 587.33, 783.99, 987.77),
                doubleArrayOf(440.00, 554.37, 659.25, 880.00, 1108.73),
                doubleArrayOf(493.88, 622.25, 739.99, 987.77, 1244.51, 1479.98),
                doubleArrayOf(523.25, 659.25, 783.99, 1046.50, 1318.51, 1567.98),
                doubleArrayOf(587.33, 739.99, 880.00, 1174.66, 1479.98, 1760.00),
                doubleArrayOf(659.25, 783.99, 987.77, 1318.51, 1567.98, 1975.53, 2637.02)
            )[tier - 1]

            fun env(t: Double, a: Double, r: Double, end: Double): Double {
                val attack = (t / a).coerceIn(0.0, 1.0)
                val release = if (t > end - r) ((end - t) / r).coerceIn(0.0, 1.0) else 1.0
                return attack * release
            }
            fun sine(freq: Double, t: Double): Double = kotlin.math.sin(2.0 * Math.PI * freq * t)
            fun noiseLike(i: Int): Double {
                var x = i * 1103515245L + 12345L
                x = x xor (x shr 16)
                return ((x and 0x7fffffffL).toDouble() / 1073741823.5) - 1.0
            }

            val total = durationMs / 1000.0
            val fanfareStart = 0.18
            val fanfareEnd = 1.65 + tier * 0.045
            val suspenseStart = fanfareEnd
            val explosionAt = (2.15 + tier * 0.16).coerceAtMost(total - 2.0)
            val tailStart = explosionAt + 0.28
            val strength = 0.72 + tier * 0.025

            for (i in raw.indices) {
                val t = i.toDouble() / sampleRate
                var s = 0.0

                // 1) Immediate cinematic impact.
                val impact = kotlin.math.exp(-t * (20.0 - tier * 0.35))
                s += sine(58.0 + tier * 2.2, t) * impact * (0.70 + tier * 0.025)
                s += sine(116.0 + tier * 4.0, t) * impact * 0.26
                s += noiseLike(i) * impact * (0.08 + tier * 0.006)

                // 2) Rising fanfare.
                if (t >= fanfareStart && t < fanfareEnd) {
                    val local = t - fanfareStart
                    val seg = (local / ((fanfareEnd - fanfareStart) / notes.size)).toInt().coerceIn(0, notes.size - 1)
                    val segLen = (fanfareEnd - fanfareStart) / notes.size
                    val lt = local - seg * segLen
                    val f = notes[seg]
                    val e = env(lt, 0.025, 0.18, segLen)
                    s += sine(f, t) * e * 0.34
                    s += sine(f * 2.0, t) * e * 0.16
                    s += sine(f * 3.0, t) * e * (0.07 + tier * 0.004)
                    s += sine(f * 0.5, t) * e * (0.06 + tier * 0.006)
                }

                // 3) Suspense / rising shimmer.
                if (t >= suspenseStart && t < explosionAt) {
                    val q = ((t - suspenseStart) / (explosionAt - suspenseStart)).coerceIn(0.0, 1.0)
                    val sweep = 420.0 + q * (1100.0 + tier * 90.0)
                    val e = 0.08 + q * 0.20
                    s += sine(sweep, t) * e
                    s += sine(sweep * 1.5, t) * e * 0.38
                    s += sine(7.0 + q * 15.0, t) * e * 0.10
                }

                // 4) Big explosion / crown hit.
                val ex = t - explosionAt
                if (ex >= 0.0 && ex < 0.55 + tier * 0.012) {
                    val boom = kotlin.math.exp(-ex * (8.0 - tier * 0.12))
                    s += sine(45.0 + tier * 3.0, ex) * boom * (1.05 + tier * 0.05)
                    s += sine(91.0 + tier * 5.0, ex) * boom * 0.42
                    s += noiseLike(i) * boom * (0.28 + tier * 0.018)
                    val crack = kotlin.math.exp(-ex * 32.0)
                    s += sine(1400.0 + tier * 120.0, ex) * crack * 0.18
                }

                // 5) Long harmonic tail.
                if (t >= tailStart) {
                    val q = t - tailStart
                    val decay = kotlin.math.exp(-q / (1.55 + tier * 0.10))
                    val root = notes.last()
                    s += sine(root, q) * decay * 0.22
                    s += sine(root * 1.5, q) * decay * 0.13
                    s += sine(root * 2.0, q) * decay * 0.07
                }

                raw[i] = s * strength
            }

            // Stereo-style spaciousness collapsed safely to mono: short multi-tap reverb.
            val wet = DoubleArray(totalSamples)
            val taps = intArrayOf(1900, 3300, 5100, 7600, 10300)
            val gains = doubleArrayOf(0.18, 0.13, 0.095, 0.065, 0.04)
            for (i in raw.indices) {
                var r = 0.0
                for (k in taps.indices) {
                    val j = i - taps[k]
                    if (j >= 0) r += raw[j] * gains[k]
                }
                wet[i] = r
            }

            val buffer = ShortArray(totalSamples)
            var peak = 0.0
            for (i in raw.indices) peak = maxOf(peak, kotlin.math.abs(raw[i] + wet[i]))
            val norm = if (peak > 0.001) (0.88 / peak) else 1.0
            for (i in raw.indices) {
                val x = (raw[i] + wet[i] * (0.72 + tier * 0.018)) * norm
                val limited = kotlin.math.tanh(x * 1.15) / kotlin.math.tanh(1.15)
                buffer[i] = (limited * 30000.0).coerceIn(-32767.0, 32767.0).toInt().toShort()
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
                Thread.sleep(durationMs.toLong() + 120L)
            } finally {
                track.stop()
                track.release()
            }
        }.start()
    }

}
