package com.parental.screenmirror

import android.content.Context
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.projection.MediaProjection
import android.util.Log
import android.view.Surface
import org.webrtc.*

/**
 * Concrete WebRTC VideoCapturer that links Android MediaProjection to WebRTC VideoTrack.
 *
 * Execution Pipeline:
 * MediaProjection
 *   ↓
 * VirtualDisplay (created on SurfaceTextureHelper's Surface)
 *   ↓
 * SurfaceTextureHelper (OpenGL ES Texture receiver)
 *   ↓
 * CapturerObserver (Frame delivery to WebRTC C++ native engine)
 *   ↓
 * WebRTC VideoSource / VideoTrack
 *   ↓
 * PeerConnection.addTrack(videoTrack)
 */
class WebRTCSurfaceCapturer(
    private val mediaProjection: MediaProjection,
    private val width: Int = 1280,
    private val height: Int = 720,
    private val dpi: Int = 320
) : VideoCapturer {

    companion object {
        private const val TAG = "WebRTCSurfaceCapturer"
    }

    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    private var capturerObserver: CapturerObserver? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var surface: Surface? = null
    private var isDisposed = false

    override fun initialize(
        surfaceTextureHelper: SurfaceTextureHelper?,
        applicationContext: Context?,
        capturerObserver: CapturerObserver?
    ) {
        this.surfaceTextureHelper = surfaceTextureHelper
        this.capturerObserver = capturerObserver

        if (surfaceTextureHelper == null) {
            Log.e(TAG, "[WEBRTC] SurfaceTextureHelper is null during capturer initialization")
            return
        }

        surfaceTextureHelper.setTextureSize(width, height)
        this.surface = Surface(surfaceTextureHelper.surfaceTexture)
        Log.i(TAG, "[WEBRTC] Initialized SurfaceTextureHelper and created native output Surface: $surface")
    }

    override fun startCapture(width: Int, height: Int, framerate: Int) {
        if (isDisposed) return
        val currentSurface = surface
        if (currentSurface == null || !currentSurface.isValid) {
            Log.e(TAG, "[WEBRTC] Cannot startCapture: Surface is invalid or null")
            return
        }

        Log.i(TAG, "[WEBRTC] Creating VirtualDisplay binding MediaProjection to WebRTC Surface (${width}x${height} @ ${framerate}fps)")
        virtualDisplay = mediaProjection.createVirtualDisplay(
            "WebRTCScreenMirrorDisplay",
            width,
            height,
            dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            currentSurface,
            null,
            null
        )

        capturerObserver?.onCapturerStarted(true)
        Log.i(TAG, "[WEBRTC] VirtualDisplay active. Frames flowing directly from Android OS to WebRTC encoder.")
    }

    override fun stopCapture() {
        Log.i(TAG, "[WEBRTC] Stopping WebRTC screen capturer and releasing VirtualDisplay")
        try {
            virtualDisplay?.release()
            virtualDisplay = null
        } catch (e: Exception) {
            Log.e(TAG, "[WEBRTC] Error releasing VirtualDisplay", e)
        }
        capturerObserver?.onCapturerStopped()
    }

    override fun changeCaptureFormat(width: Int, height: Int, framerate: Int) {
        Log.i(TAG, "[WEBRTC] Changing capture format to ${width}x${height} @ ${framerate}fps")
        surfaceTextureHelper?.setTextureSize(width, height)
        virtualDisplay?.resize(width, height, dpi)
    }

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        Log.i(TAG, "[WEBRTC] Disposing WebRTCSurfaceCapturer resources")
        stopCapture()
        surface?.release()
        surface = null
        surfaceTextureHelper = null
        capturerObserver = null
    }

    override fun isScreencast(): Boolean = true

    fun getSurface(): Surface? = surface
}
