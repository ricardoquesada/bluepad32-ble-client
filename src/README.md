# Bluepad32 BLE Client (`src/`)

This directory contains the Flutter application source code, unit/widget test suites, and native platform runners (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`) for the **Bluepad32 BLE Client** (`moe.retro.bluepad32`).

For complete feature documentation, platform build instructions, and automated release workflow details, see the root [README.md](../README.md).

## Quick Developer Reference

```bash
# Install Dart/Flutter dependencies
flutter pub get

# Regenerate multi-platform launcher icons from assets/icon/icon.png
dart run flutter_launcher_icons

# Run static analysis (zero warnings/infos policy)
flutter analyze --fatal-infos --fatal-warnings

# Run the unit and widget test suite
flutter test --reporter expanded
```
