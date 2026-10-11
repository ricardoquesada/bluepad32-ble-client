# Bluepad32 BLE Client

A cross-platform Flutter companion app for configuring and monitoring [Bluepad32](https://github.com/ricardoquesada/bluepad32) devices over Bluetooth Low Energy (BLE).

It connects to the Bluepad32 BLE GATT service (`4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`) to inspect connected gamepads and update runtime settings without reflashing firmware or opening a serial console.

## Features

* **Device Discovery & Custom Service Identity (`AC0D`):** Scans for nearby Bluepad32 peripherals advertising the Bluepad32 BLE service, prioritizing live `ADV_IND` + `SCAN_RSP` advertising names over stale OS-cached device names and supporting inline service renaming (`1–29` UTF-8 bytes) from the dashboard.
* **Session Password Authentication (`AC0E`):** Supports password-protected Bluepad32 peripherals (`1–31` UTF-8 bytes), prompting to unlock the BLE session before reading or modifying protected controller telemetry and settings.
* **Live Controller Monitor (`AC05`):** Displays connected controllers in real time (controller model, MAC address, Vendor/Product ID, connection state) and allows disconnecting individual slots (`AC0A`).
* **Radio & Pairing Controls (`AC03`, `AC04`, `AC09`):** Toggle controller scanning/pairing, BLE controller connections, and virtual child devices (such as DualShock 4 / DualSense touchpad mice).
* **Controller Button Mappings & Custom Remapping Matrix (`AC06`, `AC0F`):** Switch between **Xbox**, **Nintendo Switch**, and **Custom** presets (`AC06`, accepting 1-byte preset selection or 29-byte atomic custom-mapping writes), or open the interactive **Custom Remapping Matrix** editor to inspect and customize all 28 fields of `uni_gamepad_mappings_t` (`AC0F`: 4 D-pad directions, 10 face/shoulder/trigger/thumb buttons, 4 misc buttons, 4 analog stick axes, 4 axis-inversion switches, and 2 analog pedals/triggers).
* **Bluetooth MAC Allowlist (`AC07`, `AC08`):** Enable or disable allowlist enforcement and manage up to 4 allowed controller MAC addresses (including a one-tap shortcut to add currently connected controllers).
* **System Maintenance (`AC0B`, `AC0C`):** Clear stored Bluetooth pairing keys or reboot the Bluepad32 microcontroller remotely.

## Supported Platforms

Built with Flutter and [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus):

* **Android** (API 21+)
* **iOS** (iOS 12+)
* **macOS** (macOS 10.14+, Universal `x86_64` + `arm64`)
* **Linux** (`x64` and `arm64`, requires `bluez`)
* **Windows** (Windows 10+ `x64` via WinRT BLE)
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

# Run on Windows desktop
flutter run -d windows

# Run on Chrome (Web Bluetooth)
flutter run -d chrome
```

### Build & Deploy Release Binaries

* **Android (APK / App Bundle):**

    ```bash
    flutter build apk --release
    flutter build appbundle --release
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
    open build/macos/Build/Products/Release/Bluepad32.app
    ```

* **Linux:**

    ```bash
    flutter build linux --release
    ./build/linux/x64/release/bundle/bluepad32
    ```

* **Windows:**

    ```bash
    flutter build windows --release
    .\build\windows\x64\runner\Release\bluepad32.exe
    ```

* **Web:**

    ```bash
    flutter build web --release
    ```

## Creating a Release

Releases are built and published automatically by [`.github/workflows/release.yml`](.github/workflows/release.yml) whenever a `v*` tag is pushed to GitHub:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The workflow extracts the semantic version from the tag (`v1.2.0` -> `--build-name=1.2.0`) and derives a monotonically increasing integer build number (`--build-number=${{ github.run_number }}`, or `N` if tagged with an explicit `+N` suffix such as `v1.2.0+42`).

### Published Release Assets

| Platform | Release Asset | Notes |
| :--- | :--- | :--- |
| **Android (APK)** | `bluepad32-android.apk` | Direct sideloadable Android package |
| **Android (App Bundle)** | `bluepad32-android.aab` | Google Play Console upload bundle |
| **iOS** | `bluepad32-ios.ipa` | App Store Connect (`Transporter`) / sideload IPA archive |
| **macOS (Universal)** | `bluepad32-macos-universal.zip` | Universal (`x86_64` + `arm64`) `Bluepad32.app`, signed (`Developer ID Application`), notarized, and stapled |
| **Linux (x64)** | `bluepad32-linux-amd64.tar.gz` | GTK desktop bundle (`bluepad32`) for `x86_64` |
| **Linux (ARM64)** | `bluepad32-linux-arm64.tar.gz` | GTK desktop bundle (`bluepad32`) for `aarch64` |
| **Windows (x64)** | `bluepad32-windows-amd64.zip` | Win32/WinRT desktop bundle (`bluepad32.exe`) for `x86_64` |
| **Web** | `bluepad32-web.tar.gz` | Static Web Bluetooth PWA bundle |

### GitHub Actions Secrets for Code Signing & Notarization

* **macOS Code Signing & Apple Notary Service (Required for macOS release job):**
  * `MACOS_CERTIFICATE`: Base64-encoded `Developer ID Application` `.p12` certificate.
  * `MACOS_CERTIFICATE_PWD`: Password for the macOS `.p12` certificate.
  * `KEYCHAIN_PWD`: Temporary CI keychain password.
  * `APPLE_ID`: Apple ID email address for `xcrun notarytool`.
  * `APPLE_PASSWORD`: App-specific password for `xcrun notarytool`.
  * `APPLE_TEAM_ID`: 10-character Apple Developer Team ID.
* **Android Release Keystore Signing (Optional; falls back to debug signing if omitted):**
  * `ANDROID_KEYSTORE_BASE64`: Base64-encoded Android upload keystore (`.jks` or `.keystore`).
  * `ANDROID_STORE_PASSWORD`: Keystore password.
  * `ANDROID_KEY_ALIAS`: Key alias inside the keystore.
  * `ANDROID_KEY_PASSWORD`: Private key password.
* **iOS App Store Distribution Signing (Optional; falls back to unsigned `.ipa` if omitted):**
  * `IOS_CERTIFICATE`: Base64-encoded `Apple Distribution` `.p12` certificate.
  * `IOS_CERTIFICATE_PWD`: Password for `IOS_CERTIFICATE`.
  * `IOS_PROVISION_PROFILE`: Base64-encoded App Store `.mobileprovision` profile for `moe.retro.bluepad32`.
  * `KEYCHAIN_PWD`: Temporary CI keychain password (shared with macOS).
  * `APPLE_TEAM_ID`: 10-character Apple Developer Team ID (shared with macOS).

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
