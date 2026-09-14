package com.parental.screenmirror

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Helper to detect and guide users through OEM background restrictions
 * (e.g. Samsung, Xiaomi, Huawei, Oppo, Vivo) without using hacks or exploits.
 */
object OemBatteryHelper {

    private const val TAG = "OemBatteryHelper"

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }
    }

    fun getRequestIgnoreBatteryIntent(context: Context): Intent? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isIgnoringBatteryOptimizations(context)) {
                return Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
        }
        return null
    }

    fun getManufacturerName(): String = Build.MANUFACTURER.lowercase()

    fun isAggressiveOem(): Boolean {
        val mfg = getManufacturerName()
        return mfg.contains("xiaomi") ||
                mfg.contains("redmi") ||
                mfg.contains("poco") ||
                mfg.contains("samsung") ||
                mfg.contains("huawei") ||
                mfg.contains("honor") ||
                mfg.contains("oppo") ||
                mfg.contains("realme") ||
                mfg.contains("oneplus") ||
                mfg.contains("vivo")
    }

    fun getOemSpecificSettingsIntent(context: Context): Intent? {
        val mfg = getManufacturerName()
        val pkg = context.packageName

        try {
            when {
                mfg.contains("xiaomi") || mfg.contains("redmi") || mfg.contains("poco") -> {
                    val intent = Intent()
                    intent.component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (isIntentCallable(context, intent)) return intent
                }
                mfg.contains("huawei") || mfg.contains("honor") -> {
                    val intent = Intent()
                    intent.component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (isIntentCallable(context, intent)) return intent
                }
                mfg.contains("oppo") || mfg.contains("realme") -> {
                    val intent = Intent()
                    intent.component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (isIntentCallable(context, intent)) return intent
                }
                mfg.contains("vivo") -> {
                    val intent = Intent()
                    intent.component = ComponentName(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (isIntentCallable(context, intent)) return intent
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "[OEM] Failed to build OEM intent for manufacturer: $mfg", e)
        }

        // Fallback to standard App Details settings
        return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    private fun isIntentCallable(context: Context, intent: Intent): Boolean {
        val list = context.packageManager.queryIntentActivities(intent, 0)
        return list.isNotEmpty()
    }
}
