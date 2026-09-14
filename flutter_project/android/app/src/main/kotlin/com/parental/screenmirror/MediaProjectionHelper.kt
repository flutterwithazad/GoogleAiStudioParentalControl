package com.parental.screenmirror

import android.content.Context
import android.content.res.Resources
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager

/**
 * Handles resolution scaling, FPS profiles, and Android-version capability checks.
 */
object MediaProjectionHelper {

    enum class QualityProfile {
        POOR_NETWORK,
        NORMAL_NETWORK,
        GOOD_NETWORK
    }

    data class CaptureConfig(
        val width: Int,
        val height: Int,
        val dpi: Int,
        val targetFps: Int,
        val bitrateKbps: Int
    )

    fun getCaptureConfig(context: Context, profile: QualityProfile = QualityProfile.NORMAL_NETWORK): CaptureConfig {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowMetrics = windowManager.currentWindowMetrics
            val bounds = windowMetrics.bounds
            metrics.widthPixels = bounds.width()
            metrics.heightPixels = bounds.height()
            metrics.densityDpi = context.resources.configuration.densityDpi
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(metrics)
        }

        val aspectRatio = metrics.widthPixels.toFloat() / metrics.heightPixels.toFloat()

        return when (profile) {
            QualityProfile.POOR_NETWORK -> {
                val targetHeight = 480
                val targetWidth = (targetHeight * aspectRatio).toInt() / 2 * 2 // ensure even number
                CaptureConfig(
                    width = targetWidth,
                    height = targetHeight,
                    dpi = (metrics.densityDpi * 0.65f).toInt(),
                    targetFps = 15,
                    bitrateKbps = 600
                )
            }
            QualityProfile.NORMAL_NETWORK -> {
                val targetHeight = 720
                val targetWidth = (targetHeight * aspectRatio).toInt() / 2 * 2
                CaptureConfig(
                    width = targetWidth,
                    height = targetHeight,
                    dpi = metrics.densityDpi,
                    targetFps = 25,
                    bitrateKbps = 1400
                )
            }
            QualityProfile.GOOD_NETWORK -> {
                val targetHeight = 720
                val targetWidth = (targetHeight * aspectRatio).toInt() / 2 * 2
                CaptureConfig(
                    width = targetWidth,
                    height = targetHeight,
                    dpi = metrics.densityDpi,
                    targetFps = 30,
                    bitrateKbps = 2400
                )
            }
        }
    }

    /**
     * Inspects whether Android 14+ one-time token restrictions apply.
     */
    fun isAndroid14OrNewer(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
    }

    /**
     * Inspects whether runtime notification permission is required (Android 13+).
     */
    fun isNotificationPermissionRequired(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    }
}
