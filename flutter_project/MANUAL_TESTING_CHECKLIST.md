# Manual Android Testing Checklist: ScreenMirror Parental Control

This document provides testing procedures across Android API levels (Android 12 to Android 15+) for the ScreenMirror MediaProjection Foreground Service and WebRTC pipeline.

---

## 1. Matrix by Android OS Version

### Android 12 (API 31 / 32)
- [ ] **Foreground Service Start:** Verify `ScreenCaptureService` starts without `ForegroundServiceStartNotAllowedException` when activity is in foreground.
- [ ] **Notification Presentation:** Ensure default ongoing notification is shown in status bar.
- [ ] **Lock Screen Behavior:** Ensure capture does not crash if device is locked during active session.

### Android 13 (API 33)
- [ ] **Runtime Notification Permission:** Verify setup wizard prompts for `POST_NOTIFICATIONS`.
- [ ] **Denial Recovery:** If child denies notification permission, verify wizard halts and explains why the mandatory foreground notification cannot be created.
- [ ] **Cast Indicator:** Confirm the system cast icon appears in the quick settings / status bar.

### Android 14 (API 34)
- [ ] **Foreground Service Type:** Verify manifest contains `android:foregroundServiceType="mediaProjection"` and service starts with `ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION`.
- [ ] **One-Time Consent Token:** Ensure app does NOT crash with `SecurityException` upon starting capture. Verify each new session re-requests consent if token is expired.
- [ ] **Background Launch Restriction:** Confirm that starting capture service directly from background without a foreground activity or full-screen intent throws expected Android 14 restriction, handled gracefully by prompting user to foreground the app.

### Android 15+ (API 35+)
- [ ] **Single-Window vs Full-Screen Capture:** Handle Android 15 user choice dialog (sharing a single app window vs entire display).
- [ ] **Privacy Chip:** Verify native persistent screen capture chip in top status bar works alongside app notification.

---

## 2. Core Functional & Lifecycle Test Cases

| Test Case | Steps | Expected Result | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **TC-01: First-Time Setup Wizard** | Launch Child App on fresh install. Follow permissions 1-by-1. | Each permission requested only when explained. No unrelated permissions asked. | [ ] |
| **TC-02: Device Pairing Flow** | Child generates QR & 6-digit code. Parent inputs code. | Secure link established. Child status updates to `READY`. | [ ] |
| **TC-03: MediaProjection Consent Granted** | Parent taps "View Screen". Child accepts system prompt. | Service starts with notification. Parent displays live screen stream within 1.5s. | [ ] |
| **TC-04: MediaProjection Consent Denied** | Parent taps "View Screen". Child cancels system dialog. | Parent receives `Child declined session`. Child state reverts to `READY`. No crash. | [ ] |
| **TC-05: App in Background** | Minimize Child app to home screen during active mirror. | Stream continues without stutter. Foreground service notification remains pinned. | [ ] |
| **TC-06: Device Screen Locked** | Lock child device screen with power button. | WebRTC stream pauses or sends blank frame. Resumes immediately upon unlock. | [ ] |
| **TC-07: Network Switch (Wi-Fi → Mobile Data)** | Disconnect Wi-Fi while streaming. | WebRTC triggers ICE restart. Reconnection state shown, recovers in < 2 seconds. | [ ] |
| **TC-08: Network Switch (Mobile Data → Wi-Fi)** | Re-enable Wi-Fi during active stream. | WebRTC seamlessly transitions to faster route, adaptive bitrate scales up. | [ ] |
| **TC-09: Child Terminates Session** | Child taps "Stop Mirroring" in app or in Android Notification. | MediaProjection, VirtualDisplay, and WebRTC tracks closed. Parent HUD shows `Ended`. | [ ] |
| **TC-10: Parent Terminates Session** | Parent taps "Stop Mirroring". | Child receives `session_end` signaling. Foreground service halts immediately. | [ ] |
| **TC-11: System Revocation** | User revokes screen recording via Android status bar chip. | `MediaProjection.Callback.onStop()` triggers. Service cleans up gracefully. | [ ] |
| **TC-12: Process Death / Kill** | Force stop Child app from Android Settings. | Signaling detects disconnection. Parent UI displays `Disconnected` without freeze. | [ ] |
| **TC-13: Child Offline** | Disconnect Child device from internet. Parent taps "View Screen". | Parent UI displays `Device Offline` with disabled or informative action. | [ ] |
