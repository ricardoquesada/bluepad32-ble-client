// GATT UUID registry for the Bluepad32 BLE configuration and telemetry service.

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// GATT Service and Characteristic UUIDs exposed by Bluepad32 firmware
/// (`src/components/bluepad32/bt/uni_bt_service.gatt`).
///
/// The primary service uses base UUID `4627c4a4-ac00-46b9-b688-afc5c1bf7f63`
/// with 14 characteristics numbered contiguously from `AC01` through `AC0E`:
/// - `AC05` ([connectedDevices]) unifies both on-demand full-table reads and
///   reactive change notifications over a single GATT handle.
/// - `AC0D` ([serviceName]) exposes the custom UTF-8 BLE service name (`1..29`
///   bytes, fitting inside the 31-byte `SCAN_RSP` PDU alongside the 8-byte
///   shortened/complete name in `ADV_IND`).
/// - `AC0E` ([serviceAuth]) enforces per-connection session authentication
///   (`0 = open`, `1 = password required`, `2 = authenticated`), gating reads
///   to `AC02`–`AC09`, writes to `AC03`–`AC0D`, and `AC05` CCCD subscriptions.
abstract final class Bluepad32Uuids {
  /// Primary Bluepad32 GATT Service UUID (`4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`).
  static final Guid service = Guid('4627c4a4-ac00-46b9-b688-afc5c1bf7f63');

  /// `AC01` (`READ | DYNAMIC`): UTF-8 firmware version string (e.g., `"v4.2.0"`).
  static final Guid version = Guid('4627c4a4-ac01-46b9-b688-afc5c1bf7f63');

  /// `AC02` (`READ | DYNAMIC`): Maximum supported concurrent connections (`uint8_t`).
  static final Guid maxConnections = Guid('4627c4a4-ac02-46b9-b688-afc5c1bf7f63');

  /// `AC03` (`READ | WRITE | DYNAMIC`): Whether BLE controller connections are enabled (`uint8_t`, 0 or 1).
  static final Guid bleEnabled = Guid('4627c4a4-ac03-46b9-b688-afc5c1bf7f63');

  /// `AC04` (`READ | WRITE | DYNAMIC`): Whether controller inquiry/scanning is active (`uint8_t`, 0 or 1).
  static final Guid scanning = Guid('4627c4a4-ac04-46b9-b688-afc5c1bf7f63');

  /// `AC05` (`READ | NOTIFY | DYNAMIC`): Connected controller table (`N * 16`-byte `compact_device_t` records).
  static final Guid connectedDevices = Guid('4627c4a4-ac05-46b9-b688-afc5c1bf7f63');

  /// `AC06` (`READ | WRITE | DYNAMIC`): Controller button mapping layout (`uint8_t`: 0=Xbox, 1=Switch, 2=Custom).
  static final Guid mappings = Guid('4627c4a4-ac06-46b9-b688-afc5c1bf7f63');

  /// `AC07` (`READ | WRITE | DYNAMIC`): Whether the Bluetooth MAC allowlist is enforced (`uint8_t`, 0 or 1).
  static final Guid allowlistEnabled = Guid('4627c4a4-ac07-46b9-b688-afc5c1bf7f63');

  /// `AC08` (`READ | WRITE | DYNAMIC`): Concatenated 6-byte `bd_addr_t` allowlist entries (`K * 6` bytes).
  static final Guid allowlistAddresses = Guid('4627c4a4-ac08-46b9-b688-afc5c1bf7f63');

  /// `AC09` (`READ | WRITE | DYNAMIC`): Whether virtual child devices (e.g., touchpad mouse) are enabled (`uint8_t`).
  static final Guid virtualDeviceEnabled = Guid('4627c4a4-ac09-46b9-b688-afc5c1bf7f63');

  /// Alias for [virtualDeviceEnabled].
  static final Guid virtualDevicesEnabled = virtualDeviceEnabled;

  /// `AC0A` (`WRITE | DYNAMIC`): Disconnects and deletes the controller at slot `idx` (`uint8_t`).
  static final Guid disconnectDevice = Guid('4627c4a4-ac0a-46b9-b688-afc5c1bf7f63');

  /// `AC0B` (`WRITE | DYNAMIC`): Deletes stored Bluetooth bond keys when `1` (`uint8_t`) is written.
  static final Guid deleteStoredKeys = Guid('4627c4a4-ac0b-46b9-b688-afc5c1bf7f63');

  /// `AC0C` (`WRITE | DYNAMIC`): Reboots the Bluepad32 microcontroller when `1` (`uint8_t`) is written.
  static final Guid resetDevice = Guid('4627c4a4-ac0c-46b9-b688-afc5c1bf7f63');

  /// `AC0D` (`READ | WRITE | DYNAMIC`): Custom UTF-8 BLE advertised service name (`1..29` bytes).
  static final Guid serviceName = Guid('4627c4a4-ac0d-46b9-b688-afc5c1bf7f63');

  /// `AC0E` (`READ | WRITE | DYNAMIC`): Session password authentication gate
  /// (`READ` returns `uint8_t`: `0=open`, `1=required`, `2=authenticated`;
  /// `WRITE` submits a `1..31`-byte UTF-8 password).
  static final Guid serviceAuth = Guid('4627c4a4-ac0e-46b9-b688-afc5c1bf7f63');

  /// Short-handle alias for `AC01` ([version]).
  static final Guid ac01 = version;

  /// Short-handle alias for `AC02` ([maxConnections]).
  static final Guid ac02 = maxConnections;

  /// Short-handle alias for `AC03` ([bleEnabled]).
  static final Guid ac03 = bleEnabled;

  /// Short-handle alias for `AC04` ([scanning]).
  static final Guid ac04 = scanning;

  /// Short-handle alias for `AC05` ([connectedDevices]).
  static final Guid ac05 = connectedDevices;

  /// Short-handle alias for `AC06` ([mappings]).
  static final Guid ac06 = mappings;

  /// Short-handle alias for `AC07` ([allowlistEnabled]).
  static final Guid ac07 = allowlistEnabled;

  /// Short-handle alias for `AC08` ([allowlistAddresses]).
  static final Guid ac08 = allowlistAddresses;

  /// Short-handle alias for `AC09` ([virtualDeviceEnabled]).
  static final Guid ac09 = virtualDeviceEnabled;

  /// Short-handle alias for `AC0A` ([disconnectDevice]).
  static final Guid ac0a = disconnectDevice;

  /// Short-handle alias for `AC0B` ([deleteStoredKeys]).
  static final Guid ac0b = deleteStoredKeys;

  /// Short-handle alias for `AC0C` ([resetDevice]).
  static final Guid ac0c = resetDevice;

  /// Short-handle alias for `AC0D` ([serviceName]).
  static final Guid ac0d = serviceName;

  /// Short-handle alias for `AC0E` ([serviceAuth]).
  static final Guid ac0e = serviceAuth;

  /// All 14 characteristic UUIDs (`AC01` through `AC0E`) in the Bluepad32 GATT service.
  static final List<Guid> allCharacteristics = List.unmodifiable(<Guid>[
    version,
    maxConnections,
    bleEnabled,
    scanning,
    connectedDevices,
    mappings,
    allowlistEnabled,
    allowlistAddresses,
    virtualDeviceEnabled,
    disconnectDevice,
    deleteStoredKeys,
    resetDevice,
    serviceName,
    serviceAuth,
  ]);
}
