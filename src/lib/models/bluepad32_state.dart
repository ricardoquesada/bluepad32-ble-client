// Immutable state snapshot aggregating all Bluepad32 GATT characteristics (`AC01`–`AC0E`)
// and BLE connection status for presentation in the Material 3 dashboard.

import 'package:flutter/foundation.dart';

import 'connected_controller.dart';
import 'gamepad_mappings.dart';

export 'connected_controller.dart';
export 'gamepad_mappings.dart';

/// Session authentication status reported by characteristic `AC0E` (`serviceAuth`).
///
/// Mirrors `uni_bt_service_auth_state_t` in `src/components/bluepad32/include/bt/uni_bt_service.h`.
enum Bluepad32AuthStatus {
  /// `0`: No password is configured on the peripheral; all characteristics are open.
  open(0),

  /// `1`: A password is required and the current BLE connection is still locked.
  required(1),

  /// `2`: A password is required and the current BLE connection has authenticated.
  authenticated(2);

  /// Raw `uint8_t` wire value returned when reading `AC0E`.
  final int value;

  const Bluepad32AuthStatus(this.value);

  /// Decodes a single `uint8_t` [value] from `AC0E`, defaulting to [open] for
  /// unrecognized values.
  static Bluepad32AuthStatus fromByte(int value) {
    return switch (value & 0xFF) {
      1 => Bluepad32AuthStatus.required,
      2 => Bluepad32AuthStatus.authenticated,
      _ => Bluepad32AuthStatus.open,
    };
  }

  /// Decodes the raw byte list returned from reading `AC0E`, defaulting to
  /// [open] when [bytes] is empty (e.g., on legacy firmware without `AC0E`).
  static Bluepad32AuthStatus fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return Bluepad32AuthStatus.open;
    }
    return fromByte(bytes[0]);
  }
}

/// Immutable snapshot of a Bluepad32 device's connection and GATT configuration state.
@immutable
class Bluepad32State {
  /// Whether a BLE connection and GATT service discovery sequence is in progress.
  final bool isConnecting;

  /// Whether the BLE peripheral is currently connected and the Bluepad32 GATT service is ready.
  final bool isConnected;

  /// Whether a full GATT characteristic read (`refreshAll()`) is currently running.
  final bool isRefreshing;

  /// Most recent user-facing error message, or `null` if no error is active.
  final String? errorMessage;

  /// Bluepad32 firmware version string read from `AC01` (e.g., `"v4.2.0"`).
  final String? firmwareVersion;

  /// Custom BLE service name read from `AC0D` (e.g., `"Bluepad32 rc car"`),
  /// or `''` if not set / not yet read.
  final String serviceName;

  /// Session authentication state read from `AC0E`.
  final Bluepad32AuthStatus authStatus;

  /// Maximum concurrent controller connections read from `AC02` (default `4`).
  final int maxConnections;

  /// Whether BLE controller connections are enabled on the firmware (`AC03`).
  final bool bleEnabled;

  /// Whether controller inquiry/scanning is currently active on the firmware (`AC04`).
  final bool scanningEnabled;

  /// All controller slots (`0 .. maxConnections - 1`) reported by `AC05`.
  final List<ConnectedController> controllers;

  /// Active controller face-button mapping layout (`AC06`).
  final GamepadMappings mappings;

  /// Whether Bluetooth MAC allowlist enforcement is enabled (`AC07`).
  final bool allowlistEnabled;

  /// Persisted Bluetooth MAC addresses in the firmware allowlist (`AC08`).
  final List<MacAddress> allowlistAddresses;

  /// Whether virtual child devices (such as DualShock/DualSense touchpad mouse) are enabled (`AC09`).
  final bool virtualDevicesEnabled;

  const Bluepad32State({
    this.isConnecting = false,
    this.isConnected = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.firmwareVersion,
    this.serviceName = '',
    this.authStatus = Bluepad32AuthStatus.open,
    this.maxConnections = 4,
    this.bleEnabled = false,
    this.scanningEnabled = false,
    this.controllers = const <ConnectedController>[],
    this.mappings = const GamepadMappings(),
    this.allowlistEnabled = false,
    this.allowlistAddresses = const <MacAddress>[],
    this.virtualDevicesEnabled = false,
  });

  /// Subset of [controllers] that are currently occupied/connected.
  List<ConnectedController> get activeControllers =>
      controllers.where((ConnectedController c) => c.isConnected).toList(growable: false);

  /// Whether the connected peripheral has a non-empty service password configured
  /// ([Bluepad32AuthStatus.required] or [Bluepad32AuthStatus.authenticated]).
  bool get isPasswordProtected => authStatus != Bluepad32AuthStatus.open;

  /// Whether the connected peripheral is currently locked and requires a password
  /// write to `AC0E` before telemetry or configuration characteristics can be accessed.
  bool get requiresAuthentication =>
      authStatus == Bluepad32AuthStatus.required;

  /// Whether the current session is authorized to read/write protected characteristics
  /// ([Bluepad32AuthStatus.open] or [Bluepad32AuthStatus.authenticated]).
  bool get isAuthenticated => authStatus != Bluepad32AuthStatus.required;

  /// Creates a copy of this state with updated fields.
  ///
  /// Pass `clearError: true` to clear any existing [errorMessage] (unless a new
  /// non-null [errorMessage] is simultaneously provided).
  /// Pass `clearServiceName: true` to reset [serviceName] to `''`.
  Bluepad32State copyWith({
    bool? isConnecting,
    bool? isConnected,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    String? firmwareVersion,
    String? serviceName,
    bool clearServiceName = false,
    Bluepad32AuthStatus? authStatus,
    int? maxConnections,
    bool? bleEnabled,
    bool? scanningEnabled,
    List<ConnectedController>? controllers,
    GamepadMappings? mappings,
    bool? allowlistEnabled,
    List<MacAddress>? allowlistAddresses,
    bool? virtualDevicesEnabled,
  }) {
    return Bluepad32State(
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? errorMessage : (errorMessage ?? this.errorMessage),
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      serviceName:
          clearServiceName ? (serviceName ?? '') : (serviceName ?? this.serviceName),
      authStatus: authStatus ?? this.authStatus,
      maxConnections: maxConnections ?? this.maxConnections,
      bleEnabled: bleEnabled ?? this.bleEnabled,
      scanningEnabled: scanningEnabled ?? this.scanningEnabled,
      controllers: controllers != null
          ? List<ConnectedController>.unmodifiable(controllers)
          : this.controllers,
      mappings: mappings ?? this.mappings,
      allowlistEnabled: allowlistEnabled ?? this.allowlistEnabled,
      allowlistAddresses: allowlistAddresses != null
          ? List<MacAddress>.unmodifiable(allowlistAddresses)
          : this.allowlistAddresses,
      virtualDevicesEnabled: virtualDevicesEnabled ?? this.virtualDevicesEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Bluepad32State &&
        other.isConnecting == isConnecting &&
        other.isConnected == isConnected &&
        other.isRefreshing == isRefreshing &&
        other.errorMessage == errorMessage &&
        other.firmwareVersion == firmwareVersion &&
        other.serviceName == serviceName &&
        other.authStatus == authStatus &&
        other.maxConnections == maxConnections &&
        other.bleEnabled == bleEnabled &&
        other.scanningEnabled == scanningEnabled &&
        listEquals(other.controllers, controllers) &&
        other.mappings == mappings &&
        other.allowlistEnabled == allowlistEnabled &&
        listEquals(other.allowlistAddresses, allowlistAddresses) &&
        other.virtualDevicesEnabled == virtualDevicesEnabled;
  }

  @override
  int get hashCode => Object.hash(
        isConnecting,
        isConnected,
        isRefreshing,
        errorMessage,
        firmwareVersion,
        serviceName,
        authStatus,
        maxConnections,
        bleEnabled,
        scanningEnabled,
        Object.hashAll(controllers),
        mappings,
        allowlistEnabled,
        Object.hashAll(allowlistAddresses),
        virtualDevicesEnabled,
      );
}
