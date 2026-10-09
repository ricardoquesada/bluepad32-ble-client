// Domain model and 16-byte little-endian wire codec for Bluepad32 controller slots (`compact_device_t`).

import 'package:flutter/foundation.dart';

import 'controller_type.dart';
import 'mac_address.dart';

export 'controller_type.dart';
export 'mac_address.dart';

/// Immutable representation of a single Bluepad32 controller slot (`compact_device_t`).
///
/// Binary wire layout (16 bytes, packed, little-endian):
/// - Byte `0`: `uint8_t idx` (`0 .. CONFIG_BLUEPAD32_MAX_DEVICES - 1`)
/// - Bytes `1..6`: `bd_addr_t addr` (6-byte Bluetooth MAC address)
/// - Bytes `7..8`: `uint16_t vendor_id` (little-endian)
/// - Bytes `9..10`: `uint16_t product_id` (little-endian)
/// - Byte `11`: `uint8_t state` (`uni_bt_conn_state_t`)
/// - Byte `12`: `uint8_t incoming` (`0` = outgoing, non-zero = incoming)
/// - Bytes `13..14`: `uint16_t controller_type` (little-endian `uni_controller_type_t`)
/// - Byte `15`: `uint8_t controller_subtype` (`uni_controller_subtype_t`)
@immutable
class ConnectedController {
  /// Exact size in bytes of a serialized `compact_device_t` record.
  static const int byteLength = 16;

  /// Controller slot index (`0 .. maxConnections - 1`).
  final int idx;

  /// Bluetooth MAC address of the controller (`00:00:00:00:00:00` when unoccupied).
  final MacAddress address;

  /// USB/Bluetooth Vendor ID (`uint16_t`).
  final int vendorId;

  /// USB/Bluetooth Product ID (`uint16_t`).
  final int productId;

  /// Connection state (`uni_bt_conn_state_t`).
  final Bluepad32DeviceState state;

  /// Whether the connection was initiated by the controller (`true`) or by Bluepad32 (`false`).
  final bool incoming;

  /// Resolved controller model type.
  final Bluepad32ControllerType controllerType;

  /// Resolved controller extension/attachment subtype.
  final Bluepad32ControllerSubtype controllerSubtype;

  const ConnectedController({
    required this.idx,
    required this.address,
    required this.vendorId,
    required this.productId,
    required this.state,
    required this.incoming,
    required this.controllerType,
    required this.controllerSubtype,
  });

  /// Creates an unoccupied controller slot at [idx].
  factory ConnectedController.empty(int idx) {
    return ConnectedController(
      idx: idx,
      address: MacAddress.zero,
      vendorId: 0,
      productId: 0,
      state: Bluepad32DeviceState.deviceNone,
      incoming: false,
      controllerType: Bluepad32ControllerType.unknown,
      controllerSubtype: Bluepad32ControllerSubtype.none,
    );
  }

  /// Deserializes a single 16-byte `compact_device_t` record from [bytes] at [offset].
  ///
  /// Throws a [RangeError] if fewer than [byteLength] bytes are available from [offset].
  factory ConnectedController.fromBytes(List<int> bytes, [int offset = 0]) {
    if (offset < 0 || bytes.length - offset < byteLength) {
      throw RangeError(
        'Expected at least $byteLength bytes for ConnectedController at offset $offset, '
        'got ${bytes.length - offset}.',
      );
    }

    final Uint8List slice = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      slice[i] = bytes[offset + i] & 0xFF;
    }
    final ByteData view = ByteData.sublistView(slice);

    return ConnectedController(
      idx: view.getUint8(0),
      address: MacAddress.fromBytes(slice, 1),
      vendorId: view.getUint16(7, Endian.little),
      productId: view.getUint16(9, Endian.little),
      state: Bluepad32DeviceState.fromValue(view.getUint8(11)),
      incoming: view.getUint8(12) != 0,
      controllerType: Bluepad32ControllerType.fromValue(
        view.getUint16(13, Endian.little),
      ),
      controllerSubtype: Bluepad32ControllerSubtype.fromValue(view.getUint8(15)),
    );
  }

  /// Parses all complete 16-byte `compact_device_t` records from [bytes] and returns
  /// them sorted in ascending order by [idx].
  ///
  /// Trailing unaligned bytes (`bytes.length % 16 != 0`) are ignored.
  static List<ConnectedController> listFromBytes(List<int> bytes) {
    final List<ConnectedController> controllers = <ConnectedController>[];
    for (int offset = 0; offset + byteLength <= bytes.length; offset += byteLength) {
      controllers.add(ConnectedController.fromBytes(bytes, offset));
    }
    controllers.sort((ConnectedController a, ConnectedController b) => a.idx.compareTo(b.idx));
    return controllers;
  }

  /// Whether this slot is occupied by an active or connecting controller.
  bool get isConnected =>
      state != Bluepad32DeviceState.deviceNone || !address.isZero;

  /// Alias for [isConnected].
  bool get isOccupied => isConnected;

  /// Whether this controller has reached `UNI_BT_CONN_STATE_DEVICE_READY` (`14`).
  bool get isReady => state.isReady;

  /// Formatted 4-digit uppercase hex `VID:PID` string (e.g., `'054C:0CE6'`).
  String get vendorProductHex {
    final String vid = vendorId.toRadixString(16).toUpperCase().padLeft(4, '0');
    final String pid = productId.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$vid:$pid';
  }

  /// Serializes this controller slot back into its 16-byte little-endian `compact_device_t` format.
  Uint8List toBytes() {
    final Uint8List buffer = Uint8List(byteLength);
    final ByteData view = ByteData.sublistView(buffer);
    view.setUint8(0, idx & 0xFF);
    buffer.setRange(1, 7, address.toBytes());
    view.setUint16(7, vendorId & 0xFFFF, Endian.little);
    view.setUint16(9, productId & 0xFFFF, Endian.little);
    view.setUint8(11, state.value & 0xFF);
    view.setUint8(12, incoming ? 1 : 0);
    view.setUint16(13, controllerType.value & 0xFFFF, Endian.little);
    view.setUint8(15, controllerSubtype.value & 0xFF);
    return buffer;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ConnectedController &&
        other.idx == idx &&
        other.address == address &&
        other.vendorId == vendorId &&
        other.productId == productId &&
        other.state == state &&
        other.incoming == incoming &&
        other.controllerType == controllerType &&
        other.controllerSubtype == controllerSubtype;
  }

  @override
  int get hashCode => Object.hash(
        idx,
        address,
        vendorId,
        productId,
        state,
        incoming,
        controllerType,
        controllerSubtype,
      );

  @override
  String toString() {
    return 'ConnectedController(idx: $idx, address: $address, '
        'vidPid: $vendorProductHex, state: ${state.name}, '
        'incoming: $incoming, type: ${controllerType.name}, '
        'subtype: ${controllerSubtype.name})';
  }
}
