# ScreenMirror: Android-Only Flutter Parental Control Remote Screen Mirroring
## Production Architecture & Process Lifecycle Resilience Guide

---

## 1. Native-Owned Architecture

The Flutter Activity/UI is strictly a control and setup interface. **The native Android layer owns the entire active screen-mirroring lifecycle.**

```
Parent Device (Flutter Viewer)
       │
       │ WebRTC SRTP/DTLS Video
       ▼
Child Device (Android)
┌──────────────────────────────────────────────────────────────────┐
│ [Flutter Process / UI Layer]                                     │
│  - Child Setup Wizard & Pairing Configuration                   │
│  - Child Dashboard (Status, battery optimization exemption)      │
│  (May be foregrounded, backgrounded, destroyed, or swiped away)  │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Platform Channels (Method & Event)
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ [Native Android Layer]                                           │
│  1. NativeCaptureManager (Singleton State Machine)               │
│  2. ScreenCaptureService (Foreground Service, START_STICKY)      │
│     - stopWithTask="false" in AndroidManifest                    │
│     - onTaskRemoved() intercepted: active capture maintained     │
│     - foregroundServiceType="mediaProjection"                    │
│     - NotificationChannel + Non-dismissible Notification         │
│  3. MediaProjection & VirtualDisplay                             │
│     - Tied to WebRTC SurfaceTexture                              │
│     - Managed by MediaProjection.Callback                        │
│  4. WebRTC Native Pipeline                                       │
│     - Hardware H.264 / VP8 encoder                               │
│     - Dedicated PeerConnection and ICE handler                   │
│  5. Background Signaling & Re-launch Components                  │
│     - NativeSignalingReceiver (Handles parent request when closed)│
│     - MediaProjectionConsentActivity (Translucent consent prompt)│
│     - BootReceiver (Restores pairing & presence on reboot)       │
│     - NativeStorageHelper (Safe SharedPreferences persistence)   │
└──────────────────────────────────────────────────────────────────┘
```

Once mirroring is active, the Flutter Activity may be:
- Backgrounded (Home button)
- Suspended while user uses other apps (YouTube, Games, Chrome)
- Recreated (orientation change, theme change)
- Swiped from Android Recents (`onTaskRemoved`)

In all these scenarios, **the native capture service and WebRTC stream continue independently.**

---

## 2. Decoupled Native State Machine (`NativeSessionState`)

The state machine lives in native Kotlin (`NativeSessionState.kt`) and is synchronized with Flutter via EventChannel:

```
[IDLE]
  │ (Device paired)
  ▼
[READY] ◄────────────────────────┐
  │ (Parent requests session)    │ (Clean stop / teardown)
  ▼                              │
[STARTING]                       │
  │ (Consent granted)            │
  ▼                              │
[CAPTURING]                      │
  │ (Surface attached)           │
  ▼                              │
[CONNECTING]                     │
  │ (WebRTC connected)           │
  ▼                              │
[STREAMING] ─────────────────────┼─────────┐
  │                              │         │
  │ (Wi-Fi ↔ Cellular handoff)   │         │ (User/System stops)
  ▼                              │         │
[RECONNECTING] ──────────────────┘         │
  │ (ICE Restart OK -> STREAMING)          │
  │                                        ▼
  │ (System revokes / token killed)   [STOPPING]
  ▼                                        │
[REVOKED] ────────────────────────────────►[STOPPED]
  │
  │ (Android OS kills service, restarted via START_STICKY)
  ▼
[REAUTHORIZATION_REQUIRED]
```

---

## 3. Handling Swipe Away From Recents (`onTaskRemoved`)

When a user swipes the Child app from Recents:
1. Android OS terminates the Flutter Activity and invokes `Service.onTaskRemoved(Intent rootIntent)`.
2. Standard Android services call `stopSelf()`, which would kill mirroring.
3. In `ScreenCaptureService`:
   ```kotlin
   override fun onTaskRemoved(rootIntent: Intent?) {
       super.onTaskRemoved(rootIntent)
       if (isRunning && mediaProjection != null) {
           Log.i(TAG, "Child app swiped from Recents: MAINTAINING active foreground capture")
           // DO NOT CALL stopSelf()
       } else {
           stopSelf()
       }
   }
   ```
4. In `AndroidManifest.xml`, the service declares `android:stopWithTask="false"`:
   ```xml
   <service
       android:name=".ScreenCaptureService"
       android:enabled="true"
       android:exported="false"
       android:stopWithTask="false"
       android:foregroundServiceType="mediaProjection" />
   ```

---

## 4. Handling Parent Request When Flutter UI Is Closed

Under Android 10+ background activity start restrictions, apps cannot silently launch activities from the background.

**Legitimate Android Compliance Flow:**
1. Parent sends a `session_request` via the signaling channel.
2. `NativeSignalingReceiver` intercepts the request:
   - Validates that `senderId == pairedParentId` using `NativeStorageHelper`.
   - Creates a high-priority Android notification on `screen_mirror_requests_channel`.
   - Attaches a `PendingIntent` with `MediaProjectionConsentActivity`.
3. Child sees high-priority notification: *"Azad requested to view screen. Tap to authorize."*
4. Child taps notification -> `MediaProjectionConsentActivity` launches system `createScreenCaptureIntent()` dialog.
5. User taps "Start now" -> `ScreenCaptureService` starts with `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`.

---

## 5. MediaProjection Token Lifecycle (Android 14 & 15 Rules)

- **One-Time Token**: Android 14+ strictly treats `MediaProjection` tokens as single-use.
- **No Indefinite Caching**: Storing the `Intent` data in SharedPreferences and reusing it later will throw `SecurityException`.
- **Must Start Foreground First**: Calling `MediaProjectionManager.getMediaProjection()` before `startForeground()` with `FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION` will throw an immediate `SecurityException`.
- **System Indicator**: Android 14+ renders a mandatory green status bar privacy chip and cast tile. If the child taps this chip and stops capture, `MediaProjection.Callback.onStop()` fires, and the app must release all resources cleanly.

---

## 6. Process Death Categorization & Recovery Matrix

| Scenario | State Before | Android Event | What Survives | Native Recovery Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **A. App Swiped from Recents** | STREAMING | Activity destroyed, `onTaskRemoved()` | FGS, VirtualDisplay, WebRTC, MediaProjection | `onTaskRemoved()` does NOT call `stopSelf()`. Stream continues uninterrupted. |
| **B. Home / App Switch** | STREAMING | Activity `onStop()`, backgrounded | FGS, VirtualDisplay, WebRTC, MediaProjection | Native FGS owns capture; continues drawing foreign app screens. |
| **C. Low Memory Killer (LMK)** | STREAMING | Process SIGKILL under high RAM pressure | Nothing in memory | OS restarts service via `START_STICKY`. Service detects missing token, enters `REAUTHORIZATION_REQUIRED`. |
| **D. Device Reboot** | READY | Power off / Boot | SharedPreferences config | `BootReceiver` runs on `BOOT_COMPLETED`, restores presence to `READY`. Never pre-captures. |
| **E. Wi-Fi / Cell Switch** | STREAMING | Default network route change | FGS, VirtualDisplay, MediaProjection | `ConnectivityManager.NetworkCallback` detects handoff. WebRTC `restartIce()` switches candidate pair. |
| **F. User Revokes via Chip** | STREAMING | Taps status chip / cast tile | Service process | `MediaProjection.Callback.onStop()` fires. Clean teardown, parent notified `REVOKED`. |
| **G. Notification Stop** | STREAMING | Taps "Stop Sharing" on FGS notification | Service process | `onStartCommand` receives `ACTION_STOP`. Clean teardown, state resets to `READY`. |
| **H. Remote Parent Stop** | STREAMING | Parent sends `session_end` | Service process | Child signaling receives `session_end`. FGS stops, returns to `READY`. |

---

## 7. Battery Optimization & OEM Restrictions

Aggressive OEM power management systems (Xiaomi MIUI/HyperOS, Samsung One UI, Huawei EMUI, Oppo ColorOS) kill background processes aggressively.

**Legitimate Android Solution:**
- App requests battery optimization exemption via `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- `OemBatteryHelper` detects manufacturer (`Build.MANUFACTURER`) and guides parents/children to device-specific autostart and background running permissions with explicit intents.
- No hidden watchdog processes, foreground service abuse, or broadcast bouncing hacks.

---

## 8. Honest Operational Boundaries

### Fully Supported by Native Architecture
- Remote screen mirroring when Child app is in foreground or background.
- Continued mirroring when child navigates to Home or uses other applications.
- Continued mirroring when child app is swiped away from Recents.
- Dynamic network handoff (Wi-Fi ↔ Cellular) via WebRTC ICE restarts.
- Immediate, crash-free recovery on user denial or status-bar revocation.

### Possibly Recoverable with User Interaction
- Process kill by Android Low-Memory Killer: Service auto-restarts via `START_STICKY` and notifies user to re-authorize (`REAUTHORIZATION_REQUIRED`).
- Parent requests while app is closed: Delivered via high-priority notification with full-screen intent.

### Not Guaranteed by Android Security Architecture (Hacks Prohibited)
- Capturing screens displaying `FLAG_SECURE` (banking apps, passwords, DRM video): Android compositor automatically blacks out these windows.
- Capturing screen across device reboot without user consent: Android OS prohibits silent MediaProjection initiation.

---

## 9. 15-Point Test Matrix

| # | Test Scenario | Trigger | Expected Outcome | Actual Native Handling | Android Limitation |
|---|---|---|---|---|---|
| **1** | Flutter Child Foreground Request | Parent taps "View Screen" | System consent dialog displays; stream starts | `MainActivity` launches `createScreenCaptureIntent()`; forwards token to `ScreenCaptureService` | None |
| **2** | Flutter Child Background Request | Parent taps "View Screen" | High-priority notification displayed; tap opens consent | `NativeSignalingReceiver` displays notification with `PendingIntent` to `MediaProjectionConsentActivity` | Android 10+ background activity launch restrictions |
| **3** | Home Button Navigation | Child navigates to Home launcher | Screen capture continues uninterrupted | `ScreenCaptureService` runs independently of Activity; VirtualDisplay continues producing frames | None |
| **4** | Foreign App Usage | Child launches Chrome or YouTube | Chrome/YouTube screen mirrored to parent | WebRTC video track receives composite display frames from VirtualDisplay | `FLAG_SECURE` content blacked out |
| **5** | Swipe From Recents | Child swipes app card from Recents | FGS survives; mirroring continues | `ScreenCaptureService.onTaskRemoved()` intercepted; `stopSelf()` skipped; `stopWithTask="false"` | Aggressive OEM task clearers may require battery exemption |
| **6** | Display Sleep / Screen Lock | Power button pressed | Stream pauses frames cleanly; resumes on wake | `DisplayManager` stops generating dirty buffers; WebRTC keepalive pings sustained | No display buffers generated while screen off |
| **7** | Device Reboot | Device restarted | Presence restored to `READY` on parent dashboard | `BootReceiver` executes on `BOOT_COMPLETED`; loads pairing config; sets presence = `READY` | Direct-boot mode until first unlock; MediaProjection token cannot be stored |
| **8** | Wi-Fi ↔ Cellular Handoff | Wi-Fi disconnects | Stream recovers in <1.5s via ICE restart | `ConnectivityManager.NetworkCallback` triggers `WebRTCBridge.notifyNetworkChange()`; new SDP offer sent | Brief 0.5s-1.5s packet transit pause during socket switch |
| **9** | System Status Chip Revoke | Child taps green cast chip in status bar | Service tears down cleanly; parent notified | `MediaProjection.Callback.onStop()` fires; VirtualDisplay released; state = `REVOKED` | Android 14+ user privilege |
| **10** | Parent Initiated Stop | Parent taps "Stop Mirroring" | Both devices return to `READY` state cleanly | Signaling sends `session_end`; Child `stopCapture()` releases all resources | None |
| **11** | Child Notification Stop | Child taps "Stop Sharing" on notification | Mirroring halts immediately | `ScreenCaptureService.onStartCommand` receives `ACTION_STOP`; shuts down FGS and notifies Parent | None |
| **12** | Low Memory Killer (LMK) | Device under severe RAM starvation | Service restarts via `START_STICKY`; asks for re-auth | `ScreenCaptureService` restarted with null intent; enters `REAUTHORIZATION_REQUIRED` | Tokens are ephemeral on Android 14+ |
| **13** | Unpaired Rogue Request | Unpaired device sends session_request | Request dropped; no dialog shown | `NativeSignalingReceiver` verifies `senderId == getPairedParentId()`; drops invalid packet | None |
| **14** | Child Denies Consent Prompt | Child taps "Cancel" on system dialog | Parent notified; no app crash | `onActivityResult` receives `RESULT_CANCELED`; state reset to `READY`; notification sent to Parent | User right of refusal |
| **15** | Poor Network Adaptation | RTT > 300ms, packet loss > 5% | Bitrate drops to 600 kbps, 480p @ 15fps | WebRTC RTP receiver stats trigger dynamic encoder bitrate and framerate reduction | Physical cellular radio limits |
