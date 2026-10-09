import 'dart:typed_data';

import 'package:bluepad32_client/services/bluepad32_client.dart';
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

      expect(initial.toBytes(), equals(Uint8List.fromList(<int>[0])));
      expect(updated.toBytes(), equals(Uint8List.fromList(<int>[1])));
      expect(initial, isNot(equals(updated)));
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
  });
}
