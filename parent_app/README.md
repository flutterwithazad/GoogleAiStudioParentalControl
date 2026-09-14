# Parent App: ScreenMirror Parental Control

The Parent Application provides the interface for remote screen monitoring.

## Features
- **Strictly Single Feature**: Remote screen mirroring. No unsolicited web filtering, app blocking, location maps, or secondary feature bloat.
- **HUD & Telemetry**: Live stream with display of current resolution, FPS, approximate bitrate, and connection state.
- **Connection Handling**: Handles CONNECTED, CONNECTING, RECONNECTING (automatic ICE restart upon network drop).
- **Controls**: "VIEW SCREEN" and "STOP MIRRORING" buttons.

## Build & Execution
```bash
cd /parent_app
flutter pub get
flutter run -d <parent-device-id>
```
