/// Unit tests for Bluepad32 GATT binary protocol models, enums, immutable state,
/// and [Bluepad32Client] service layer interactions.
///
/// Covers:
/// - [Bluepad32Uuids] service (`AC00`) and characteristic (`AC01`–`AC0C`) constants
/// - [ConnectedController] 16-byte `compact_device_t` little-endian decoding,
///   64-byte 4-slot table parsing, and slot occupancy boundary conditions
/// - [MacAddress] parsing, normalization, zero-sentinel filtering, and byte serialization
/// - [GamepadMappings] and [GamepadMappingsType] decoding and fallback defaults
/// - [Bluepad32ControllerType], [Bluepad32ControllerSubtype], and
///   [Bluepad32DeviceState] enum mappings, labels, and Material icons
/// - [Bluepad32State] immutability, `copyWith(clearError: true)`, and equality
/// - [Bluepad32Client] GATT read/write/notify lifecycle, allowlist 6-zero-byte
///   clearing (`AC08`), reboot disconnection tolerance (`AC0C`), and production
///   GATT transport discovery via in-memory [BluetoothDevice] fakes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bluepad32_client/services/bluepad32_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bluepad32Uuids', () {
    test('defines primary service and contiguous AC01..AC0C characteristics', () {
      expect(
        Bluepad32Uuids.service,
        Guid('4627c4a4-ac00-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.version,
        Guid('4627c4a4-ac01-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.maxConnections,
        Guid('4627c4a4-ac02-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.bleEnabled,
        Guid('4627c4a4-ac03-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.scanning,
        Guid('4627c4a4-ac04-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.connectedDevices,
        Guid('4627c4a4-ac05-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.mappings,
        Guid('4627c4a4-ac06-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.allowlistEnabled,
        Guid('4627c4a4-ac07-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.allowlistAddresses,
        Guid('4627c4a4-ac08-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.virtualDeviceEnabled,
        Guid('4627c4a4-ac09-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.disconnectDevice,
        Guid('4627c4a4-ac0a-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.deleteStoredKeys,
        Guid('4627c4a4-ac0b-46b9-b688-afc5c1bf7f63'),
      );
      expect(
        Bluepad32Uuids.resetDevice,
        Guid('4627c4a4-ac0c-46b9-b688-afc5c1bf7f63'),
      );
      expect(Bluepad32Uuids.allCharacteristics, hasLength(12));
    });

    test('Bluepad32Uuids aliases match primary characteristic UUIDs', () {
      expect(
        Bluepad32Uuids.virtualDevicesEnabled,
        equals(Bluepad32Uuids.virtualDeviceEnabled),
      );
      expect(Bluepad32Uuids.ac01, equals(Bluepad32Uuids.version));
      expect(Bluepad32Uuids.ac02, equals(Bluepad32Uuids.maxConnections));
      expect(Bluepad32Uuids.ac03, equals(Bluepad32Uuids.bleEnabled));
      expect(Bluepad32Uuids.ac04, equals(Bluepad32Uuids.scanning));
      expect(Bluepad32Uuids.ac05, equals(Bluepad32Uuids.connectedDevices));
      expect(Bluepad32Uuids.ac06, equals(Bluepad32Uuids.mappings));
      expect(Bluepad32Uuids.ac07, equals(Bluepad32Uuids.allowlistEnabled));
      expect(Bluepad32Uuids.ac08, equals(Bluepad32Uuids.allowlistAddresses));
      expect(Bluepad32Uuids.ac09, equals(Bluepad32Uuids.virtualDeviceEnabled));
      expect(Bluepad32Uuids.ac0a, equals(Bluepad32Uuids.disconnectDevice));
      expect(Bluepad32Uuids.ac0b, equals(Bluepad32Uuids.deleteStoredKeys));
      expect(Bluepad32Uuids.ac0c, equals(Bluepad32Uuids.resetDevice));
    });
  });

  group('3.1 ConnectedController Binary Deserialization & Occupancy', () {
    test('parses 16-byte single-slot notification payload (DualSense on slot 1)', () {
      final List<int> payload = <int>[
        0x01, // idx = 1
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, // addr = AA:BB:CC:DD:EE:FF
        0x4C, 0x05, // vendor_id = 0x054C (Sony LE)
        0xE6, 0x0C, // product_id = 0x0CE6 (DualSense LE)
        0x0E, // state = 14 (DEVICE_READY)
        0x01, // incoming = 1
        0x2D, 0x00, // controller_type = 45 (PS5Controller LE)
        0x00, // controller_subtype = 0 (NONE)
      ];

      final ConnectedController controller = ConnectedController.fromBytes(payload);

      expect(controller.idx, 1);
      expect(controller.address.toString(), 'AA:BB:CC:DD:EE:FF');
      expect(controller.vendorId, 0x054C);
      expect(controller.productId, 0x0CE6);
      expect(controller.vendorProductHex, '054C:0CE6');
      expect(controller.state, Bluepad32DeviceState.deviceReady);
      expect(controller.isReady, isTrue);
      expect(controller.incoming, isTrue);
      expect(controller.controllerType, Bluepad32ControllerType.ps5Controller);
      expect(controller.controllerSubtype, Bluepad32ControllerSubtype.none);
      expect(controller.isConnected, isTrue);
      expect(controller.isOccupied, isTrue);
      expect(controller.toBytes(), equals(Uint8List.fromList(payload)));
    });

    test('parses 64-byte 4-slot full table read/notify payload', () {
      final Uint8List slot0 = ConnectedController(
        idx: 0,
        address: MacAddress.parse('98:B6:E9:12:34:56'),
        vendorId: 0x057E,
        productId: 0x2009,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.switchProController,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      ).toBytes();

      final Uint8List slot1 = ConnectedController.empty(1).toBytes();

      final Uint8List slot2 = ConnectedController(
        idx: 2,
        address: MacAddress.parse('44:16:22:AA:BB:CC'),
        vendorId: 0x045E,
        productId: 0x02FD,
        state: Bluepad32DeviceState.deviceReady,
        incoming: false,
        controllerType: Bluepad32ControllerType.xboxOneController,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      ).toBytes();

      final Uint8List slot3 = ConnectedController.empty(3).toBytes();

      final BytesBuilder builder = BytesBuilder(copy: false)
        ..add(slot0)
        ..add(slot1)
        ..add(slot2)
        ..add(slot3);
      final Uint8List fullTable = builder.toBytes();
      expect(fullTable, hasLength(64));

      final List<ConnectedController> controllers =
          ConnectedController.listFromBytes(fullTable);

      expect(controllers, hasLength(4));
      expect(controllers.map((ConnectedController c) => c.idx), <int>[0, 1, 2, 3]);
      expect(controllers[0].isConnected, isTrue);
      expect(
        controllers[0].controllerType,
        Bluepad32ControllerType.switchProController,
      );
      expect(controllers[0].vendorProductHex, '057E:2009');
      expect(controllers[1].isConnected, isFalse);
      expect(controllers[2].isConnected, isTrue);
      expect(
        controllers[2].controllerType,
        Bluepad32ControllerType.xboxOneController,
      );
      expect(controllers[2].incoming, isFalse);
      expect(controllers[3].isConnected, isFalse);
    });

    test('sorts out-of-order slots ascending by idx in listFromBytes', () {
      final Uint8List recordIdx2 = ConnectedController.empty(2).toBytes();
      final Uint8List recordIdx0 = ConnectedController.empty(0).toBytes();
      final Uint8List payload = Uint8List.fromList(<int>[
        ...recordIdx2,
        ...recordIdx0,
      ]);

      final List<ConnectedController> parsed =
          ConnectedController.listFromBytes(payload);
      expect(parsed, hasLength(2));
      expect(parsed[0].idx, 0);
      expect(parsed[1].idx, 2);
    });

    test('handles empty, short, and unaligned byte arrays safely', () {
      expect(ConnectedController.listFromBytes(const <int>[]), isEmpty);
      expect(ConnectedController.listFromBytes(const <int>[1, 2, 3]), isEmpty);

      final Uint8List unaligned20Bytes = Uint8List.fromList(<int>[
        ...ConnectedController.empty(0).toBytes(),
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ]);
      final List<ConnectedController> parsed =
          ConnectedController.listFromBytes(unaligned20Bytes);
      expect(parsed, hasLength(1));
      expect(parsed.first.idx, 0);

      expect(
        () => ConnectedController.fromBytes(const <int>[1, 2, 3]),
        throwsRangeError,
      );
      expect(
        () => ConnectedController.fromBytes(unaligned20Bytes, 8),
        throwsRangeError,
      );
    });

    test('evaluates isConnected / isOccupied boundary conditions', () {
      // (a) state != deviceNone and non-zero MAC
      final ConnectedController caseA = ConnectedController(
        idx: 0,
        address: MacAddress.parse('11:22:33:44:55:66'),
        vendorId: 0,
        productId: 0,
        state: Bluepad32DeviceState.l2capInterruptConnected,
        incoming: false,
        controllerType: Bluepad32ControllerType.unknown,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      expect(caseA.isConnected, isTrue);

      // (b) state != deviceNone and zero MAC
      final ConnectedController caseB = ConnectedController(
        idx: 0,
        address: MacAddress.zero,
        vendorId: 0,
        productId: 0,
        state: Bluepad32DeviceState.deviceDiscovered,
        incoming: false,
        controllerType: Bluepad32ControllerType.unknown,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      expect(caseB.isConnected, isTrue);

      // (c) state == deviceNone and non-zero MAC
      final ConnectedController caseC = ConnectedController(
        idx: 0,
        address: MacAddress.parse('11:22:33:44:55:66'),
        vendorId: 0,
        productId: 0,
        state: Bluepad32DeviceState.deviceNone,
        incoming: false,
        controllerType: Bluepad32ControllerType.unknown,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      expect(caseC.isConnected, isTrue);

      // (d) state == deviceNone and zero MAC
      final ConnectedController caseD = ConnectedController.empty(0);
      expect(caseD.isConnected, isFalse);
      expect(caseD.isOccupied, isFalse);
    });

    test('ConnectedController equality, hashCode, toString, and negative offset guard', () {
      final ConnectedController a = ConnectedController(
        idx: 1,
        address: MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      final ConnectedController b = ConnectedController(
        idx: 1,
        address: MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      final ConnectedController c = ConnectedController.empty(1);

      expect(a, equals(a));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a == Object(), isFalse);

      expect(
        a.toString(),
        equals(
          'ConnectedController(idx: 1, address: AA:BB:CC:DD:EE:FF, '
          'vidPid: 054C:0CE6, state: deviceReady, incoming: true, '
          'type: ps5Controller, subtype: none)',
        ),
      );

      expect(
        () => ConnectedController.fromBytes(a.toBytes(), -1),
        throwsRangeError,
      );
    });
  });

  group('3.2 MacAddress Parsing, Normalization & Serialization', () {
    test('parses valid colon-separated uppercase hex', () {
      final MacAddress? mac = MacAddress.tryParse('11:22:33:AA:BB:CC');
      expect(mac, isNotNull);
      expect(mac.toString(), '11:22:33:AA:BB:CC');
      expect(
        mac!.toBytes(),
        equals(Uint8List.fromList(<int>[0x11, 0x22, 0x33, 0xAA, 0xBB, 0xCC])),
      );
      expect(mac.octets, equals(<int>[0x11, 0x22, 0x33, 0xAA, 0xBB, 0xCC]));
      expect(mac == Object(), isFalse);
      expect(mac, isNot(equals(MacAddress.zero)));
    });

    test('normalizes lowercase, hyphen-separated, and padded strings', () {
      final MacAddress? fromHyphens = MacAddress.tryParse('aa-bb-cc-01-02-fe');
      final MacAddress fromPadded = MacAddress.parse('  aa:bb:cc:01:02:fe ');
      final MacAddress fromUpper = MacAddress.parse('AA:BB:CC:01:02:FE');

      expect(fromHyphens, isNotNull);
      expect(fromHyphens.toString(), 'AA:BB:CC:01:02:FE');
      expect(fromPadded.toString(), 'AA:BB:CC:01:02:FE');
      expect(fromHyphens, equals(fromPadded));
      expect(fromPadded, equals(fromUpper));
      expect(fromHyphens.hashCode, equals(fromUpper.hashCode));
    });

    test('rejects malformed MAC strings', () {
      const List<String> invalidInputs = <String>[
        '',
        '11:22:33:44:55',
        '11:22:33:44:55:66:77',
        'GG:00:00:00:00:00',
        '112233445566',
        '11:22:33:44:55:666',
      ];

      for (final String input in invalidInputs) {
        expect(
          MacAddress.tryParse(input),
          isNull,
          reason: 'Expected "$input" to fail tryParse',
        );
        expect(
          () => MacAddress.parse(input),
          throwsFormatException,
          reason: 'Expected "$input" to throw FormatException',
        );
      }
    });

    test('detects zero MAC address', () {
      expect(MacAddress.zero.isZero, isTrue);
      expect(MacAddress.zero.toString(), '00:00:00:00:00:00');
      expect(MacAddress.parse('00:00:00:00:00:00').isZero, isTrue);
      expect(MacAddress.parse('00:00:00:00:00:01').isZero, isFalse);
    });

    test('round-trips fromBytes() and toBytes()', () {
      final List<int> raw = <int>[0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01];
      final MacAddress mac = MacAddress.fromBytes(raw);
      expect(mac.toString(), 'DE:AD:BE:EF:00:01');
      expect(mac.toBytes(), equals(Uint8List.fromList(raw)));
    });

    test('MacAddress.fromBytes throws RangeError on negative offset or short buffer', () {
      expect(
        () => MacAddress.fromBytes(const <int>[1, 2, 3, 4, 5, 6], -1),
        throwsRangeError,
      );
      expect(
        () => MacAddress.fromBytes(const <int>[1, 2, 3, 4, 5]),
        throwsRangeError,
      );
      expect(
        () => MacAddress.fromBytes(const <int>[1, 2, 3, 4, 5, 6], 2),
        throwsRangeError,
      );
    });

    test('MacAddress.listFromBytes ignores trailing unaligned bytes', () {
      final List<int> fourteenBytes = <int>[
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, // MAC 1
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, // MAC 2
        0xAA, 0xBB, // 2 trailing unaligned bytes
      ];
      final List<MacAddress> parsed = MacAddress.listFromBytes(fourteenBytes);
      expect(parsed, <MacAddress>[
        MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        MacAddress.parse('11:22:33:44:55:66'),
      ]);
    });

    test('filters zero sentinel entries in listFromBytes()', () {
      expect(MacAddress.listFromBytes(const <int>[]), isEmpty);
      expect(MacAddress.listFromBytes(const <int>[0, 0, 0, 0, 0, 0]), isEmpty);

      final List<int> eighteenBytes = <int>[
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, // entry 0
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // zero sentinel (filtered)
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, // entry 2
      ];
      final List<MacAddress> parsed = MacAddress.listFromBytes(eighteenBytes);
      expect(parsed, <MacAddress>[
        MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        MacAddress.parse('11:22:33:44:55:66'),
      ]);
    });

    test('serializes listToBytes() cleanly', () {
      final MacAddress mac1 = MacAddress.parse('AA:BB:CC:DD:EE:FF');
      final MacAddress mac2 = MacAddress.parse('11:22:33:44:55:66');

      final Uint8List twelveBytes = MacAddress.listToBytes(<MacAddress>[
        mac1,
        mac2,
      ]);
      expect(twelveBytes, hasLength(12));
      expect(
        twelveBytes,
        equals(
          Uint8List.fromList(<int>[
            0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66,
          ]),
        ),
      );

      final Uint8List emptyBytes = MacAddress.listToBytes(const <MacAddress>[]);
      expect(emptyBytes, isEmpty);
    });
  });

  group('3.3 GamepadMappings & GamepadMappingsType', () {
    test('decodes [0, 0] and [0] as Xbox mappings', () {
      final GamepadMappings fromTwoBytes =
          GamepadMappings.fromBytes(const <int>[0, 0]);
      final GamepadMappings fromOneByte =
          GamepadMappings.fromBytes(const <int>[0]);

      expect(fromTwoBytes.type, GamepadMappingsType.xbox);
      expect(fromTwoBytes.customValue, 0);
      expect(fromOneByte.type, GamepadMappingsType.xbox);
      expect(fromOneByte.customValue, 0);
      expect(fromTwoBytes, equals(fromOneByte));
    });

    test('decodes [1, 2], [1], and [2] as Switch and Custom presets', () {
      final GamepadMappings switchWithCustom =
          GamepadMappings.fromBytes(const <int>[1, 2]);
      expect(switchWithCustom.type, GamepadMappingsType.switchLayout);
      expect(switchWithCustom.customValue, 2);

      final GamepadMappings switchPreset =
          GamepadMappings.fromBytes(const <int>[1]);
      expect(switchPreset.type, GamepadMappingsType.switchLayout);
      expect(switchPreset.customValue, 0);

      final GamepadMappings customPreset =
          GamepadMappings.fromBytes(const <int>[2]);
      expect(customPreset.type, GamepadMappingsType.custom);
      expect(customPreset.customValue, 0);
    });

    test('safely defaults to Xbox mappings when bytes are empty', () {
      final GamepadMappings empty = GamepadMappings.fromBytes(const <int>[]);
      expect(empty.type, GamepadMappingsType.xbox);
      expect(empty.customValue, 0);
    });

    test('supports toBytes(), copyWith(), and value equality', () {
      const GamepadMappings initial = GamepadMappings();
      final GamepadMappings updated = initial.copyWith(
        type: GamepadMappingsType.switchLayout,
      );
      final GamepadMappings updatedCustom = updated.copyWith(customValue: 5);

      expect(initial.toBytes(), equals(Uint8List.fromList(<int>[0])));
      expect(updated.toBytes(), equals(Uint8List.fromList(<int>[1])));
      expect(updatedCustom.type, GamepadMappingsType.switchLayout);
      expect(updatedCustom.customValue, 5);
      expect(initial, isNot(equals(updated)));
      expect(initial == Object(), isFalse);
      expect(
        updated,
        equals(const GamepadMappings(type: GamepadMappingsType.switchLayout)),
      );
      expect(
        updated.hashCode,
        equals(
          const GamepadMappings(type: GamepadMappingsType.switchLayout).hashCode,
        ),
      );
    });

    test('GamepadMappingsType.fromValue fallback and GamepadMappings.toString', () {
      expect(
        GamepadMappingsType.fromValue(99),
        equals(GamepadMappingsType.xbox),
      );

      final GamepadMappings fallbackSingleByte =
          GamepadMappings.fromBytes(const <int>[99]);
      expect(fallbackSingleByte.type, equals(GamepadMappingsType.xbox));
      expect(fallbackSingleByte.customValue, equals(0));

      final GamepadMappings fallbackTwoBytes =
          GamepadMappings.fromBytes(const <int>[99, 42]);
      expect(fallbackTwoBytes.type, equals(GamepadMappingsType.xbox));
      expect(fallbackTwoBytes.customValue, equals(42));

      expect(
        const GamepadMappings(
          type: GamepadMappingsType.switchLayout,
          customValue: 1,
        ).toString(),
        equals('GamepadMappings(type: switchLayout, customValue: 1)'),
      );
    });
  });

  group('3.4 Controller Type, Subtype & Device Connection State Enums', () {
    test('maps Bluepad32ControllerType.fromValue including -1 and 0xFFFF', () {
      expect(
        Bluepad32ControllerType.fromValue(-1),
        Bluepad32ControllerType.none,
      );
      expect(
        Bluepad32ControllerType.fromValue(0xFFFF),
        Bluepad32ControllerType.none,
      );
      expect(
        Bluepad32ControllerType.fromValue(0),
        Bluepad32ControllerType.unknown,
      );
      expect(
        Bluepad32ControllerType.fromValue(32),
        Bluepad32ControllerType.xboxOneController,
      );
      expect(
        Bluepad32ControllerType.fromValue(34),
        Bluepad32ControllerType.ps4Controller,
      );
      expect(
        Bluepad32ControllerType.fromValue(38),
        Bluepad32ControllerType.switchProController,
      );
      expect(
        Bluepad32ControllerType.fromValue(44),
        Bluepad32ControllerType.xInputSwitchController,
      );
      expect(
        Bluepad32ControllerType.fromValue(45),
        Bluepad32ControllerType.ps5Controller,
      );
      expect(
        Bluepad32ControllerType.fromValue(400),
        Bluepad32ControllerType.genericKeyboard,
      );
      expect(
        Bluepad32ControllerType.fromValue(800),
        Bluepad32ControllerType.genericMouse,
      );
      expect(
        Bluepad32ControllerType.fromValue(9999),
        Bluepad32ControllerType.unknown,
      );
    });

    test('maps Bluepad32ControllerSubtype.fromValue for known and unknown values', () {
      expect(
        Bluepad32ControllerSubtype.fromValue(0),
        Bluepad32ControllerSubtype.none,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(1),
        Bluepad32ControllerSubtype.wiimoteHorizontal,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(4),
        Bluepad32ControllerSubtype.wiimoteNunchuk,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(7),
        Bluepad32ControllerSubtype.wiiClassic,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(8),
        Bluepad32ControllerSubtype.wiiUPro,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(9),
        Bluepad32ControllerSubtype.wiiBalanceBoard,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(10),
        Bluepad32ControllerSubtype.wiimoteUdrawTablet,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(20),
        Bluepad32ControllerSubtype.exampleOfNewGamepad,
      );
      expect(
        Bluepad32ControllerSubtype.fromValue(255),
        Bluepad32ControllerSubtype.unknown,
      );
    });

    test('maps Bluepad32DeviceState.fromValue and evaluates isReady', () {
      final Bluepad32DeviceState none = Bluepad32DeviceState.fromValue(0);
      expect(none, Bluepad32DeviceState.deviceNone);
      expect(none.isReady, isFalse);

      expect(
        Bluepad32DeviceState.fromValue(1),
        Bluepad32DeviceState.deviceDiscovered,
      );
      expect(
        Bluepad32DeviceState.fromValue(12),
        Bluepad32DeviceState.l2capInterruptConnected,
      );
      expect(
        Bluepad32DeviceState.fromValue(13),
        Bluepad32DeviceState.devicePendingReady,
      );

      final Bluepad32DeviceState ready = Bluepad32DeviceState.fromValue(14);
      expect(ready, Bluepad32DeviceState.deviceReady);
      expect(ready.isReady, isTrue);

      final Bluepad32DeviceState outOfRange = Bluepad32DeviceState.fromValue(99);
      expect(outOfRange, Bluepad32DeviceState.unknown);
      expect(outOfRange.isReady, isFalse);
    });

    test('label getters and icon switch branches', () {
      for (final Bluepad32ControllerType type in Bluepad32ControllerType.values) {
        expect(type.label, equals(type.displayName));
      }
      for (final Bluepad32ControllerSubtype subtype
          in Bluepad32ControllerSubtype.values) {
        expect(subtype.label, equals(subtype.displayName));
      }
      for (final Bluepad32DeviceState state in Bluepad32DeviceState.values) {
        expect(state.label, equals(state.displayName));
      }

      expect(Bluepad32ControllerType.genericKeyboard.icon, equals(Icons.keyboard));
      expect(Bluepad32ControllerType.genericMouse.icon, equals(Icons.mouse));
      expect(
        Bluepad32ControllerType.smartTvRemoteController.icon,
        equals(Icons.settings_remote),
      );
      expect(Bluepad32ControllerType.mobileTouch.icon, equals(Icons.touch_app));
      expect(Bluepad32ControllerType.none.icon, equals(Icons.help_outline));
      expect(Bluepad32ControllerType.unknown.icon, equals(Icons.help_outline));
      expect(
        Bluepad32ControllerType.ps5Controller.icon,
        equals(Icons.sports_esports),
      );
      expect(
        Bluepad32ControllerType.xboxOneController.icon,
        equals(Icons.sports_esports),
      );
      expect(
        Bluepad32ControllerType.switchProController.icon,
        equals(Icons.sports_esports),
      );
      expect(
        Bluepad32ControllerType.wiiController.icon,
        equals(Icons.sports_esports),
      );
    });
  });

  group('3.5 Bluepad32State.copyWith Immutability & Error Clearing', () {
    test('updates partial fields while preserving untouched state', () {
      const Bluepad32State initial = Bluepad32State(
        isConnected: true,
        bleEnabled: true,
      );

      final Bluepad32State updated = initial.copyWith(
        firmwareVersion: 'v4.2.0',
        maxConnections: 4,
        errorMessage: 'GATT timeout',
      );

      expect(updated.isConnected, isTrue);
      expect(updated.bleEnabled, isTrue);
      expect(updated.firmwareVersion, 'v4.2.0');
      expect(updated.maxConnections, 4);
      expect(updated.errorMessage, 'GATT timeout');
    });

    test('clears errorMessage when clearError is true', () {
      const Bluepad32State stateWithError = Bluepad32State(
        isConnected: true,
        firmwareVersion: 'v4.2.0',
        errorMessage: 'GATT write failed',
      );

      final Bluepad32State cleared = stateWithError.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
      expect(cleared.isConnected, isTrue);
      expect(cleared.firmwareVersion, 'v4.2.0');
    });

    test('Bluepad32State operator == and hashCode across nested lists and scalar fields', () {
      final ConnectedController slot0 = ConnectedController(
        idx: 0,
        address: MacAddress.parse('AA:BB:CC:11:22:33'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      final MacAddress mac = MacAddress.parse('AA:BB:CC:DD:EE:FF');

      final Bluepad32State s1 = Bluepad32State(
        isConnecting: false,
        isConnected: true,
        isRefreshing: false,
        errorMessage: null,
        firmwareVersion: 'v4.2.0',
        maxConnections: 4,
        bleEnabled: true,
        scanningEnabled: false,
        controllers: <ConnectedController>[slot0],
        mappings: const GamepadMappings(type: GamepadMappingsType.xbox),
        allowlistEnabled: true,
        allowlistAddresses: <MacAddress>[mac],
        virtualDevicesEnabled: true,
      );

      final Bluepad32State s2 = Bluepad32State(
        isConnecting: false,
        isConnected: true,
        isRefreshing: false,
        errorMessage: null,
        firmwareVersion: 'v4.2.0',
        maxConnections: 4,
        bleEnabled: true,
        scanningEnabled: false,
        controllers: <ConnectedController>[slot0],
        mappings: const GamepadMappings(type: GamepadMappingsType.xbox),
        allowlistEnabled: true,
        allowlistAddresses: <MacAddress>[mac],
        virtualDevicesEnabled: true,
      );

      expect(s1, equals(s1));
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1 == Object(), isFalse);

      expect(s1, isNot(equals(s1.copyWith(isConnecting: true))));
      expect(s1, isNot(equals(s1.copyWith(isConnected: false))));
      expect(s1, isNot(equals(s1.copyWith(isRefreshing: true))));
      expect(s1, isNot(equals(s1.copyWith(errorMessage: 'err'))));
      expect(s1, isNot(equals(s1.copyWith(firmwareVersion: 'v4.3.0'))));
      expect(s1, isNot(equals(s1.copyWith(maxConnections: 2))));
      expect(s1, isNot(equals(s1.copyWith(bleEnabled: false))));
      expect(s1, isNot(equals(s1.copyWith(scanningEnabled: true))));
      expect(
        s1,
        isNot(equals(s1.copyWith(controllers: const <ConnectedController>[]))),
      );
      expect(
        s1,
        isNot(
          equals(
            s1.copyWith(
              mappings: const GamepadMappings(
                type: GamepadMappingsType.switchLayout,
              ),
            ),
          ),
        ),
      );
      expect(s1, isNot(equals(s1.copyWith(allowlistEnabled: false))));
      expect(
        s1,
        isNot(equals(s1.copyWith(allowlistAddresses: const <MacAddress>[]))),
      );
      expect(s1, isNot(equals(s1.copyWith(virtualDevicesEnabled: false))));
    });
  });

  group('4.1 Bluepad32Client Service & Fake Characteristic Interaction', () {
    test('hydrates AC01..AC09 on connect() and merges 16-byte AC05 notifications', () async {
      final ConnectedController slot0 = ConnectedController(
        idx: 0,
        address: MacAddress.parse('AA:BB:CC:11:22:33'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );

      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
        firmwareVersion: 'v4.3.0',
        maxConnections: 4,
        bleEnabled: true,
        scanningEnabled: true,
        controllers: <ConnectedController>[
          slot0,
          ConnectedController.empty(1),
          ConnectedController.empty(2),
          ConnectedController.empty(3),
        ],
        mappings: const GamepadMappings(type: GamepadMappingsType.switchLayout),
        allowlistEnabled: true,
        allowlistAddresses: <MacAddress>[
          MacAddress.parse('AA:BB:CC:11:22:33'),
        ],
        virtualDevicesEnabled: false,
      );

      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(),
      );
      addTearDown(client.dispose);

      await client.connect();

      expect(transport.connectCallCount, 1);
      expect(client.state.isConnected, isTrue);
      expect(client.state.isConnecting, isFalse);
      expect(client.state.isRefreshing, isFalse);
      expect(client.state.errorMessage, isNull);
      expect(client.state.firmwareVersion, 'v4.3.0');
      expect(client.state.maxConnections, 4);
      expect(client.state.bleEnabled, isTrue);
      expect(client.state.scanningEnabled, isTrue);
      expect(client.state.mappings.type, GamepadMappingsType.switchLayout);
      expect(client.state.allowlistEnabled, isTrue);
      expect(client.state.allowlistAddresses, <MacAddress>[
        MacAddress.parse('AA:BB:CC:11:22:33'),
      ]);
      expect(client.state.virtualDevicesEnabled, isFalse);
      expect(client.state.controllers, hasLength(4));
      expect(client.state.activeControllers, hasLength(1));

      // Verify empty `[]` emission is ignored and does not wipe out controllers.
      transport.emitConnectedDevicesNotification(const <int>[]);
      await Future<void>.delayed(Duration.zero);
      expect(client.state.activeControllers, hasLength(1));
      expect(client.state.controllers[0], equals(slot0));

      // Verify a 16-byte single-slot notification for slot 2 updates only slot 2
      // without clobbering slot 0.
      final ConnectedController slot2Update = ConnectedController(
        idx: 2,
        address: MacAddress.parse('11:22:33:44:55:66'),
        vendorId: 0x057E,
        productId: 0x2009,
        state: Bluepad32DeviceState.deviceReady,
        incoming: false,
        controllerType: Bluepad32ControllerType.switchProController,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      transport.emitConnectedDevicesNotification(slot2Update.toBytes());
      await Future<void>.delayed(Duration.zero);

      expect(client.state.activeControllers, hasLength(2));
      expect(client.state.controllers[0], equals(slot0));
      expect(client.state.controllers[1].isConnected, isFalse);
      expect(client.state.controllers[2], equals(slot2Update));
      expect(client.state.controllers[3].isConnected, isFalse);
    });

    test('writes 6 zero bytes (00:00:00:00:00:00) to AC08 when clearing last allowlist MAC', () async {
      final MacAddress mac = MacAddress.parse('AA:BB:CC:DD:EE:FF');
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
        allowlistAddresses: <MacAddress>[mac],
      );
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: Bluepad32State(
          isConnected: true,
          allowlistAddresses: <MacAddress>[mac],
        ),
      );
      addTearDown(client.dispose);

      await client.removeAllowlistAddress(mac);

      expect(client.state.allowlistAddresses, isEmpty);
      final Uint8List? written =
          transport.lastWriteFor(Bluepad32Uuids.allowlistAddresses);
      expect(written, isNotNull);
      expect(written, hasLength(6));
      expect(written, equals(Uint8List(6)));
    });

    test('handles immediate disconnection exception on resetDevice() (AC0C) gracefully', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      transport.setWriteError(
        Bluepad32Uuids.resetDevice,
        (_) => FlutterBluePlusException(
          ErrorPlatform.fbp,
          'writeCharacteristic',
          FbpErrorCode.deviceIsDisconnected.index,
          'device is not connected',
        ),
      );

      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );
      addTearDown(client.dispose);

      await client.resetDevice();

      expect(
        transport.lastWriteFor(Bluepad32Uuids.resetDevice),
        equals(Uint8List.fromList(<int>[1])),
      );
      expect(client.state.isConnected, isFalse);
      expect(client.state.errorMessage, isNull);
    });

    test('executes GATT write actions for toggles, mappings, disconnect, and bond keys', () async {
      final ConnectedController occupiedSlot0 = ConnectedController(
        idx: 0,
        address: MacAddress.parse('AA:BB:CC:11:22:33'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
        controllers: <ConnectedController>[occupiedSlot0],
      );
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: Bluepad32State(
          isConnected: true,
          controllers: <ConnectedController>[occupiedSlot0],
        ),
      );
      addTearDown(client.dispose);

      await client.setBleEnabled(false);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.bleEnabled),
        equals(Uint8List.fromList(<int>[0])),
      );
      expect(client.state.bleEnabled, isFalse);

      await client.setControllerScanning(true);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.scanning),
        equals(Uint8List.fromList(<int>[1])),
      );
      expect(client.state.scanningEnabled, isTrue);

      await client.setMappingsType(GamepadMappingsType.switchLayout);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.mappings),
        equals(Uint8List.fromList(<int>[1])),
      );
      expect(client.state.mappings.type, GamepadMappingsType.switchLayout);

      await client.setAllowlistEnabled(true);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.allowlistEnabled),
        equals(Uint8List.fromList(<int>[1])),
      );
      expect(client.state.allowlistEnabled, isTrue);

      await client.setVirtualDevicesEnabled(false);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.virtualDeviceEnabled),
        equals(Uint8List.fromList(<int>[0])),
      );
      expect(client.state.virtualDevicesEnabled, isFalse);

      await client.disconnectController(0);
      expect(
        transport.lastWriteFor(Bluepad32Uuids.disconnectDevice),
        equals(Uint8List.fromList(<int>[0])),
      );
      expect(client.state.activeControllers, isEmpty);

      await client.deleteStoredBondKeys();
      expect(
        transport.lastWriteFor(Bluepad32Uuids.deleteStoredKeys),
        equals(Uint8List.fromList(<int>[1])),
      );
    });

    test('connect() failure sets errorMessage and resets isConnecting/isConnected', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport()
        ..connectError = FlutterBluePlusException(
          ErrorPlatform.fbp,
          'connect',
          1,
          'Connection timeout',
        );
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(),
      );
      addTearDown(client.dispose);

      await client.connect();

      expect(transport.connectCallCount, 1);
      expect(client.state.isConnecting, isFalse);
      expect(client.state.isConnected, isFalse);
      expect(
        client.state.errorMessage,
        contains('Failed to connect to Bluepad32 device: Connection timeout'),
      );
    });

    test('disconnect() failure sets errorMessage and transitions isConnected to false', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport()
        ..disconnectError = StateError('GATT link broken');
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );
      addTearDown(client.dispose);

      await client.disconnect();

      expect(transport.disconnectCallCount, 1);
      expect(client.state.isConnected, isFalse);
      expect(
        client.state.errorMessage,
        contains('Disconnect error: Bad state: GATT link broken'),
      );

      // Clear disconnectError and verify clean disconnect clears errorMessage.
      transport.disconnectError = null;
      await client.disconnect();
      expect(transport.disconnectCallCount, 2);
      expect(client.state.isConnected, isFalse);
      expect(client.state.errorMessage, isNull);
    });

    test('refreshAll() read error and fallback defaults for empty version / zero maxConnections', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      transport.setCharacteristicValue(
        Bluepad32Uuids.version,
        const <int>[0x00, 0x00],
      );
      transport.setCharacteristicValue(
        Bluepad32Uuids.maxConnections,
        const <int>[0],
      );

      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );
      addTearDown(client.dispose);

      await client.refreshAll();
      expect(client.state.firmwareVersion, equals('Unknown'));
      expect(client.state.maxConnections, equals(4));
      expect(client.state.errorMessage, isNull);

      transport.setReadError(
        Bluepad32Uuids.version,
        () => StateError('ATT read failed'),
      );
      await client.refreshAll();
      expect(client.state.isRefreshing, isFalse);
      expect(
        client.state.errorMessage,
        contains('Failed to read Bluepad32 state: Bad state: ATT read failed'),
      );

      transport.setReadError(Bluepad32Uuids.version, null);
      await client.refreshAll();
      expect(client.state.isRefreshing, isFalse);
      expect(client.state.errorMessage, isNull);
    });

    test('unsolicited connectionStateStream disconnect transitions state only when not connecting', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(
          isConnected: true,
          isConnecting: true,
        ),
      );
      addTearDown(client.dispose);

      // Emitting disconnected while isConnecting == true is ignored by race guard.
      transport.emitConnectionState(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);
      expect(client.state.isConnecting, isTrue);
      expect(client.state.isConnected, isTrue);

      // Once isConnecting == false, unsolicited disconnected transitions isConnected to false.
      client.updateStateForTesting(
        client.state.copyWith(isConnecting: false, isRefreshing: true),
      );
      transport.emitConnectionState(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);
      expect(client.state.isConnected, isFalse);
      expect(client.state.isRefreshing, isFalse);
    });

    test('write errors across AC03–AC0C preserve prior state and populate errorMessage', () async {
      final ConnectedController occupiedSlot0 = ConnectedController(
        idx: 0,
        address: MacAddress.parse('AA:BB:CC:11:22:33'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
        controllers: <ConnectedController>[occupiedSlot0],
      );
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: Bluepad32State(
          isConnected: true,
          bleEnabled: true,
          scanningEnabled: false,
          mappings: const GamepadMappings(type: GamepadMappingsType.xbox),
          allowlistEnabled: false,
          allowlistAddresses: const <MacAddress>[],
          virtualDevicesEnabled: true,
          controllers: <ConnectedController>[occupiedSlot0],
        ),
      );
      addTearDown(client.dispose);

      expect(transport.lastWriteFor(Bluepad32Uuids.bleEnabled), isNull);
      expect(transport.writesFor(Bluepad32Uuids.bleEnabled), isEmpty);

      // 1. AC03 setBleEnabled
      transport.setWriteError(
        Bluepad32Uuids.bleEnabled,
        (_) => StateError('AC03 rejected'),
      );
      await client.setBleEnabled(false);
      expect(client.state.bleEnabled, isTrue);
      expect(
        client.state.errorMessage,
        startsWith('Failed to update BLE setting:'),
      );
      transport.setWriteError(Bluepad32Uuids.bleEnabled, null);

      // 2. AC04 setScanningEnabled
      transport.setWriteError(
        Bluepad32Uuids.scanning,
        (_) => StateError('AC04 rejected'),
      );
      await client.setScanningEnabled(true);
      expect(client.state.scanningEnabled, isFalse);
      expect(
        client.state.errorMessage,
        startsWith('Failed to update controller scanning:'),
      );

      // 3. AC06 setMappingsType
      transport.setWriteError(
        Bluepad32Uuids.mappings,
        (_) => StateError('AC06 rejected'),
      );
      await client.setMappingsType(GamepadMappingsType.switchLayout);
      expect(client.state.mappings.type, equals(GamepadMappingsType.xbox));
      expect(
        client.state.errorMessage,
        startsWith('Failed to update controller mappings:'),
      );

      // 4. AC07 setAllowlistEnabled
      transport.setWriteError(
        Bluepad32Uuids.allowlistEnabled,
        (_) => StateError('AC07 rejected'),
      );
      await client.setAllowlistEnabled(true);
      expect(client.state.allowlistEnabled, isFalse);
      expect(
        client.state.errorMessage,
        startsWith('Failed to update allowlist enforcement:'),
      );

      // 5. AC08 setAllowlistAddresses
      transport.setWriteError(
        Bluepad32Uuids.allowlistAddresses,
        (_) => StateError('AC08 rejected'),
      );
      await client.setAllowlistAddresses(<MacAddress>[
        MacAddress.parse('AA:BB:CC:DD:EE:FF'),
      ]);
      expect(client.state.allowlistAddresses, isEmpty);
      expect(
        client.state.errorMessage,
        startsWith('Failed to update allowlist addresses:'),
      );

      // 6. AC09 setVirtualDevicesEnabled
      transport.setWriteError(
        Bluepad32Uuids.virtualDeviceEnabled,
        (_) => StateError('AC09 rejected'),
      );
      await client.setVirtualDevicesEnabled(false);
      expect(client.state.virtualDevicesEnabled, isTrue);
      expect(
        client.state.errorMessage,
        startsWith('Failed to update virtual devices setting:'),
      );

      // 7. AC0A disconnectDevice
      transport.setWriteError(
        Bluepad32Uuids.disconnectDevice,
        (_) => StateError('AC0A rejected'),
      );
      await client.disconnectDevice(0);
      expect(client.state.activeControllers, hasLength(1));
      expect(
        client.state.errorMessage,
        startsWith('Failed to disconnect controller #0:'),
      );

      // 8. AC0B deleteStoredKeys
      transport.setWriteError(
        Bluepad32Uuids.deleteStoredKeys,
        (_) => StateError('AC0B rejected'),
      );
      await client.deleteStoredKeys();
      expect(
        client.state.errorMessage,
        startsWith('Failed to delete stored bond keys:'),
      );

      // 9. AC0C resetDevice with non-disconnection exception
      transport.setWriteError(
        Bluepad32Uuids.resetDevice,
        (_) => StateError('Write rejected by security'),
      );
      await client.resetDevice();
      expect(client.state.isConnected, isTrue);
      expect(
        client.state.errorMessage,
        startsWith('Failed to reset device:'),
      );
    });

    test('resetDevice() treats string-matched disconnection exceptions and clean write as expected reboot', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );
      addTearDown(client.dispose);

      // 1. Clean write without exception
      await client.resetDevice();
      expect(client.state.isConnected, isFalse);
      expect(client.state.errorMessage, isNull);

      // 2. FlutterBluePlusException with non-deviceIsDisconnected code but 'not connected' description
      client.updateStateForTesting(
        client.state.copyWith(isConnected: true, errorMessage: 'old'),
      );
      transport.setWriteError(
        Bluepad32Uuids.resetDevice,
        (_) => FlutterBluePlusException(
          ErrorPlatform.fbp,
          'write',
          999,
          'Peripheral is not connected',
        ),
      );
      await client.resetDevice();
      expect(client.state.isConnected, isFalse);
      expect(client.state.errorMessage, isNull);

      // 3. Generic Exception containing 'disconnected'
      client.updateStateForTesting(
        client.state.copyWith(isConnected: true, errorMessage: 'old'),
      );
      transport.setWriteError(
        Bluepad32Uuids.resetDevice,
        (_) => Exception('GATT link disconnected'),
      );
      await client.resetDevice();
      expect(client.state.isConnected, isFalse);
      expect(client.state.errorMessage, isNull);
    });

    test('allowlist guards: zero MAC rejection, duplicate no-op, and deduplication', () async {
      final MacAddress macA = MacAddress.parse('AA:BB:CC:DD:EE:01');
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );
      addTearDown(client.dispose);

      // Zero MAC is rejected without writing to AC08
      await client.addAllowlistAddress(MacAddress.zero);
      expect(
        client.state.errorMessage,
        equals(
          'Cannot add all-zero MAC address (00:00:00:00:00:00) to allowlist.',
        ),
      );
      expect(transport.writesFor(Bluepad32Uuids.allowlistAddresses), isEmpty);

      // Add macA
      await client.addAllowlistAddress(macA);
      expect(client.state.allowlistAddresses, equals(<MacAddress>[macA]));
      expect(
        transport.writesFor(Bluepad32Uuids.allowlistAddresses),
        hasLength(1),
      );

      // Adding duplicate macA is a no-op
      await client.addAllowlistAddress(macA);
      expect(
        transport.writesFor(Bluepad32Uuids.allowlistAddresses),
        hasLength(1),
      );

      // setAllowlistAddresses deduplicates and strips MacAddress.zero
      await client.setAllowlistAddresses(<MacAddress>[
        macA,
        MacAddress.zero,
        macA,
      ]);
      expect(client.state.allowlistAddresses, equals(<MacAddress>[macA]));
      expect(
        transport.lastWriteFor(Bluepad32Uuids.allowlistAddresses),
        equals(macA.toBytes()),
      );
    });

    test('clearError, updateStateForTesting, transport getter, and post-dispose safety', () async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(isConnected: true),
      );

      expect(client.transport, same(transport));

      int listenerNotifications = 0;
      client.addListener(() {
        listenerNotifications++;
      });

      // clearError is a no-op when errorMessage is null
      client.clearError();
      expect(listenerNotifications, 0);

      client.updateStateForTesting(
        client.state.copyWith(errorMessage: 'Some error'),
      );
      expect(client.state.errorMessage, equals('Some error'));
      expect(listenerNotifications, 1);

      client.clearError();
      expect(client.state.errorMessage, isNull);
      expect(listenerNotifications, 2);

      // Dispose client and verify post-dispose state updates are ignored safely
      client.dispose();
      client.updateStateForTesting(
        client.state.copyWith(firmwareVersion: 'v9.9.9'),
      );
      transport.emitConnectedDevicesNotification(
        ConnectedController.empty(0).toBytes(),
      );
      transport.emitConnectionState(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(listenerNotifications, 2);
      expect(client.state.firmwareVersion, isNull);
    });

    test('Bluepad32Client(device: ...) exercises _DeviceBluepad32GattTransport discovery, read/write, notifications, and missing service/characteristic errors', () async {
      final _FakeGattBluetoothDevice device = _FakeGattBluetoothDevice(
        id: 'AA:BB:CC:DD:EE:10',
      );
      final Bluepad32Client client = Bluepad32Client(device: device);
      addTearDown(client.dispose);

      // 1. Before connect(), reading or writing characteristics fails with unavailable characteristic StateError
      await client.refreshAll();
      expect(
        client.state.errorMessage,
        contains('GATT characteristic ${Bluepad32Uuids.version} is not available.'),
      );
      await client.setBleEnabled(true);
      expect(
        client.state.errorMessage,
        contains('GATT characteristic ${Bluepad32Uuids.bleEnabled} is not available.'),
      );

      // 2. When discoverServices() returns only an unrelated service, connect() reports missing Bluepad32 service
      device.servicesToReturn = <BluetoothService>[
        _FakeBluetoothService(
          remoteId: device.remoteId,
          serviceUuid: Guid('1800'),
          characteristics: const <BluetoothCharacteristic>[],
        ),
      ];
      await client.connect();
      expect(client.state.isConnected, isFalse);
      expect(
        client.state.errorMessage,
        contains('Bluepad32 GATT service (${Bluepad32Uuids.service}) not found on device.'),
      );

      // 3. Populate Bluepad32 service with AC01..AC09 characteristics and verify connect(), notifications, write, and disconnect()
      final Map<Guid, _FakeBluetoothCharacteristic> chars =
          <Guid, _FakeBluetoothCharacteristic>{};
      for (final Guid uuid in Bluepad32Uuids.allCharacteristics) {
        chars[uuid] = _FakeBluetoothCharacteristic(
          remoteId: device.remoteId,
          serviceUuid: Bluepad32Uuids.service,
          characteristicUuid: uuid,
        );
      }
      chars[Bluepad32Uuids.version]!.valueToRead = utf8.encode('v4.4.0');
      chars[Bluepad32Uuids.maxConnections]!.valueToRead = <int>[4];
      chars[Bluepad32Uuids.bleEnabled]!.valueToRead = <int>[1];
      chars[Bluepad32Uuids.scanning]!.valueToRead = <int>[0];
      chars[Bluepad32Uuids.connectedDevices]!.valueToRead =
          ConnectedController.empty(0).toBytes();
      chars[Bluepad32Uuids.mappings]!.valueToRead = <int>[0];
      chars[Bluepad32Uuids.allowlistEnabled]!.valueToRead = <int>[0];
      chars[Bluepad32Uuids.allowlistAddresses]!.valueToRead = const <int>[];
      chars[Bluepad32Uuids.virtualDeviceEnabled]!.valueToRead = <int>[1];

      device.servicesToReturn = <BluetoothService>[
        _FakeBluetoothService(
          remoteId: device.remoteId,
          serviceUuid: Bluepad32Uuids.service,
          characteristics: chars.values.toList(),
        ),
      ];

      await client.connect();
      expect(client.state.isConnected, isTrue);
      expect(client.state.firmwareVersion, equals('v4.4.0'));
      expect(chars[Bluepad32Uuids.connectedDevices]!.notifyEnabled, isTrue);

      // Emit an AC05 notification over onValueReceived
      final ConnectedController slot1 = ConnectedController(
        idx: 1,
        address: MacAddress.parse('11:22:33:44:55:66'),
        vendorId: 0x054C,
        productId: 0x0CE6,
        state: Bluepad32DeviceState.deviceReady,
        incoming: true,
        controllerType: Bluepad32ControllerType.ps5Controller,
        controllerSubtype: Bluepad32ControllerSubtype.none,
      );
      chars[Bluepad32Uuids.connectedDevices]!.emitNotification(slot1.toBytes());
      await Future<void>.delayed(Duration.zero);
      expect(client.state.activeControllers, hasLength(1));
      expect(client.state.controllers[1], equals(slot1));

      // Write AC03 via _DeviceBluepad32GattTransport.writeCharacteristic
      await client.setBleEnabled(false);
      expect(
        chars[Bluepad32Uuids.bleEnabled]!.lastWrittenValue,
        equals(<int>[0]),
      );

      // Disconnect via _DeviceBluepad32GattTransport.disconnect
      await client.disconnect();
      expect(client.state.isConnected, isFalse);
      await chars[Bluepad32Uuids.connectedDevices]!.disposeController();
    });
  });
}

/// In-memory [BluetoothDevice] test double that stubs `connect`, `disconnect`,
/// `discoverServices`, and `cancelWhenDisconnected` to exercise the production
/// `_DeviceBluepad32GattTransport` without platform channels.
class _FakeGattBluetoothDevice extends BluetoothDevice {
  _FakeGattBluetoothDevice({required String id})
      : super(remoteId: DeviceIdentifier(id));

  final StreamController<BluetoothConnectionState> _connectionController =
      StreamController<BluetoothConnectionState>.broadcast();

  /// Services returned by [discoverServices] during connection setup.
  List<BluetoothService> servicesToReturn = const <BluetoothService>[];

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionController.stream;

  @override
  Future<void> connect({
    required License license,
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    _connectionController.add(BluetoothConnectionState.connected);
  }

  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    _connectionController.add(BluetoothConnectionState.disconnected);
  }

  @override
  Future<List<BluetoothService>> discoverServices({
    bool subscribeToServicesChanged = true,
    int timeout = 15,
  }) async {
    return servicesToReturn;
  }

  @override
  void cancelWhenDisconnected(
    StreamSubscription<dynamic> subscription, {
    bool next = false,
    bool delayed = false,
  }) {}
}

/// Minimal [BluetoothService] fake exposing a configurable [serviceUuid] and
/// [characteristics] list for GATT service discovery tests.
class _FakeBluetoothService implements BluetoothService {
  _FakeBluetoothService({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristics,
  });

  @override
  final DeviceIdentifier remoteId;

  @override
  final Guid serviceUuid;

  @override
  final List<BluetoothCharacteristic> characteristics;

  @override
  Guid get uuid => serviceUuid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory [BluetoothCharacteristic] fake that records ATT writes, serves
/// seeded [valueToRead] payloads, and emits simulated notifications on
/// [onValueReceived].
class _FakeBluetoothCharacteristic extends BluetoothCharacteristic {
  _FakeBluetoothCharacteristic({
    required super.remoteId,
    required super.serviceUuid,
    required super.characteristicUuid,
  });

  final StreamController<List<int>> _valueController =
      StreamController<List<int>>.broadcast();

  /// Bytes returned when [read] is called on this characteristic.
  List<int> valueToRead = const <int>[];

  /// Most recent byte payload passed to [write], or `null` if never written.
  List<int>? lastWrittenValue;

  /// Whether notifications were enabled via [setNotifyValue].
  bool notifyEnabled = false;

  /// Pushes a simulated GATT notification payload onto [onValueReceived].
  void emitNotification(List<int> bytes) {
    _valueController.add(bytes);
  }

  /// Closes the internal notification stream controller.
  Future<void> disposeController() => _valueController.close();

  @override
  Stream<List<int>> get onValueReceived => _valueController.stream;

  @override
  Future<bool> setNotifyValue(
    bool notify, {
    int timeout = 15,
    bool forceIndications = false,
  }) async {
    notifyEnabled = notify;
    return true;
  }

  @override
  Future<List<int>> read({int timeout = 15}) async => valueToRead;

  @override
  Future<void> write(
    List<int> value, {
    bool withoutResponse = false,
    bool allowLongWrite = false,
    int timeout = 15,
  }) async {
    lastWrittenValue = List<int>.from(value);
  }
}
