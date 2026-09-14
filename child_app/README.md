# Child App: ScreenMirror Parental Control

The Child Application runs on the Android target device, hosting the setup wizard, device pairing, and the **Native Foreground Service** that owns screen capture.

## Key Architectural Principles

1. **Flutter UI Does NOT Own Capture**:
   - The Flutter UI is purely a control/setup interface.
   - When the user grants MediaProjection permission, control is handed to `ScreenCaptureService.kt` (a native Android Foreground Service with type `mediaProjection`).
   - The Flutter Activity may be backgrounded, destroyed, recreated, or removed from Recents while the native capture service continues uninterrupted.

2. **Persistence & Resilience**:
   - `android:stopWithTask="false"` configured in `AndroidManifest.xml`.
   - `onTaskRemoved()` in `ScreenCaptureService` handles swipe-from-recents events without stopping mirroring.
   - `OemBatteryHelper` requests battery exemption to prevent vendor task-killers on Samsung, Xiaomi, Oppo, Vivo, and OnePlus devices.

3. **Android 14+ Security & Privacy Compliance**:
   - MediaProjection consent tokens are ephemeral and single-use.
   - If the process is terminated by the OS Low Memory Killer (LMK), the service recovers into `REAUTHORIZATION_REQUIRED` state and notifies the parent. It **never** attempts unauthorized or hidden background capture.
   - Android's persistent recording indicator and ongoing notification cannot be hidden.

## Build & Execution
```bash
cd /child_app
flutter pub get
flutter run -d <child-android-device-id>
```
