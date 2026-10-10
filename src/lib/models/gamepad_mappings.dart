/// Domain models and binary codecs for Bluepad32 controller mapping presets (`AC06`)
/// and the 28-byte `uni_gamepad_mappings_t` custom remapping matrix (`AC0F`).
///
/// Key binary wire invariants matching `src/components/bluepad32/include/controller/uni_gamepad.h`:
/// - `sizeof(uni_gamepad_mappings_t) == 28` (28 `uint8_t` fields at offsets `0..27`).
/// - **D-Pad Ordering Asymmetry (Offsets `0..3`):** The C enum `uni_gamepad_mappings_dpad_t`
///   assigns `UP=0, DOWN=1, RIGHT=2, LEFT=3`, while the struct fields are ordered
///   `dpad_up, dpad_down, dpad_left, dpad_right`. Thus the default Xbox wire bytes at
///   offsets `0..3` are `[0, 1, 3, 2]`.
/// - **Misc Button Ordering Asymmetry (Offsets `14..17`):** The C enum
///   `uni_gamepad_mappings_misc_button_t` assigns `SYSTEM=0, SELECT=1, START=2, CAPTURE=3`,
///   while the struct fields are ordered `misc_button_select, misc_button_start,
///   misc_button_system, misc_button_capture`. Thus the default Xbox wire bytes at
///   offsets `14..17` are `[1, 2, 0, 3]`.
library;

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

/// D-pad direction remap target matching `uni_gamepad_mappings_dpad_t` in
/// `src/components/bluepad32/include/controller/uni_gamepad.h`.
///
/// Note the C enum vs. struct field ordering asymmetry:
/// - Enum values are `up(0)`, `down(1)`, `right(2)`, `left(3)`.
/// - Struct fields at wire offsets `0..3` are `dpad_up`, `dpad_down`, `dpad_left`, `dpad_right`,
///   so the default Xbox wire bytes at offsets `0..3` are `[0, 1, 3, 2]`.
enum GamepadDpadTarget {
  /// `UNI_GAMEPAD_MAPPINGS_DPAD_UP` (`0`).
  up(0, 'D-Pad Up'),

  /// `UNI_GAMEPAD_MAPPINGS_DPAD_DOWN` (`1`).
  down(1, 'D-Pad Down'),

  /// `UNI_GAMEPAD_MAPPINGS_DPAD_RIGHT` (`2`).
  right(2, 'D-Pad Right'),

  /// `UNI_GAMEPAD_MAPPINGS_DPAD_LEFT` (`3`).
  left(3, 'D-Pad Left');

  /// Raw `uint8_t` wire value (`0..3`).
  final int value;

  /// Human-readable display label.
  final String label;

  const GamepadDpadTarget(this.value, this.label);

  /// Returns `true` if [value] is within the valid wire domain (`0..3`).
  static bool isValidValue(int value) =>
      value >= 0 && value < GamepadDpadTarget.values.length;

  /// Decodes a `uint8_t` wire value into a [GamepadDpadTarget], defaulting to
  /// [GamepadDpadTarget.up] when out of range.
  static GamepadDpadTarget fromValue(int value) {
    for (final GamepadDpadTarget candidate in GamepadDpadTarget.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadDpadTarget.up;
  }
}

/// Alias for [GamepadDpadTarget].
typedef GamepadDpadInput = GamepadDpadTarget;

/// Face, shoulder, trigger, and thumbstick button remap target matching
/// `uni_gamepad_mappings_button_t` in `uni_gamepad.h`.
enum GamepadButtonTarget {
  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_A` (`0`).
  a(0, 'Button A (South)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_B` (`1`).
  b(1, 'Button B (East)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_X` (`2`).
  x(2, 'Button X (West)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_Y` (`3`).
  y(3, 'Button Y (North)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_SHOULDER_L` (`4`).
  shoulderL(4, 'Left Shoulder (L1)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_SHOULDER_R` (`5`).
  shoulderR(5, 'Right Shoulder (R1)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_TRIGGER_L` (`6`).
  triggerL(6, 'Left Trigger (L2)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_TRIGGER_R` (`7`).
  triggerR(7, 'Right Trigger (R2)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_THUMB_L` (`8`).
  thumbL(8, 'Left Thumb (L3)'),

  /// `UNI_GAMEPAD_MAPPINGS_BUTTON_THUMB_R` (`9`).
  thumbR(9, 'Right Thumb (R3)');

  /// Raw `uint8_t` wire value (`0..9`).
  final int value;

  /// Human-readable display label.
  final String label;

  const GamepadButtonTarget(this.value, this.label);

  /// Returns `true` if [value] is within the valid wire domain (`0..9`).
  static bool isValidValue(int value) =>
      value >= 0 && value < GamepadButtonTarget.values.length;

  /// Decodes a `uint8_t` wire value into a [GamepadButtonTarget], defaulting to
  /// [GamepadButtonTarget.a] when out of range.
  static GamepadButtonTarget fromValue(int value) {
    for (final GamepadButtonTarget candidate in GamepadButtonTarget.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadButtonTarget.a;
  }
}

/// Alias for [GamepadButtonTarget].
typedef GamepadButtonInput = GamepadButtonTarget;

/// Auxiliary/system button remap target matching `uni_gamepad_mappings_misc_button_t`
/// in `uni_gamepad.h`.
///
/// Note the C enum vs. struct field ordering asymmetry:
/// - Enum values are `system(0)`, `select(1)`, `start(2)`, `capture(3)`.
/// - Struct fields at wire offsets `14..17` are `misc_button_select`,
///   `misc_button_start`, `misc_button_system`, `misc_button_capture`, so the
///   default Xbox wire bytes at offsets `14..17` are `[1, 2, 0, 3]`.
enum GamepadMiscButtonTarget {
  /// `UNI_GAMEPAD_MAPPINGS_MISC_BUTTON_SYSTEM` (`0`).
  system(0, 'System'),

  /// `UNI_GAMEPAD_MAPPINGS_MISC_BUTTON_SELECT` (`1`).
  select(1, 'Select'),

  /// `UNI_GAMEPAD_MAPPINGS_MISC_BUTTON_START` (`2`).
  start(2, 'Start'),

  /// `UNI_GAMEPAD_MAPPINGS_MISC_BUTTON_CAPTURE` (`3`).
  capture(3, 'Capture');

  /// Raw `uint8_t` wire value (`0..3`).
  final int value;

  /// Human-readable display label.
  final String label;

  const GamepadMiscButtonTarget(this.value, this.label);

  /// Returns `true` if [value] is within the valid wire domain (`0..3`).
  static bool isValidValue(int value) =>
      value >= 0 && value < GamepadMiscButtonTarget.values.length;

  /// Decodes a `uint8_t` wire value into a [GamepadMiscButtonTarget], defaulting
  /// to [GamepadMiscButtonTarget.system] when out of range.
  static GamepadMiscButtonTarget fromValue(int value) {
    for (final GamepadMiscButtonTarget candidate
        in GamepadMiscButtonTarget.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadMiscButtonTarget.system;
  }
}

/// Alias for [GamepadMiscButtonTarget].
typedef GamepadMiscButtonInput = GamepadMiscButtonTarget;

/// Analog stick axis source matching `uni_gamepad_mappings_axis_t` in `uni_gamepad.h`.
enum GamepadAxisTarget {
  /// `UNI_GAMEPAD_MAPPINGS_AXIS_X` (`0`).
  x(0, 'Left Stick X'),

  /// `UNI_GAMEPAD_MAPPINGS_AXIS_Y` (`1`).
  y(1, 'Left Stick Y'),

  /// `UNI_GAMEPAD_MAPPINGS_AXIS_RX` (`2`).
  rx(2, 'Right Stick X'),

  /// `UNI_GAMEPAD_MAPPINGS_AXIS_RY` (`3`).
  ry(3, 'Right Stick Y');

  /// Raw `uint8_t` wire value (`0..3`).
  final int value;

  /// Human-readable display label.
  final String label;

  const GamepadAxisTarget(this.value, this.label);

  /// Returns `true` if [value] is within the valid wire domain (`0..3`).
  static bool isValidValue(int value) =>
      value >= 0 && value < GamepadAxisTarget.values.length;

  /// Decodes a `uint8_t` wire value into a [GamepadAxisTarget], defaulting to
  /// [GamepadAxisTarget.x] when out of range.
  static GamepadAxisTarget fromValue(int value) {
    for (final GamepadAxisTarget candidate in GamepadAxisTarget.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadAxisTarget.x;
  }
}

/// Alias for [GamepadAxisTarget].
typedef GamepadAxisInput = GamepadAxisTarget;

/// Analog trigger/pedal source matching `uni_gamepad_mappings_pedal_t` in `uni_gamepad.h`.
enum GamepadPedalTarget {
  /// `UNI_GAMEPAD_MAPPINGS_PEDAL_BRAKE` (`0`).
  brake(0, 'Brake (L2)'),

  /// `UNI_GAMEPAD_MAPPINGS_PEDAL_THROTTLE` (`1`).
  throttle(1, 'Throttle (R2)');

  /// Raw `uint8_t` wire value (`0..1`).
  final int value;

  /// Human-readable display label.
  final String label;

  const GamepadPedalTarget(this.value, this.label);

  /// Returns `true` if [value] is within the valid wire domain (`0..1`).
  static bool isValidValue(int value) =>
      value >= 0 && value < GamepadPedalTarget.values.length;

  /// Decodes a `uint8_t` wire value into a [GamepadPedalTarget], defaulting to
  /// [GamepadPedalTarget.brake] when out of range.
  static GamepadPedalTarget fromValue(int value) {
    for (final GamepadPedalTarget candidate in GamepadPedalTarget.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return GamepadPedalTarget.brake;
  }
}

/// Alias for [GamepadPedalTarget].
typedef GamepadPedalInput = GamepadPedalTarget;

/// Immutable 28-byte controller remapping matrix matching `uni_gamepad_mappings_t`
/// in `src/components/bluepad32/include/controller/uni_gamepad.h` (`AC0F`).
///
/// ```dart
/// final CustomGamepadMappings custom = CustomGamepadMappings.defaultXbox.copyWith(
///   buttonA: GamepadButtonTarget.b,
///   buttonB: GamepadButtonTarget.a,
///   axisYInverted: true,
/// );
/// assert(custom.modifiedCount == 3);
/// final Uint8List wireBytes = custom.toBytes(); // 28 bytes for GATT AC0F
/// assert(CustomGamepadMappings.fromBytes(wireBytes) == custom);
/// ```
@immutable
class CustomGamepadMappings {
  /// Exact packed wire length in bytes (`sizeof(uni_gamepad_mappings_t) == 28`).
  static const int byteLength = 28;

  /// Alias for [byteLength].
  static const int payloadLength = byteLength;

  /// Default identity remapping matching `GAMEPAD_DEFAULT_MAPPINGS` in `uni_gamepad.c`.
  static const CustomGamepadMappings defaultXbox = CustomGamepadMappings();

  /// Nintendo Switch face-button preset (`A <-> B` and `X <-> Y` swapped).
  static const CustomGamepadMappings nintendoSwitch = CustomGamepadMappings(
    buttonA: GamepadButtonTarget.b,
    buttonB: GamepadButtonTarget.a,
    buttonX: GamepadButtonTarget.y,
    buttonY: GamepadButtonTarget.x,
  );

  /// Alias for [nintendoSwitch].
  static const CustomGamepadMappings switchLayout = nintendoSwitch;

  /// Preset that swaps Left/Right analog stick axes (`X <-> RX`, `Y <-> RY`) and
  /// thumbstick click buttons (`L3 <-> R3`).
  static const CustomGamepadMappings swapSticks = CustomGamepadMappings(
    buttonThumbL: GamepadButtonTarget.thumbR,
    buttonThumbR: GamepadButtonTarget.thumbL,
    axisX: GamepadAxisTarget.rx,
    axisY: GamepadAxisTarget.ry,
    axisRx: GamepadAxisTarget.x,
    axisRy: GamepadAxisTarget.y,
  );

  /// Offset `0`: Target emitted when physical D-Pad Up is pressed (default [GamepadDpadTarget.up] = `0`).
  final GamepadDpadTarget dpadUp;

  /// Offset `1`: Target emitted when physical D-Pad Down is pressed (default [GamepadDpadTarget.down] = `1`).
  final GamepadDpadTarget dpadDown;

  /// Offset `2`: Target emitted when physical D-Pad Left is pressed (default [GamepadDpadTarget.left] = `3`).
  final GamepadDpadTarget dpadLeft;

  /// Offset `3`: Target emitted when physical D-Pad Right is pressed (default [GamepadDpadTarget.right] = `2`).
  final GamepadDpadTarget dpadRight;

  /// Offset `4`: Target emitted when physical Button A (South) is pressed (default [GamepadButtonTarget.a] = `0`).
  final GamepadButtonTarget buttonA;

  /// Offset `5`: Target emitted when physical Button B (East) is pressed (default [GamepadButtonTarget.b] = `1`).
  final GamepadButtonTarget buttonB;

  /// Offset `6`: Target emitted when physical Button X (West) is pressed (default [GamepadButtonTarget.x] = `2`).
  final GamepadButtonTarget buttonX;

  /// Offset `7`: Target emitted when physical Button Y (North) is pressed (default [GamepadButtonTarget.y] = `3`).
  final GamepadButtonTarget buttonY;

  /// Offset `8`: Target emitted when physical Left Shoulder (`L1`) is pressed (default [GamepadButtonTarget.shoulderL] = `4`).
  final GamepadButtonTarget buttonShoulderL;

  /// Offset `9`: Target emitted when physical Right Shoulder (`R1`) is pressed (default [GamepadButtonTarget.shoulderR] = `5`).
  final GamepadButtonTarget buttonShoulderR;

  /// Offset `10`: Target emitted when physical Left Trigger button (`L2`) is pressed (default [GamepadButtonTarget.triggerL] = `6`).
  final GamepadButtonTarget buttonTriggerL;

  /// Offset `11`: Target emitted when physical Right Trigger button (`R2`) is pressed (default [GamepadButtonTarget.triggerR] = `7`).
  final GamepadButtonTarget buttonTriggerR;

  /// Offset `12`: Target emitted when physical Left Thumb (`L3`) is pressed (default [GamepadButtonTarget.thumbL] = `8`).
  final GamepadButtonTarget buttonThumbL;

  /// Offset `13`: Target emitted when physical Right Thumb (`R3`) is pressed (default [GamepadButtonTarget.thumbR] = `9`).
  final GamepadButtonTarget buttonThumbR;

  /// Offset `14`: Target emitted when physical Select button is pressed (default [GamepadMiscButtonTarget.select] = `1`).
  final GamepadMiscButtonTarget miscButtonSelect;

  /// Offset `15`: Target emitted when physical Start button is pressed (default [GamepadMiscButtonTarget.start] = `2`).
  final GamepadMiscButtonTarget miscButtonStart;

  /// Offset `16`: Target emitted when physical System button is pressed (default [GamepadMiscButtonTarget.system] = `0`).
  final GamepadMiscButtonTarget miscButtonSystem;

  /// Offset `17`: Target emitted when physical Capture button is pressed (default [GamepadMiscButtonTarget.capture] = `3`).
  final GamepadMiscButtonTarget miscButtonCapture;

  /// Offset `18`: Source axis routed to virtual `axis_x` (default [GamepadAxisTarget.x] = `0`).
  final GamepadAxisTarget axisX;

  /// Offset `19`: Source axis routed to virtual `axis_y` (default [GamepadAxisTarget.y] = `1`).
  final GamepadAxisTarget axisY;

  /// Offset `20`: Source axis routed to virtual `axis_rx` (default [GamepadAxisTarget.rx] = `2`).
  final GamepadAxisTarget axisRx;

  /// Offset `21`: Source axis routed to virtual `axis_ry` (default [GamepadAxisTarget.ry] = `3`).
  final GamepadAxisTarget axisRy;

  /// Offset `22`: Whether `axis_x` is inverted (`0` or `1`).
  final bool axisXInverted;

  /// Offset `23`: Whether `axis_y` is inverted (`0` or `1`).
  final bool axisYInverted;

  /// Offset `24`: Whether `axis_rx` is inverted (`0` or `1`).
  final bool axisRxInverted;

  /// Offset `25`: Whether `axis_ry` is inverted (`0` or `1`).
  final bool axisRyInverted;

  /// Offset `26`: Source pedal routed to virtual `brake` (default [GamepadPedalTarget.brake] = `0`).
  final GamepadPedalTarget brake;

  /// Offset `27`: Source pedal routed to virtual `throttle` (default [GamepadPedalTarget.throttle] = `1`).
  final GamepadPedalTarget throttle;

  /// Creates an immutable 28-field [CustomGamepadMappings] configuration.
  const CustomGamepadMappings({
    this.dpadUp = GamepadDpadTarget.up,
    this.dpadDown = GamepadDpadTarget.down,
    this.dpadLeft = GamepadDpadTarget.left,
    this.dpadRight = GamepadDpadTarget.right,
    this.buttonA = GamepadButtonTarget.a,
    this.buttonB = GamepadButtonTarget.b,
    this.buttonX = GamepadButtonTarget.x,
    this.buttonY = GamepadButtonTarget.y,
    this.buttonShoulderL = GamepadButtonTarget.shoulderL,
    this.buttonShoulderR = GamepadButtonTarget.shoulderR,
    this.buttonTriggerL = GamepadButtonTarget.triggerL,
    this.buttonTriggerR = GamepadButtonTarget.triggerR,
    this.buttonThumbL = GamepadButtonTarget.thumbL,
    this.buttonThumbR = GamepadButtonTarget.thumbR,
    this.miscButtonSelect = GamepadMiscButtonTarget.select,
    this.miscButtonStart = GamepadMiscButtonTarget.start,
    this.miscButtonSystem = GamepadMiscButtonTarget.system,
    this.miscButtonCapture = GamepadMiscButtonTarget.capture,
    this.axisX = GamepadAxisTarget.x,
    this.axisY = GamepadAxisTarget.y,
    this.axisRx = GamepadAxisTarget.rx,
    this.axisRy = GamepadAxisTarget.ry,
    this.axisXInverted = false,
    this.axisYInverted = false,
    this.axisRxInverted = false,
    this.axisRyInverted = false,
    this.brake = GamepadPedalTarget.brake,
    this.throttle = GamepadPedalTarget.throttle,
  });

  /// Factory returning [defaultXbox].
  factory CustomGamepadMappings.xboxDefault() => defaultXbox;

  /// Factory returning [nintendoSwitch].
  factory CustomGamepadMappings.switchPreset() => nintendoSwitch;

  /// Validates whether the 28-byte slice in [bytes] starting at [offset]
  /// satisfies `uni_gamepad_mappings_is_valid()` in `uni_gamepad.c`.
  static bool isValidPayload(List<int> bytes, [int offset = 0]) {
    if (offset < 0 || bytes.length - offset < byteLength) {
      return false;
    }
    for (int i = 0; i < 4; i++) {
      if (!GamepadDpadTarget.isValidValue(bytes[offset + i])) {
        return false;
      }
    }
    for (int i = 4; i < 14; i++) {
      if (!GamepadButtonTarget.isValidValue(bytes[offset + i])) {
        return false;
      }
    }
    for (int i = 14; i < 18; i++) {
      if (!GamepadMiscButtonTarget.isValidValue(bytes[offset + i])) {
        return false;
      }
    }
    for (int i = 18; i < 22; i++) {
      if (!GamepadAxisTarget.isValidValue(bytes[offset + i])) {
        return false;
      }
    }
    for (int i = 22; i < 26; i++) {
      final int inverted = bytes[offset + i];
      if (inverted < 0 || inverted > 1) {
        return false;
      }
    }
    for (int i = 26; i < 28; i++) {
      if (!GamepadPedalTarget.isValidValue(bytes[offset + i])) {
        return false;
      }
    }
    return true;
  }

  /// Deserializes a 28-byte `uni_gamepad_mappings_t` struct from [bytes] starting
  /// at [offset].
  ///
  /// Throws a [RangeError] if fewer than [byteLength] (`28`) bytes are available
  /// from [offset].
  factory CustomGamepadMappings.fromBytes(List<int> bytes, [int offset = 0]) {
    if (offset < 0 || bytes.length - offset < byteLength) {
      throw RangeError.range(
        bytes.length - offset,
        byteLength,
        null,
        'bytes',
        'CustomGamepadMappings.fromBytes requires at least $byteLength bytes from offset $offset',
      );
    }

    return CustomGamepadMappings(
      dpadUp: GamepadDpadTarget.fromValue(bytes[offset + 0] & 0xFF),
      dpadDown: GamepadDpadTarget.fromValue(bytes[offset + 1] & 0xFF),
      dpadLeft: GamepadDpadTarget.fromValue(bytes[offset + 2] & 0xFF),
      dpadRight: GamepadDpadTarget.fromValue(bytes[offset + 3] & 0xFF),
      buttonA: GamepadButtonTarget.fromValue(bytes[offset + 4] & 0xFF),
      buttonB: GamepadButtonTarget.fromValue(bytes[offset + 5] & 0xFF),
      buttonX: GamepadButtonTarget.fromValue(bytes[offset + 6] & 0xFF),
      buttonY: GamepadButtonTarget.fromValue(bytes[offset + 7] & 0xFF),
      buttonShoulderL: GamepadButtonTarget.fromValue(bytes[offset + 8] & 0xFF),
      buttonShoulderR: GamepadButtonTarget.fromValue(bytes[offset + 9] & 0xFF),
      buttonTriggerL: GamepadButtonTarget.fromValue(bytes[offset + 10] & 0xFF),
      buttonTriggerR: GamepadButtonTarget.fromValue(bytes[offset + 11] & 0xFF),
      buttonThumbL: GamepadButtonTarget.fromValue(bytes[offset + 12] & 0xFF),
      buttonThumbR: GamepadButtonTarget.fromValue(bytes[offset + 13] & 0xFF),
      miscButtonSelect:
          GamepadMiscButtonTarget.fromValue(bytes[offset + 14] & 0xFF),
      miscButtonStart:
          GamepadMiscButtonTarget.fromValue(bytes[offset + 15] & 0xFF),
      miscButtonSystem:
          GamepadMiscButtonTarget.fromValue(bytes[offset + 16] & 0xFF),
      miscButtonCapture:
          GamepadMiscButtonTarget.fromValue(bytes[offset + 17] & 0xFF),
      axisX: GamepadAxisTarget.fromValue(bytes[offset + 18] & 0xFF),
      axisY: GamepadAxisTarget.fromValue(bytes[offset + 19] & 0xFF),
      axisRx: GamepadAxisTarget.fromValue(bytes[offset + 20] & 0xFF),
      axisRy: GamepadAxisTarget.fromValue(bytes[offset + 21] & 0xFF),
      axisXInverted: (bytes[offset + 22] & 0xFF) != 0,
      axisYInverted: (bytes[offset + 23] & 0xFF) != 0,
      axisRxInverted: (bytes[offset + 24] & 0xFF) != 0,
      axisRyInverted: (bytes[offset + 25] & 0xFF) != 0,
      brake: GamepadPedalTarget.fromValue(bytes[offset + 26] & 0xFF),
      throttle: GamepadPedalTarget.fromValue(bytes[offset + 27] & 0xFF),
    );
  }

  /// Serializes this mapping matrix into the 28-byte packed `uni_gamepad_mappings_t`
  /// binary format expected by GATT characteristic `AC0F`.
  Uint8List toBytes() {
    return Uint8List.fromList(<int>[
      dpadUp.value,
      dpadDown.value,
      dpadLeft.value,
      dpadRight.value,
      buttonA.value,
      buttonB.value,
      buttonX.value,
      buttonY.value,
      buttonShoulderL.value,
      buttonShoulderR.value,
      buttonTriggerL.value,
      buttonTriggerR.value,
      buttonThumbL.value,
      buttonThumbR.value,
      miscButtonSelect.value,
      miscButtonStart.value,
      miscButtonSystem.value,
      miscButtonCapture.value,
      axisX.value,
      axisY.value,
      axisRx.value,
      axisRy.value,
      axisXInverted ? 1 : 0,
      axisYInverted ? 1 : 0,
      axisRxInverted ? 1 : 0,
      axisRyInverted ? 1 : 0,
      brake.value,
      throttle.value,
    ]);
  }

  /// Number of fields (out of `28`) that differ from [defaultXbox].
  int get modifiedCount {
    int count = 0;
    if (dpadUp != defaultXbox.dpadUp) count++;
    if (dpadDown != defaultXbox.dpadDown) count++;
    if (dpadLeft != defaultXbox.dpadLeft) count++;
    if (dpadRight != defaultXbox.dpadRight) count++;
    if (buttonA != defaultXbox.buttonA) count++;
    if (buttonB != defaultXbox.buttonB) count++;
    if (buttonX != defaultXbox.buttonX) count++;
    if (buttonY != defaultXbox.buttonY) count++;
    if (buttonShoulderL != defaultXbox.buttonShoulderL) count++;
    if (buttonShoulderR != defaultXbox.buttonShoulderR) count++;
    if (buttonTriggerL != defaultXbox.buttonTriggerL) count++;
    if (buttonTriggerR != defaultXbox.buttonTriggerR) count++;
    if (buttonThumbL != defaultXbox.buttonThumbL) count++;
    if (buttonThumbR != defaultXbox.buttonThumbR) count++;
    if (miscButtonSelect != defaultXbox.miscButtonSelect) count++;
    if (miscButtonStart != defaultXbox.miscButtonStart) count++;
    if (miscButtonSystem != defaultXbox.miscButtonSystem) count++;
    if (miscButtonCapture != defaultXbox.miscButtonCapture) count++;
    if (axisX != defaultXbox.axisX) count++;
    if (axisY != defaultXbox.axisY) count++;
    if (axisRx != defaultXbox.axisRx) count++;
    if (axisRy != defaultXbox.axisRy) count++;
    if (axisXInverted != defaultXbox.axisXInverted) count++;
    if (axisYInverted != defaultXbox.axisYInverted) count++;
    if (axisRxInverted != defaultXbox.axisRxInverted) count++;
    if (axisRyInverted != defaultXbox.axisRyInverted) count++;
    if (brake != defaultXbox.brake) count++;
    if (throttle != defaultXbox.throttle) count++;
    return count;
  }

  /// Alias for [modifiedCount].
  int get customizedFieldCount => modifiedCount;

  /// Whether all 28 fields match [defaultXbox].
  bool get isDefault => this == defaultXbox;

  /// Alias for [isDefault].
  bool get isDefaultXbox => isDefault;

  /// Returns a copy with Left and Right stick axes (`axisX`/`axisRx`, `axisY`/`axisRy`)
  /// and thumb buttons (`buttonThumbL`/`buttonThumbR`) swapped.
  CustomGamepadMappings withSwappedSticks() {
    return copyWith(
      buttonThumbL: buttonThumbR,
      buttonThumbR: buttonThumbL,
      axisX: axisRx,
      axisY: axisRy,
      axisRx: axisX,
      axisRy: axisY,
    );
  }

  /// Returns a copy of this [CustomGamepadMappings] with the specified fields updated.
  CustomGamepadMappings copyWith({
    GamepadDpadTarget? dpadUp,
    GamepadDpadTarget? dpadDown,
    GamepadDpadTarget? dpadLeft,
    GamepadDpadTarget? dpadRight,
    GamepadButtonTarget? buttonA,
    GamepadButtonTarget? buttonB,
    GamepadButtonTarget? buttonX,
    GamepadButtonTarget? buttonY,
    GamepadButtonTarget? buttonShoulderL,
    GamepadButtonTarget? buttonShoulderR,
    GamepadButtonTarget? buttonTriggerL,
    GamepadButtonTarget? buttonTriggerR,
    GamepadButtonTarget? buttonThumbL,
    GamepadButtonTarget? buttonThumbR,
    GamepadMiscButtonTarget? miscButtonSelect,
    GamepadMiscButtonTarget? miscButtonStart,
    GamepadMiscButtonTarget? miscButtonSystem,
    GamepadMiscButtonTarget? miscButtonCapture,
    GamepadAxisTarget? axisX,
    GamepadAxisTarget? axisY,
    GamepadAxisTarget? axisRx,
    GamepadAxisTarget? axisRy,
    bool? axisXInverted,
    bool? axisYInverted,
    bool? axisRxInverted,
    bool? axisRyInverted,
    GamepadPedalTarget? brake,
    GamepadPedalTarget? throttle,
  }) {
    return CustomGamepadMappings(
      dpadUp: dpadUp ?? this.dpadUp,
      dpadDown: dpadDown ?? this.dpadDown,
      dpadLeft: dpadLeft ?? this.dpadLeft,
      dpadRight: dpadRight ?? this.dpadRight,
      buttonA: buttonA ?? this.buttonA,
      buttonB: buttonB ?? this.buttonB,
      buttonX: buttonX ?? this.buttonX,
      buttonY: buttonY ?? this.buttonY,
      buttonShoulderL: buttonShoulderL ?? this.buttonShoulderL,
      buttonShoulderR: buttonShoulderR ?? this.buttonShoulderR,
      buttonTriggerL: buttonTriggerL ?? this.buttonTriggerL,
      buttonTriggerR: buttonTriggerR ?? this.buttonTriggerR,
      buttonThumbL: buttonThumbL ?? this.buttonThumbL,
      buttonThumbR: buttonThumbR ?? this.buttonThumbR,
      miscButtonSelect: miscButtonSelect ?? this.miscButtonSelect,
      miscButtonStart: miscButtonStart ?? this.miscButtonStart,
      miscButtonSystem: miscButtonSystem ?? this.miscButtonSystem,
      miscButtonCapture: miscButtonCapture ?? this.miscButtonCapture,
      axisX: axisX ?? this.axisX,
      axisY: axisY ?? this.axisY,
      axisRx: axisRx ?? this.axisRx,
      axisRy: axisRy ?? this.axisRy,
      axisXInverted: axisXInverted ?? this.axisXInverted,
      axisYInverted: axisYInverted ?? this.axisYInverted,
      axisRxInverted: axisRxInverted ?? this.axisRxInverted,
      axisRyInverted: axisRyInverted ?? this.axisRyInverted,
      brake: brake ?? this.brake,
      throttle: throttle ?? this.throttle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CustomGamepadMappings &&
        other.dpadUp == dpadUp &&
        other.dpadDown == dpadDown &&
        other.dpadLeft == dpadLeft &&
        other.dpadRight == dpadRight &&
        other.buttonA == buttonA &&
        other.buttonB == buttonB &&
        other.buttonX == buttonX &&
        other.buttonY == buttonY &&
        other.buttonShoulderL == buttonShoulderL &&
        other.buttonShoulderR == buttonShoulderR &&
        other.buttonTriggerL == buttonTriggerL &&
        other.buttonTriggerR == buttonTriggerR &&
        other.buttonThumbL == buttonThumbL &&
        other.buttonThumbR == buttonThumbR &&
        other.miscButtonSelect == miscButtonSelect &&
        other.miscButtonStart == miscButtonStart &&
        other.miscButtonSystem == miscButtonSystem &&
        other.miscButtonCapture == miscButtonCapture &&
        other.axisX == axisX &&
        other.axisY == axisY &&
        other.axisRx == axisRx &&
        other.axisRy == axisRy &&
        other.axisXInverted == axisXInverted &&
        other.axisYInverted == axisYInverted &&
        other.axisRxInverted == axisRxInverted &&
        other.axisRyInverted == axisRyInverted &&
        other.brake == brake &&
        other.throttle == throttle;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[
        dpadUp,
        dpadDown,
        dpadLeft,
        dpadRight,
        buttonA,
        buttonB,
        buttonX,
        buttonY,
        buttonShoulderL,
        buttonShoulderR,
        buttonTriggerL,
        buttonTriggerR,
        buttonThumbL,
        buttonThumbR,
        miscButtonSelect,
        miscButtonStart,
        miscButtonSystem,
        miscButtonCapture,
        axisX,
        axisY,
        axisRx,
        axisRy,
        axisXInverted,
        axisYInverted,
        axisRxInverted,
        axisRyInverted,
        brake,
        throttle,
      ]);

  @override
  String toString() =>
      'CustomGamepadMappings(modifiedCount: $modifiedCount, bytes: ${toBytes()})';
}

/// Immutable value object representing the controller mappings configuration (`AC06` & `AC0F`).
@immutable
class GamepadMappings {
  /// Active button mapping layout preset.
  final GamepadMappingsType type;

  /// Optional secondary/custom byte if provided by legacy 2-byte payloads (defaults to `0`).
  final int customValue;

  /// 28-byte custom controller remapping matrix (`AC0F`), defaulting to [CustomGamepadMappings.defaultXbox].
  final CustomGamepadMappings customMappings;

  const GamepadMappings({
    this.type = GamepadMappingsType.xbox,
    this.customValue = 0,
    this.customMappings = CustomGamepadMappings.defaultXbox,
  });

  /// Deserializes [GamepadMappings] from a GATT read payload (`AC06` or `AC0F`):
  /// - `0` bytes: defaults to [GamepadMappingsType.xbox] and [CustomGamepadMappings.defaultXbox].
  /// - `1` byte (`[type]`): decodes [type] with [customValue] = `0`.
  /// - `2..27` bytes (`[type, customValue, ...]`): decodes [type] and [customValue].
  /// - `28` bytes: decodes a raw 28-byte `AC0F` [CustomGamepadMappings] payload with [type] = [GamepadMappingsType.custom].
  /// - `29+` bytes (`[type, ...28-byte customMappings...]`): decodes [type] and the 28-byte [CustomGamepadMappings] starting at byte `1`.
  factory GamepadMappings.fromBytes(
    List<int> bytes, {
    CustomGamepadMappings? customMappings,
  }) {
    if (bytes.isEmpty) {
      return GamepadMappings(
        customMappings: customMappings ?? CustomGamepadMappings.defaultXbox,
      );
    }
    if (bytes.length == CustomGamepadMappings.byteLength) {
      return GamepadMappings(
        type: GamepadMappingsType.custom,
        customMappings:
            customMappings ?? CustomGamepadMappings.fromBytes(bytes),
      );
    }
    if (bytes.length >= 1 + CustomGamepadMappings.byteLength) {
      return GamepadMappings(
        type: GamepadMappingsType.fromValue(bytes[0] & 0xFF),
        customMappings:
            customMappings ?? CustomGamepadMappings.fromBytes(bytes, 1),
      );
    }
    return GamepadMappings(
      type: GamepadMappingsType.fromValue(bytes[0] & 0xFF),
      customValue: bytes.length >= 2 ? (bytes[1] & 0xFF) : 0,
      customMappings: customMappings ?? CustomGamepadMappings.defaultXbox,
    );
  }

  /// Serializes this mapping preset to the 1-byte payload expected by `AC06`.
  Uint8List toBytes() => Uint8List.fromList(<int>[type.value]);

  /// Serializes this mapping preset to the 1-byte payload expected by `AC06`.
  Uint8List toPresetBytes() => toBytes();

  /// Serializes the 29-byte atomic custom-mappings payload (`[2, ...28-byte customMappings...]`)
  /// accepted by `AC06`.
  Uint8List toAtomicCustomBytes() => Uint8List.fromList(<int>[
        GamepadMappingsType.custom.value,
        ...customMappings.toBytes(),
      ]);

  /// Returns a copy of this [GamepadMappings] with the given fields updated.
  GamepadMappings copyWith({
    GamepadMappingsType? type,
    int? customValue,
    CustomGamepadMappings? customMappings,
  }) {
    return GamepadMappings(
      type: type ?? this.type,
      customValue: customValue ?? this.customValue,
      customMappings: customMappings ?? this.customMappings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GamepadMappings &&
        other.type == type &&
        other.customValue == customValue &&
        other.customMappings == customMappings;
  }

  @override
  int get hashCode => Object.hash(type, customValue, customMappings);

  @override
  String toString() => customMappings.isDefault
      ? 'GamepadMappings(type: ${type.name}, customValue: $customValue)'
      : 'GamepadMappings(type: ${type.name}, customValue: $customValue, customMappings: $customMappings)';
}
