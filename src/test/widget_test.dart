/// Widget tests for root application routing ([FlutterBlueApp]),
/// [BluetoothOffScreen], [BluetoothAdapterStateObserver], and top-level
/// [DeviceScreen] error banner and AppBar connection controls.
///
/// Injects synthetic [BluetoothAdapterState] streams and [FakeBluepad32GattTransport]
/// instances so adapter state transitions and `/DeviceScreen` auto-pop behavior
/// can be verified deterministically in headless tests.
library;

import 'dart:async';

import 'package:bluepad32_client/main.dart';
import 'package:bluepad32_client/screens/bluetooth_off_screen.dart';
import 'package:bluepad32_client/screens/device_screen.dart';
import 'package:bluepad32_client/screens/scan_screen.dart';
import 'package:bluepad32_client/services/bluepad32_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FlutterBlueApp renders BluetoothOffScreen when adapter is off',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        FlutterBlueApp(
          adapterStateStream: Stream<BluetoothAdapterState>.value(
            BluetoothAdapterState.off,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BluetoothOffScreen), findsOneWidget);
      expect(find.textContaining('Bluetooth Adapter is off'), findsOneWidget);
    },
  );

  testWidgets(
    'BluetoothOffScreen null adapterState fallback and buildTurnOnButton',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BluetoothOffScreen(),
        ),
      );
      expect(
        find.text('Bluetooth Adapter is not available'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) =>
                  const BluetoothOffScreen().buildTurnOnButton(context),
            ),
          ),
        ),
      );
      expect(find.text('TURN ON'), findsOneWidget);
      await tester.tap(find.text('TURN ON'));
      await tester.pump();
    },
  );

  testWidgets(
    'FlutterBlueApp routes to ScanScreen when adapter is on and BluetoothAdapterStateObserver pops /DeviceScreen on adapter off',
    (WidgetTester tester) async {
      final StreamController<BluetoothAdapterState> adapterController =
          StreamController<BluetoothAdapterState>.broadcast();
      addTearDown(adapterController.close);

      await tester.pumpWidget(
        FlutterBlueApp(
          adapterStateStream: adapterController.stream,
          scanScreenBuilder: (BuildContext context) => Scaffold(
            appBar: AppBar(title: const Text('MockScanScreen')),
            body: Builder(
              builder: (BuildContext innerContext) => ElevatedButton(
                onPressed: () {
                  Navigator.of(innerContext).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: '/DeviceScreen'),
                      builder: (_) => const Scaffold(
                        body: Text('ActiveDeviceScreen'),
                      ),
                    ),
                  );
                },
                child: const Text('PushDeviceScreen'),
              ),
            ),
          ),
        ),
      );

      // Verify stream errors are ignored gracefully.
      adapterController.addError(Exception('platform-error'));
      await tester.pump();

      // Transition adapter to on -> renders ScanScreen builder.
      adapterController.add(BluetoothAdapterState.on);
      await tester.pumpAndSettle();
      expect(find.text('MockScanScreen'), findsOneWidget);

      // Push /DeviceScreen route.
      await tester.tap(find.text('PushDeviceScreen'));
      await tester.pumpAndSettle();
      expect(find.text('ActiveDeviceScreen'), findsOneWidget);

      // Emit BluetoothAdapterState.off -> BluetoothAdapterStateObserver pops /DeviceScreen.
      adapterController.add(BluetoothAdapterState.off);
      await tester.pumpAndSettle();
      expect(find.text('ActiveDeviceScreen'), findsNothing);
      expect(find.byType(BluetoothOffScreen), findsOneWidget);

      // Also verify default ScanScreen construction when scanScreenBuilder is omitted.
      await tester.pumpWidget(
        FlutterBlueApp(
          key: UniqueKey(),
          adapterStateStream: Stream<BluetoothAdapterState>.value(
            BluetoothAdapterState.on,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ScanScreen), findsOneWidget);
    },
  );

  testWidgets(
    'DeviceScreen displays and dismisses error banner and supports Connect/Disconnect',
    (WidgetTester tester) async {
      final FakeBluepad32GattTransport transport = FakeBluepad32GattTransport(
        firmwareVersion: 'v4.2.0',
      );
      final Bluepad32Client client = Bluepad32Client.test(
        transport: transport,
        initialState: const Bluepad32State(
          isConnected: true,
          firmwareVersion: 'v4.2.0',
          errorMessage: 'Simulated GATT write error',
        ),
      );
      addTearDown(client.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E88E5),
            ),
          ),
          home: DeviceScreen(client: client),
        ),
      );

      expect(find.text('Simulated GATT write error'), findsOneWidget);

      await tester.tap(find.byKey(const Key('dismiss_error_button')));
      await tester.pumpAndSettle();

      expect(find.text('Simulated GATT write error'), findsNothing);
      expect(client.state.errorMessage, isNull);

      // Tap Disconnect in AppBar.
      await tester.tap(find.byKey(const Key('appbar_disconnect_button')));
      await tester.pumpAndSettle();

      expect(client.state.isConnected, isFalse);
      expect(find.text('Disconnected'), findsOneWidget);

      // Tap Connect in AppBar.
      await tester.tap(find.byKey(const Key('appbar_connect_button')));
      await tester.pumpAndSettle();

      expect(client.state.isConnected, isTrue);
      expect(find.text('Connected'), findsOneWidget);
    },
  );

  test('BluetoothAdapterState enum sanity check', () {
    expect(BluetoothAdapterState.on, isNot(equals(BluetoothAdapterState.off)));
  });
}
