package com.phonek.phonek_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

/** يستقبل نتيجة جلسة التثبيت من النظام. */
class InstallResultReceiver : BroadcastReceiver() {

    @Suppress("DEPRECATION")
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE
        )
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""

        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            // النظام يطلب تأكيد المستخدم: نفتح شاشة «تثبيت» الرسمية.
            val confirm: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
            if (confirm == null) {
                PhoneKInstaller.report(
                    context,
                    PhoneKInstaller.STATUS_CONFIRM_FAILED,
                    "missing confirmation intent"
                )
                return
            }
            try {
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(confirm)
                PhoneKInstaller.report(context, status, message)
            } catch (error: Exception) {
                PhoneKInstaller.report(
                    context,
                    PhoneKInstaller.STATUS_CONFIRM_FAILED,
                    error.javaClass.simpleName + ": " + (error.message ?: "")
                )
            }
            return
        }

        PhoneKInstaller.report(context, status, message)
    }
}
