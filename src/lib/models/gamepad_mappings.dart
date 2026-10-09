// Domain model for Bluepad32 controller face-button mapping presets (`AC06`).

import 'package:flutter/foundation.dart';

/// Controller face-button layout preset matching `uni_gamepad_mappings_type_t`
/// in `src/components/bluepad32/include/controller/uni_gamepad.h`.
enum GamepadMappingsType {
  /// Default Xbox layout: `A` (South), `B` (East), `X` (West), `Y` (North).
  xbox(0, 'Xbox', 'A (South), B (East), X (West), Y (North)'),

  /// Nintendo Switch layout: `B` (South), `A` (East), `Y` (West), `X` (North).
  switchLayout(1, 'Nintendo Switch', 'B (South), A (East), Y (West), X (North)'),

  /// User-defined custom button remapping applied on the firmware.
  custom(2, 'Custom', 'User-defined custom button remapping');

  /// Numeric wire value (`0`, `1`, or `2`).
  final int value;

  /// Short display title for the preset.
  final String label;

  /// Descriptive subtitle explaining the face-button orientation.
  final String subtitle;

  const GamepadMappingsType(this.value, this.label, this.subtitle);

  /// Decodes a `uint8_t` wire value into a [GamepadMappingsType], defaulting to
  /// [GamepadMappingsType.xbox] if out of range.
  static GamepadMappingsType fromValue(int value) {
    for (final GamepadMappingsType candidate in GamepadMappingsType.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadMappingsType.xbox;
  }
}

/// Immutable value object representing the controller mappings configuration (`AC06`).
@immutable
class GamepadMappings {
  /// Active button mapping layout preset.
  final GamepadMappingsType type;

  /// Optional secondary/custom byte if provided by extended payloads (defaults to `0`).
  final int customValue;

  const GamepadMappings({
    this.type = GamepadMappingsType.xbox,
    this.customValue = 0,
  });

  /// Deserializes [GamepadMappings] from a GATT read payload (`AC06`).
  ///
  /// Safely defaults to [GamepadMappingsType.xbox] when [bytes] is empty.
  factory GamepadMappings.fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return const GamepadMappings();
    }
    return GamepadMappings(
      type: GamepadMappingsType.fromValue(bytes[0] & 0xFF),
      customValue: bytes.length >= 2 ? (bytes[1] & 0xFF) : 0,
    );
  }

  /// Serializes this mapping preset to the 1-byte payload expected by `AC06`.
  Uint8List toBytes() => Uint8List.fromList(<int>[type.value]);

  /// Returns a copy of this [GamepadMappings] with the given fields updated.
  GamepadMappings copyWith({
    GamepadMappingsType? type,
    int? customValue,
  }) {
    return GamepadMappings(
      type: type ?? this.type,
      customValue: customValue ?? this.customValue,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GamepadMappings &&
        other.type == type &&
        other.customValue == customValue;
  }

  @override
  int get hashCode => Object.hash(type, customValue);

  @override
  String toString() =>
      'GamepadMappings(type: ${type.name}, customValue: $customValue)';
}
