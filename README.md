# Bluepad32 BLE Client

A cross-platform Flutter companion app for configuring and monitoring [Bluepad32](https://github.com/ricardoquesada/bluepad32) devices over Bluetooth Low Energy (BLE).

It connects to the Bluepad32 BLE GATT service (`4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`) to inspect connected gamepads and update runtime settings without reflashing firmware or opening a serial console.

## Features

* **Device Discovery:** Scans for nearby Bluepad32 peripherals advertising the Bluepad32 BLE service.
* **Live Controller Monitor:** Displays connected controllers in real time (controller model, MAC address, Vendor/Product ID, connection state) and allows disconnecting individual slots.
* **Radio & Pairing Controls:** Toggle controller scanning/pairing, BLE controller connections, and virtual child devices (such as DualShock 4 / DualSense touchpad mice).
* **Controller Button Mappings:** Switch between **Xbox**, **Nintendo Switch**, and **Custom** button/axis remapping presets.
* **Bluetooth MAC Allowlist:** Enable or disable allowlist enforcement and manage up to 4 allowed controller MAC addresses (including a one-tap shortcut to add currently connected controllers).
* **System Maintenance:** Clear stored Bluetooth pairing keys or reboot the Bluepad32 microcontroller remotely.

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

```bash
cd src
flutter analyze
flutter test
```
