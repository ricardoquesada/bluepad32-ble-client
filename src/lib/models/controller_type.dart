// Domain enums mapping Bluepad32 firmware controller types, attachment subtypes,
// and Bluetooth HID connection lifecycle states.

import 'package:flutter/material.dart';

/// Controller model classification matching `uni_controller_type_t` in
/// `src/components/bluepad32/include/controller/uni_controller_type.h`.
enum Bluepad32ControllerType {
  none(-1, 'None'),
  unknown(0, 'Unknown Controller'),

  // Steam Controllers
  unknownSteamController(1, 'Steam Controller (Unknown)'),
  steamController(2, 'Steam Controller'),
  steamControllerV2(3, 'Steam Controller V2'),
  steamControllerNeptune(4, 'Steam Deck (Neptune)'),

  // Console & Mobile Gamepads
  unknownNonSteamController(30, 'Generic Controller'),
  xbox360Controller(31, 'Xbox 360 Controller'),
  xboxOneController(32, 'Xbox One / Series Controller'),
  ps3Controller(33, 'PlayStation DualShock 3'),
  ps4Controller(34, 'PlayStation DualShock 4'),
  wiiController(35, 'Nintendo Wii Controller'),
  appleController(36, 'Apple MFi Controller'),
  androidController(37, 'Android Controller'),
  switchProController(38, 'Nintendo Switch Pro Controller'),
  switchJoyConLeft(39, 'Nintendo Switch Joy-Con (L)'),
  switchJoyConRight(40, 'Nintendo Switch Joy-Con (R)'),
  switchJoyConPair(41, 'Nintendo Switch Joy-Con Pair'),
  switchInputOnlyController(42, 'Nintendo Switch Input-Only Controller'),
  mobileTouch(43, 'Mobile Touch Controller'),
  xInputSwitchController(44, 'XInput Switch Controller'),
  ps5Controller(45, 'PlayStation DualSense (PS5)'),
  xInputPs4Controller(46, 'XInput PS4 Controller'),

  // Bluepad32 Extensions
  iCadeController(50, 'iCade Arcade Controller'),
  smartTvRemoteController(51, 'Smart TV Remote'),
  eightBitdoController(52, '8BitDo Controller'),
  genericController(53, 'Generic Gamepad'),
  nimbusController(54, 'SteelSeries Nimbus'),
  ouyaController(55, 'OUYA Controller'),
  psMoveController(56, 'PlayStation Move'),
  atariJoystick(57, 'Atari Wireless Joystick'),
  sInputController(58, 'SInput Controller'),
  switch2ProController(59, 'Nintendo Switch 2 Pro Controller'),
  switch2JoyConLeft(60, 'Nintendo Switch 2 Joy-Con (L)'),
  switch2JoyConRight(61, 'Nintendo Switch 2 Joy-Con (R)'),
  steamControllerTriton(62, 'Steam Controller (Triton)'),

  // Keyboards and Mice
  genericKeyboard(400, 'Generic Keyboard'),
  genericMouse(800, 'Generic Mouse');

  /// Numeric wire value from `uni_controller_type_t`.
  final int value;

  /// Human-readable controller model name.
  final String displayName;

  const Bluepad32ControllerType(this.value, this.displayName);

  /// Alias for [displayName].
  String get label => displayName;

  /// Material icon representing this device category.
  IconData get icon {
    switch (this) {
      case Bluepad32ControllerType.genericKeyboard:
        return Icons.keyboard;
      case Bluepad32ControllerType.genericMouse:
        return Icons.mouse;
      case Bluepad32ControllerType.smartTvRemoteController:
        return Icons.settings_remote;
      case Bluepad32ControllerType.mobileTouch:
        return Icons.touch_app;
      case Bluepad32ControllerType.none:
      case Bluepad32ControllerType.unknown:
        return Icons.help_outline;
      default:
        return Icons.sports_esports;
    }
  }

  /// Decodes a `uint16_t` or signed integer `uni_controller_type_t` value.
  ///
  /// Both `-1` (`k_eControllerType_None`) and its unsigned 16-bit representation
  /// `0xFFFF` (`65535`) map to [Bluepad32ControllerType.none]. Any unrecognized
  /// code maps to [Bluepad32ControllerType.unknown].
  static Bluepad32ControllerType fromValue(int value) {
    if (value == -1 || value == 0xFFFF) {
      return Bluepad32ControllerType.none;
    }
    for (final Bluepad32ControllerType candidate in Bluepad32ControllerType.values) {
      if (candidate.value == value) {
        return candidate;
      }
    }
    return Bluepad32ControllerType.unknown;
  }
}

/// Controller attachment/extension subtype matching `uni_controller_subtype_t` in
/// `src/components/bluepad32/include/controller/uni_controller.h`.
enum Bluepad32ControllerSubtype {
  none(0, 'None'),
  wiimoteHorizontal(1, 'Wiimote (Horizontal)'),
  wiimoteVertical(2, 'Wiimote (Vertical)'),
  wiimoteAccel(3, 'Wiimote (Accelerometer)'),
  wiimoteNunchuk(4, 'Wiimote + Nunchuk'),
  unused00(5, 'Unused'),
  wiimoteNunchukAccel(6, 'Wiimote + Nunchuk (Accel)'),
  wiiClassic(7, 'Wii Classic Controller'),
  wiiUPro(8, 'Wii U Pro Controller'),
  wiiBalanceBoard(9, 'Wii Balance Board'),
  wiimoteUdrawTablet(10, 'uDraw GameTablet'),
  exampleOfNewGamepad(20, 'Custom Gamepad Subtype'),
  unknown(-1, 'Unknown Subtype');

  /// Numeric wire value from `uni_controller_subtype_t`.
  final int value;

  /// Human-readable subtype label.
  final String displayName;

  const Bluepad32ControllerSubtype(this.value, this.displayName);

  /// Alias for [displayName].
  String get label => displayName;

  /// Decodes a `uint8_t` wire value into a [Bluepad32ControllerSubtype].
  static Bluepad32ControllerSubtype fromValue(int value) {
    for (final Bluepad32ControllerSubtype candidate in Bluepad32ControllerSubtype.values) {
      if (candidate != Bluepad32ControllerSubtype.unknown && candidate.value == value) {
        return candidate;
      }
    }
    return Bluepad32ControllerSubtype.unknown;
  }
}

/// Bluetooth HID connection lifecycle state matching `uni_bt_conn_state_t` in
/// `src/components/bluepad32/include/bt/uni_bt_conn.h`.
enum Bluepad32DeviceState {
  deviceNone(0, 'Disconnected'),
  deviceDiscovered(1, 'Discovered'),
  remoteNameRequest(2, 'Requesting Name'),
  remoteNameInquired(3, 'Name Inquired'),
  remoteNameFetched(4, 'Name Fetched'),
  sdpVendorRequested(5, 'Querying SDP Vendor'),
  sdpVendorFetched(6, 'SDP Vendor Fetched'),
  sdpHidDescriptorRequested(7, 'Querying HID Descriptor'),
  sdpHidDescriptorFetched(8, 'HID Descriptor Fetched'),
  l2capControlConnectionRequested(9, 'Connecting L2CAP Control'),
  l2capControlConnected(10, 'L2CAP Control Connected'),
  l2capInterruptConnectionRequested(11, 'Connecting L2CAP Interrupt'),
  l2capInterruptConnected(12, 'L2CAP Interrupt Connected'),
  devicePendingReady(13, 'Pending Ready'),
  deviceReady(14, 'Ready'),
  unknown(-1, 'Unknown State');

  /// Numeric wire value from `uni_bt_conn_state_t`.
  final int value;

  /// Human-readable connection state label.
  final String displayName;

  const Bluepad32DeviceState(this.value, this.displayName);

  /// Alias for [displayName].
  String get label => displayName;

  /// Whether the controller has completed HID/SDP initialization and is ready.
  bool get isReady => this == Bluepad32DeviceState.deviceReady;

  /// Decodes a `uint8_t` wire value into a [Bluepad32DeviceState].
  static Bluepad32DeviceState fromValue(int value) {
    for (final Bluepad32DeviceState candidate in Bluepad32DeviceState.values) {
      if (candidate != Bluepad32DeviceState.unknown && candidate.value == value) {
        return candidate;
      }
    }
    return Bluepad32DeviceState.unknown;
  }
}
