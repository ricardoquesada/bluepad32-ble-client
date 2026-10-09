import 'package:bluepad32_client/main.dart';
import 'package:bluepad32_client/screens/bluetooth_off_screen.dart';
import 'package:bluepad32_client/screens/device_screen.dart';
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
