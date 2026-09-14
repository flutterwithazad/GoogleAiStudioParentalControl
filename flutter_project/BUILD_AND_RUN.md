# Build and Run Instructions

## Prerequisites
1. **Flutter SDK**: 3.19.0 or newer
2. **Android Studio**: Hedgehog / Iguana / Jellyfish (JDK 17)
3. **Android SDK Platform**: API 34 / 35 (Android 14/15)
4. **Physical Android Device or Emulator** (Physical device recommended for real MediaProjection hardware testing)

---

## 1. Dependency Installation
Inside `flutter_project/`:
```bash
flutter pub get
```

---

## 2. Running the Parent App
To run the Parent target on your desktop or secondary Android device:
```bash
flutter run -t lib/main_parent.dart
```

---

## 3. Running the Child App (Android Target)
To run the Child target on the target Android device:
```bash
flutter run -t lib/main_child.dart -d <android-device-id>
```

---

## 4. Running Unit & Integration Tests
To execute the protocol, state machine, and signaling test suite:
```bash
flutter test test/mirroring_test.dart
```

---

## 5. Building Release APKs
For Parent App:
```bash
flutter build apk --target=lib/main_parent.dart --release
```

For Child App:
```bash
flutter build apk --target=lib/main_child.dart --release
```

---

## 6. Supabase Setup
1. Create a Supabase project at [supabase.com](https://supabase.com).
2. Open the SQL Editor and paste the contents of `supabase/schema.sql`.
3. Enable Realtime on `mirroring_sessions` and `signaling_messages`.
4. Replace the Supabase URL and anon key in `lib/services/signaling_service.dart`.
