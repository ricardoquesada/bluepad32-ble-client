import 'dart:typed_data';

import 'package:bluepad32_client/screens/device_screen.dart';
import 'package:bluepad32_client/services/bluepad32_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithMaterial3(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E88E5),
      ),
    ),
    home: child,
  );
}

void main() {
  group('4.2 Material 3 Dashboard Widget Tests', () {
    testWidgets(
      '1. System Info Card renders firmware version, connection badge, active controller count (2 / 4), and triggers refreshAll()',
      (WidgetTester tester) async {
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
        final ConnectedController slot2 = ConnectedController(
          idx: 2,
          address: MacAddress.parse('11:22:33:44:55:66'),
          vendorId: 0x057E,
          productId: 0x2009,
          state: Bluepad32DeviceState.deviceReady,
          incoming: false,
          controllerType: Bluepad32ControllerType.switchProController,
          controllerSubtype: Bluepad32ControllerSubtype.none,
        );

        final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
          firmwareVersion: 'v4.2.0',
          maxConnections: 4,
          controllers: <ConnectedController>[
            slot0,
            ConnectedController.empty(1),
            slot2,
            ConnectedController.empty(3),
          ],
        );

        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: Bluepad32State(
            isConnected: true,
            firmwareVersion: 'v4.2.0',
            maxConnections: 4,
            controllers: <ConnectedController>[
              slot0,
              ConnectedController.empty(1),
              slot2,
              ConnectedController.empty(3),
            ],
          ),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        expect(find.text('v4.2.0'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('2 / 4'), findsOneWidget);

        // Update fake firmware version and tap refresh button to verify refreshAll() runs.
        transport.setCharacteristicValue(
          Bluepad32Uuids.version,
          'v4.3.1'.codeUnits,
        );
        final Finder refreshButton = find.byKey(
          const Key('system_info_refresh_button'),
        );
        await tester.tap(refreshButton);
        await tester.pumpAndSettle();

        expect(transport.readCounts[Bluepad32Uuids.version], 1);
        expect(find.text('v4.3.1'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Connected Controllers Card renders PS5 DualSense metadata and invokes disconnectController(0) (AC0A)',
      (WidgetTester tester) async {
        final ConnectedController ps5Controller = ConnectedController(
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
          controllers: <ConnectedController>[
            ps5Controller,
            ConnectedController.empty(1),
            ConnectedController.empty(2),
            ConnectedController.empty(3),
          ],
        );

        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: Bluepad32State(
            isConnected: true,
            firmwareVersion: 'v4.2.0',
            maxConnections: 4,
            controllers: <ConnectedController>[
              ps5Controller,
              ConnectedController.empty(1),
              ConnectedController.empty(2),
              ConnectedController.empty(3),
            ],
          ),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        expect(find.text('PlayStation DualSense (PS5)'), findsOneWidget);
        expect(find.text('AA:BB:CC:11:22:33'), findsOneWidget);
        expect(find.text('054C:0CE6'), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Incoming'), findsOneWidget);

        final Finder disconnectBtn = find.byKey(
          const Key('disconnect_controller_0'),
        );
        expect(disconnectBtn, findsOneWidget);

        await tester.tap(disconnectBtn);
        await tester.pumpAndSettle();

        expect(
          transport.lastWriteFor(Bluepad32Uuids.disconnectDevice),
          equals(Uint8List.fromList(<int>[0])),
        );
        expect(find.text('No controllers connected'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Connections & Security Card toggles BLE (AC03), Scanning (AC04), and Enforce Allowlist (AC07)',
      (WidgetTester tester) async {
        final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
          bleEnabled: true,
          scanningEnabled: false,
          allowlistEnabled: false,
        );
        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: const Bluepad32State(
            isConnected: true,
            bleEnabled: true,
            scanningEnabled: false,
            allowlistEnabled: false,
          ),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        final Finder bleSwitch = find.text('BLE Connections Enabled');
        await tester.ensureVisible(bleSwitch);
        await tester.tap(bleSwitch);
        await tester.pumpAndSettle();
        expect(
          transport.lastWriteFor(Bluepad32Uuids.bleEnabled),
          equals(Uint8List.fromList(<int>[0])),
        );
        expect(client.state.bleEnabled, isFalse);

        final Finder scanSwitch = find.text('Scan / Pair New Controllers');
        await tester.ensureVisible(scanSwitch);
        await tester.tap(scanSwitch);
        await tester.pumpAndSettle();
        expect(
          transport.lastWriteFor(Bluepad32Uuids.scanning),
          equals(Uint8List.fromList(<int>[1])),
        );
        expect(client.state.scanningEnabled, isTrue);

        final Finder allowlistSwitch = find.text('Enforce Allowlist');
        await tester.ensureVisible(allowlistSwitch);
        await tester.tap(allowlistSwitch);
        await tester.pumpAndSettle();
        expect(
          transport.lastWriteFor(Bluepad32Uuids.allowlistEnabled),
          equals(Uint8List.fromList(<int>[1])),
        );
        expect(client.state.allowlistEnabled, isTrue);
      },
    );

    testWidgets(
      '4. Allowlist Manager Card validates MAC format, normalizes lowercase input, and supports add/remove (AC08)',
      (WidgetTester tester) async {
        final MacAddress existingMac = MacAddress.parse('11:22:33:44:55:66');
        final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
          allowlistAddresses: <MacAddress>[existingMac],
        );
        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: Bluepad32State(
            isConnected: true,
            allowlistEnabled: true,
            allowlistAddresses: <MacAddress>[existingMac],
          ),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        final Finder addButton = find.byKey(const Key('add_mac_address_button'));
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Enter invalid MAC and try to submit.
        final Finder textField = find.byKey(const Key('mac_address_text_field'));
        final Finder confirmAddButton = find.byKey(
          const Key('confirm_add_mac_button'),
        );
        await tester.enterText(textField, 'invalid-mac');
        await tester.tap(confirmAddButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Invalid MAC format. Use AA:BB:CC:DD:EE:FF.'),
          findsOneWidget,
        );
        expect(
          transport.writesFor(Bluepad32Uuids.allowlistAddresses),
          isEmpty,
        );

        // Enter valid lowercase MAC and submit.
        await tester.enterText(textField, 'aa:bb:cc:dd:ee:ff');
        await tester.tap(confirmAddButton);
        await tester.pumpAndSettle();

        expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
        expect(client.state.allowlistAddresses, <MacAddress>[
          existingMac,
          MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        ]);
        expect(
          transport.lastWriteFor(Bluepad32Uuids.allowlistAddresses),
          hasLength(12),
        );

        // Delete the newly added MAC address.
        final Finder deleteButton = find.byKey(
          const Key('delete_mac_AA:BB:CC:DD:EE:FF'),
        );
        await tester.ensureVisible(deleteButton);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        expect(find.text('AA:BB:CC:DD:EE:FF'), findsNothing);
        expect(client.state.allowlistAddresses, <MacAddress>[existingMac]);
      },
    );

    testWidgets(
      '5. Virtual Device & Mappings Card toggles Virtual Devices (AC09) and selects Xbox / Switch / Custom mappings (AC06)',
      (WidgetTester tester) async {
        final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
          virtualDevicesEnabled: true,
          mappings: const GamepadMappings(type: GamepadMappingsType.xbox),
        );
        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: const Bluepad32State(
            isConnected: true,
            virtualDevicesEnabled: true,
            mappings: GamepadMappings(type: GamepadMappingsType.xbox),
          ),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        final Finder virtualSwitch = find.text('Virtual Devices Enabled');
        await tester.ensureVisible(virtualSwitch);
        await tester.pumpAndSettle();
        await tester.tap(virtualSwitch);
        await tester.pumpAndSettle();

        expect(
          transport.lastWriteFor(Bluepad32Uuids.virtualDeviceEnabled),
          equals(Uint8List.fromList(<int>[0])),
        );
        expect(client.state.virtualDevicesEnabled, isFalse);

        // Select Nintendo Switch mappings (1).
        final Finder switchOption = find.text('Nintendo Switch');
        await tester.ensureVisible(switchOption);
        await tester.pumpAndSettle();
        await tester.tap(switchOption);
        await tester.pumpAndSettle();

        expect(
          transport.lastWriteFor(Bluepad32Uuids.mappings),
          equals(Uint8List.fromList(<int>[1])),
        );
        expect(client.state.mappings.type, GamepadMappingsType.switchLayout);

        // Select Custom mappings (2).
        final Finder customOption = find.text('Custom');
        await tester.ensureVisible(customOption);
        await tester.pumpAndSettle();
        await tester.tap(customOption);
        await tester.pumpAndSettle();

        expect(
          transport.lastWriteFor(Bluepad32Uuids.mappings),
          equals(Uint8List.fromList(<int>[2])),
        );
        expect(client.state.mappings.type, GamepadMappingsType.custom);
      },
    );

    testWidgets(
      '6. Danger Zone Card guards Delete Stored Bond Keys (AC0B) and Reset / Reboot Device (AC0C) with confirmation dialogs',
      (WidgetTester tester) async {
        final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport();
        final Bluepad32Client client = Bluepad32Client.test(
          transport: transport,
          initialState: const Bluepad32State(isConnected: true),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          _wrapWithMaterial3(DeviceScreen(client: client)),
        );

        final Finder deleteBondKeysBtn = find.byKey(
          const Key('delete_bond_keys_button'),
        );
        await tester.ensureVisible(deleteBondKeysBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteBondKeysBtn);
        await tester.pumpAndSettle();

        expect(find.text('Delete Stored Bond Keys?'), findsOneWidget);

        // Cancel first: verify no GATT write is sent.
        await tester.tap(find.byKey(const Key('cancel_delete_bond_keys_button')));
        await tester.pumpAndSettle();
        expect(
          transport.writesFor(Bluepad32Uuids.deleteStoredKeys),
          isEmpty,
        );

        // Re-open and confirm Delete Keys.
        await tester.tap(deleteBondKeysBtn);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('confirm_delete_bond_keys_button')),
        );
        await tester.pumpAndSettle();
        expect(
          transport.lastWriteFor(Bluepad32Uuids.deleteStoredKeys),
          equals(Uint8List.fromList(<int>[1])),
        );

        // Test Reset / Reboot Device confirmation dialog.
        final Finder resetDeviceBtn = find.byKey(
          const Key('reset_device_button'),
        );
        await tester.ensureVisible(resetDeviceBtn);
        await tester.tap(resetDeviceBtn);
        await tester.pumpAndSettle();

        expect(find.text('Reset / Reboot Device?'), findsOneWidget);

        // Cancel first: verify no GATT write is sent.
        await tester.tap(find.byKey(const Key('cancel_reset_device_button')));
        await tester.pumpAndSettle();
        expect(transport.writesFor(Bluepad32Uuids.resetDevice), isEmpty);

        // Re-open and confirm Reboot.
        await tester.tap(resetDeviceBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_reset_device_button')));
        await tester.pumpAndSettle();

        expect(
          transport.lastWriteFor(Bluepad32Uuids.resetDevice),
          equals(Uint8List.fromList(<int>[1])),
        );
        expect(client.state.isConnected, isFalse);
      },
    );
  });
}
