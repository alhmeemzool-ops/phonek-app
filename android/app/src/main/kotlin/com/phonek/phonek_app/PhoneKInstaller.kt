package com.phonek.phonek_app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * يثبّت ملف التحديث عبر PackageInstaller (الطريقة الرسمية في أندرويد).
 * الميزة الأساسية: النظام يرجّع لنا نتيجة حقيقية (نجاح / إلغاء / حظر / تعارض توقيع ...)
 * بدل فتح شاشة تثبيت دون أي معرفة بما حدث.
 */
object PhoneKInstaller {
    const val ACTION_STATUS = "com.phonek.phonek_app.INSTALL_STATUS"

    // رمز خاص بنا: تعذر فتح نافذة تأكيد التثبيت.
    const val STATUS_CONFIRM_FAILED = -100

    private const val PREFS = "phonek_installer"
    private const val KEY_STATUS = "status"
    private const val KEY_MESSAGE = "message"

    // قناة Flutter لإرسال النتيجة للتطبيق مباشرة (تُضبط في MainActivity).
    @Volatile
    var channel: MethodChannel? = null

    @Throws(Exception::class)
    fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller

        // تنظيف أي جلسات قديمة عالقة من محاولات سابقة.
        for (info in installer.mySessions) {
            try {
                installer.abandonSession(info.sessionId)
            } catch (ignored: Exception) {
            }
        }
        clearResult(context)

        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        params.setAppPackageName(context.packageName)
        params.setSize(apk.length())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // أندرويد 12+: إن توفرت الشروط يُحدَّث التطبيق دون ضغطة تأكيد،
            // وإلا يطلب النظام التأكيد عادةً (نتعامل معه في المستقبِل).
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }

        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        try {
            FileInputStream(apk).use { input ->
                session.openWrite("phonek-update.apk", 0, apk.length()).use { output ->
                    input.copyTo(output, 64 * 1024)
                    session.fsync(output)
                }
            }

            val intent = Intent(context, InstallResultReceiver::class.java)
            intent.action = ACTION_STATUS
            intent.setPackage(context.packageName)

            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // النظام يضيف نتيجة التثبيت داخل الـ Intent، لذلك يجب أن يكون mutable.
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            session.commit(pending.intentSender)
        } catch (error: Exception) {
            try {
                session.abandon()
            } catch (ignored: Exception) {
            }
            throw error
        } finally {
            session.close()
        }
    }

    /** يحفظ النتيجة (للاسترجاع عند عودة التطبيق) ويبلّغ Flutter فوراً إن كان متاحاً. */
    fun report(context: Context, status: Int, message: String) {
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_STATUS, status)
                .putString(KEY_MESSAGE, message)
                .apply()
        }
        channel?.invokeMethod(
            "installStatus",
            mapOf("status" to status, "message" to message)
        )
    }

    fun lastResult(context: Context): Map<String, Any>? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_STATUS)) return null
        return mapOf(
            "status" to prefs.getInt(KEY_STATUS, PackageInstaller.STATUS_FAILURE),
            "message" to (prefs.getString(KEY_MESSAGE, "") ?: "")
        )
    }

    fun clearResult(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
