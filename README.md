# Bluepad32 BLE Client

A cross-platform Flutter companion app for configuring and monitoring [Bluepad32](https://github.com/ricardoquesada/bluepad32) devices over Bluetooth Low Energy (BLE).

It connects to the Bluepad32 BLE GATT service (`4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`) to inspect connected gamepads and update runtime settings without reflashing firmware or opening a serial console.

## Features

* **Device Discovery & Custom Service Identity (`AC0D`):** Scans for nearby Bluepad32 peripherals advertising the Bluepad32 BLE service, prioritizing live `ADV_IND` + `SCAN_RSP` advertising names over stale OS-cached device names and supporting inline service renaming (`1–29` UTF-8 bytes) from the dashboard.
* **Session Password Authentication (`AC0E`):** Supports password-protected Bluepad32 peripherals (`1–31` UTF-8 bytes), prompting to unlock the BLE session before reading or modifying protected controller telemetry and settings.
* **Live Controller Monitor (`AC05`):** Displays connected controllers in real time (controller model, MAC address, Vendor/Product ID, connection state) and allows disconnecting individual slots (`AC0A`).
* **Radio & Pairing Controls (`AC03`, `AC04`, `AC09`):** Toggle controller scanning/pairing, BLE controller connections, and virtual child devices (such as DualShock 4 / DualSense touchpad mice).
* **Controller Button Mappings (`AC06`):** Switch between **Xbox**, **Nintendo Switch**, and **Custom** button/axis remapping presets.
* **Bluetooth MAC Allowlist (`AC07`, `AC08`):** Enable or disable allowlist enforcement and manage up to 4 allowed controller MAC addresses (including a one-tap shortcut to add currently connected controllers).
* **System Maintenance (`AC0B`, `AC0C`):** Clear stored Bluetooth pairing keys or reboot the Bluepad32 microcontroller remotely.

## Supported Platforms

Built with Flutter and [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus):

* **Android** (API 21+)
* **iOS** (iOS 12+)
* **macOS** (macOS 10.14+)
* **Linux** (requires `bluez`)
* **Web** (experimental, requires a browser with Web Bluetooth support such as Chrome or Edge)

## Building and Deploying

All Flutter project files are located in the `src/` directory:

```bash
cd src
flutter pub get
```

### Run in Development Mode

List connected targets with `flutter devices`, then run on your target device:

```bash
# Run on a connected Android or iOS device
flutter run -d <device_id>

# Run on macOS desktop
flutter run -d macos

# Run on Linux desktop
flutter run -d linux

# Run on Chrome (Web Bluetooth)
flutter run -d chrome
```

### Build & Deploy Release Binaries

* **Android (APK / App Bundle):**

    ```bash
    flutter build apk --release
    flutter install -d <android_device_id>
    ```

* **iOS:**

    ```bash
    flutter build ios --release
    flutter install -d <ios_device_id>
    ```

    *(Requires Xcode and a valid Apple Developer signing team configured in `src/ios/Runner.xcworkspace`.)*

* **macOS:**

    ```bash
    flutter build macos --release
    open build/macos/Build/Products/Release/flutter_blue_plus_example.app
    ```

* **Linux:**

    ```bash
    flutter build linux --release
    ./build/linux/x64/release/bundle/flutter_blue_plus_example
    ```

* **Web:**

    ```bash
    flutter build web --release
    ```

### Running Tests & Static Analysis

Run static analysis and the automated unit and widget test suite from the `src/` directory:

```bash
cd src

# Run Dart static analysis and lint checks
flutter analyze

# Run the full unit and widget test suite
flutter test

# Run individual test suites
flutter test test/bluepad32_models_test.dart     # Domain models, binary serialization, and Bluepad32Client GATT service layer
flutter test test/bluepad32_dashboard_test.dart  # DeviceScreen and Material 3 configuration dashboard cards
flutter test test/scan_and_tiles_test.dart       # BLE discovery screen (ScanScreen) and peripheral tiles (ScanResultTile, SystemDeviceTile)
flutter test test/utils_test.dart                # Stream re-emission (StreamControllerReemit), Snackbar, and BluetoothDevice Extra utilities
flutter test test/widget_test.dart               # App routing (FlutterBlueApp), BluetoothOffScreen, and adapter state observer

# Generate LCOV line coverage report (outputs src/coverage/lcov.info)
flutter test --coverage
```
