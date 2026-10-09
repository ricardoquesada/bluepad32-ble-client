// Value object and binary serializer for 6-byte Bluetooth MAC addresses (`bd_addr_t`).

import 'package:flutter/foundation.dart';

/// Immutable value object representing a 6-byte Bluetooth MAC address (`bd_addr_t`).
///
/// Formats canonically as uppercase colon-separated hexadecimal (`AA:BB:CC:DD:EE:FF`)
/// and serializes to/from 6-byte wire payloads used by Bluepad32's `compact_device_t`
/// (`AC05`) and allowlist (`AC08`) characteristics.
@immutable
class MacAddress {
  /// Number of bytes in a Bluetooth `bd_addr_t` address.
  static const int byteLength = 6;

  /// Sentinel all-zero MAC address (`00:00:00:00:00:00`) used by Bluepad32 to mark
  /// unoccupied controller slots (`AC05`) and to clear the allowlist (`AC08`)
  /// without issuing a 0-byte GATT write.
  static final MacAddress zero = MacAddress._(Uint8List(byteLength));

  static final RegExp _macPattern = RegExp(
    r'^([0-9A-Fa-f]{2})[:-]([0-9A-Fa-f]{2})[:-]([0-9A-Fa-f]{2})[:-]'
    r'([0-9A-Fa-f]{2})[:-]([0-9A-Fa-f]{2})[:-]([0-9A-Fa-f]{2})$',
  );

  final Uint8List _bytes;

  MacAddress._(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  /// Creates a [MacAddress] from 6 bytes starting at [offset] in [bytes].
  ///
  /// Throws a [RangeError] if [bytes] contains fewer than 6 bytes after [offset].
  factory MacAddress.fromBytes(List<int> bytes, [int offset = 0]) {
    if (offset < 0 || bytes.length - offset < byteLength) {
      throw RangeError(
        'Expected at least $byteLength bytes for MacAddress at offset $offset, '
        'got ${bytes.length - offset}.',
      );
    }
    final Uint8List raw = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      raw[i] = bytes[offset + i] & 0xFF;
    }
    return MacAddress._(raw);
  }

  /// Parses a Bluetooth MAC address string (`XX:XX:XX:XX:XX:XX` or `XX-XX-XX-XX-XX-XX`).
  ///
  /// Throws a [FormatException] if [input] is not a valid 6-octet hex MAC address.
  factory MacAddress.parse(String input) {
    final MacAddress? parsed = tryParse(input);
    if (parsed == null) {
      throw FormatException('Invalid Bluetooth MAC address: "$input"');
    }
    return parsed;
  }

  /// Attempts to parse [input] into a [MacAddress], returning `null` if malformed.
  ///
  /// Accepts colon (`:`) or hyphen (`-`) separators and normalizes lowercase hex
  /// digits and surrounding whitespace.
  static MacAddress? tryParse(String input) {
    final String trimmed = input.trim();
    final RegExpMatch? match = _macPattern.firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final Uint8List raw = Uint8List(byteLength);
    for (int i = 0; i < byteLength; i++) {
      raw[i] = int.parse(match.group(i + 1)!, radix: 16);
    }
    return MacAddress._(raw);
  }

  /// Unmodifiable 6-element list of raw byte values (`0x00..0xFF`).
  List<int> get octets => List<int>.unmodifiable(_bytes);

  /// Whether all 6 octets are `0x00` (`00:00:00:00:00:00`).
  bool get isZero {
    for (int i = 0; i < byteLength; i++) {
      if (_bytes[i] != 0) {
        return false;
      }
    }
    return true;
  }

  /// Returns a fresh 6-byte [Uint8List] containing this address's wire representation.
  Uint8List toBytes() => Uint8List.fromList(_bytes);

  /// Parses concatenated 6-byte `bd_addr_t` chunks from [bytes], filtering out
  /// any all-zero (`00:00:00:00:00:00`) sentinel entries.
  static List<MacAddress> listFromBytes(List<int> bytes) {
    final List<MacAddress> result = <MacAddress>[];
    for (int offset = 0; offset + byteLength <= bytes.length; offset += byteLength) {
      final MacAddress address = MacAddress.fromBytes(bytes, offset);
      if (!address.isZero) {
        result.add(address);
      }
    }
    return result;
  }

  /// Serializes [addresses] into a contiguous `K * 6`-byte [Uint8List].
  ///
  /// Returns an empty `Uint8List(0)` if [addresses] is empty.
  static Uint8List listToBytes(Iterable<MacAddress> addresses) {
    final List<MacAddress> list = addresses.toList(growable: false);
    final Uint8List buffer = Uint8List(list.length * byteLength);
    for (int i = 0; i < list.length; i++) {
      buffer.setRange(i * byteLength, (i + 1) * byteLength, list[i]._bytes);
    }
    return buffer;
  }

  @override
  String toString() {
    return _bytes
        .map((int b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(':');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! MacAddress) {
      return false;
    }
    for (int i = 0; i < byteLength; i++) {
      if (_bytes[i] != other._bytes[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_bytes);
}
