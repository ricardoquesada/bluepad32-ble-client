/// Widget and unit tests for BLE peripheral discovery ([ScanScreen]),
/// advertisement tiles ([ScanResultTile]), and system-connected device tiles
/// ([SystemDeviceTile]).
///
/// Exercises [ScanScreen]'s injected stream and callback seams to verify
/// Bluepad32 UUID/name heuristic detection, filter chip toggling, RSSI priority
/// sorting, pull-to-refresh timer completion, `/DeviceScreen` navigation, and
/// error [SnackBar] reporting without native BLE hardware.
library;

import 'dart:async';

import 'package:bluepad32_client/models/bluepad32_uuids.dart';
import 'package:bluepad32_client/screens/scan_screen.dart';
import 'package:bluepad32_client/widgets/scan_result_tile.dart';
import 'package:bluepad32_client/widgets/system_device_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [BluetoothDevice] test double that overrides [platformName] and
/// [connectionState] without invoking native `flutter_blue_plus` channels.
class TestBluetoothDevice extends BluetoothDevice {
  /// Creates a [TestBluetoothDevice] with the given remote [id] and optional
  /// [testPlatformName] and [connectionStateStream].
  TestBluetoothDevice({
    required String id,
    this.testPlatformName = '',
    Stream<BluetoothConnectionState>? connectionStateStream,
  })  : _connectionStateStream = connectionStateStream ??
            Stream<BluetoothConnectionState>.value(
              BluetoothConnectionState.disconnected,
            ),
        super(remoteId: DeviceIdentifier(id));

  /// Simulated OS-cached device name returned by [platformName].
  final String testPlatformName;
  final Stream<BluetoothConnectionState> _connectionStateStream;

  @override
  String get platformName => testPlatformName;

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateStream;
}

/// Constructs a synthetic [ScanResult] backed by a [TestBluetoothDevice] and
/// configurable [AdvertisementData] for discovery and tile tests.
ScanResult _makeScanResult({
  required String id,
  String platformName = '',
  String advName = '',
  int rssi = -60,
  bool connectable = true,
  int? txPowerLevel,
  int? appearance,
  Map<int, List<int>> manufacturerData = const <int, List<int>>{},
  Map<Guid, List<int>> serviceData = const <Guid, List<int>>{},
  List<Guid> serviceUuids = const <Guid>[],
  Stream<BluetoothConnectionState>? connectionStateStream,
}) {
  return ScanResult(
    device: TestBluetoothDevice(
      id: id,
      testPlatformName: platformName,
      connectionStateStream: connectionStateStream,
    ),
    advertisementData: AdvertisementData(
      advName: advName,
      txPowerLevel: txPowerLevel,
      appearance: appearance,
      connectable: connectable,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: serviceUuids,
    ),
    rssi: rssi,
    timeStamp: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Wraps [child] in a Material 3 [MaterialApp] and [Scaffold] for isolated tile tests.
Widget _wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E88E5),
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('3.1 ScanResultTile Detection & Widget Rendering', () {
    test(
      'ScanResultTile.isBluepad32Peripheral identifies service UUID, platformName, and advName',
      () {
        final ScanResult byUuid = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:01',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        expect(ScanResultTile.isBluepad32Peripheral(byUuid), isTrue);

        final ScanResult byPlatformName = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:02',
          platformName: 'Bluepad32-ESP32',
        );
        expect(ScanResultTile.isBluepad32Peripheral(byPlatformName), isTrue);

        final ScanResult byAdvName = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:03',
          advName: 'my-bluepad32-host',
        );
        expect(ScanResultTile.isBluepad32Peripheral(byAdvName), isTrue);

        final ScanResult unrelated = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:04',
          platformName: 'HeartRateMonitor',
          advName: 'HRM-Pro',
          serviceUuids: <Guid>[Guid('180d')],
        );
        expect(ScanResultTile.isBluepad32Peripheral(unrelated), isFalse);
      },
    );

    testWidgets(
      'ScanResultTile renders Bluepad32 badge, Connect/Open states, non-connectable disabled state, and expansion rows',
      (WidgetTester tester) async {
        final StreamController<BluetoothConnectionState> connectionController =
            StreamController<BluetoothConnectionState>.broadcast();
        addTearDown(connectionController.close);

        int tapCount = 0;
        final ScanResult bpResult = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:01',
          platformName: 'Bluepad32-ESP32',
          advName: 'BP32-Adv',
          rssi: -55,
          connectable: true,
          txPowerLevel: -12,
          appearance: 0x03C1,
          manufacturerData: <int, List<int>>{
            0x5678: <int>[0xAA, 0xBB],
          },
          serviceUuids: <Guid>[Bluepad32Uuids.service],
          serviceData: <Guid, List<int>>{
            Guid('180f'): <int>[0x64],
          },
          connectionStateStream: connectionController.stream,
        );

        await tester.pumpWidget(
          _wrapWithMaterialApp(
            ScanResultTile(
              result: bpResult,
              onTap: () => tapCount++,
            ),
          ),
        );

        expect(find.text('BP32-Adv'), findsOneWidget);
        expect(find.text('Cached OS Name: Bluepad32-ESP32'), findsOneWidget);
        expect(find.text('Bluepad32'), findsOneWidget);
        expect(find.text('AA:BB:CC:DD:EE:01'), findsOneWidget);
        expect(find.text('-55 dBm'), findsOneWidget);
        expect(find.byIcon(Icons.sports_esports), findsWidgets);
        expect(find.text('Connect'), findsOneWidget);

        // Tap Connect button and verify callback runs without expanding tile.
        await tester.tap(find.text('Connect'));
        await tester.pump();
        expect(tapCount, equals(1));

        // Expand the ExpansionTile by tapping the title text.
        await tester.tap(find.text('BP32-Adv'));
        await tester.pumpAndSettle();

        expect(find.text('Name'), findsOneWidget);
        expect(find.text('BP32-Adv'), findsNWidgets(2));
        expect(find.text('Tx Power Level'), findsOneWidget);
        expect(find.text('-12'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('0x3c1'), findsOneWidget);
        expect(find.text('Manufacturer Data'), findsOneWidget);
        expect(find.text('[78, 56, AA, BB]'), findsOneWidget);
        expect(find.text('Service UUIDs'), findsOneWidget);
        expect(
          find.text('4627C4A4-AC00-46B9-B688-AFC5C1BF7F63'),
          findsOneWidget,
        );
        expect(find.text('Service Data'), findsOneWidget);
        expect(find.text('180F: [64]'), findsOneWidget);

        // Transition connection state to connected -> button changes to 'Open'.
        connectionController.add(BluetoothConnectionState.connected);
        await tester.pumpAndSettle();

        expect(find.text('Open'), findsOneWidget);
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(tapCount, equals(2));

        // Render unnamed, non-connectable peripheral and advName fallback peripheral.
        final ScanResult advNameOnly = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:02',
          platformName: '',
          advName: 'AdvFallbackName',
          connectable: true,
        );
        final ScanResult unnamedNonConnectable = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:03',
          platformName: '',
          advName: '',
          connectable: false,
        );

        await tester.pumpWidget(
          _wrapWithMaterialApp(
            Column(
              children: <Widget>[
                ScanResultTile(result: advNameOnly),
                ScanResultTile(result: unnamedNonConnectable),
              ],
            ),
          ),
        );

        expect(find.text('AdvFallbackName'), findsOneWidget);
        expect(find.text('Unnamed Device'), findsOneWidget);
        expect(find.byIcon(Icons.bluetooth), findsNWidgets(2));

        final Iterable<FilledButton> buttons =
            tester.widgetList<FilledButton>(find.byType(FilledButton));
        expect(buttons.last.onPressed, isNull);
      },
    );

    testWidgets(
      'ScanResultTile prioritizes live advName ("Bluepad32 rc car", "Bluepad32 on esp32") over stale OS-cached platformName and falls back to platformName when advName is empty',
      (WidgetTester tester) async {
        final ScanResult rcCar = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:10',
          platformName: 'Bluepad32',
          advName: 'Bluepad32 rc car',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        final ScanResult esp32Host = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:11',
          platformName: 'BP32',
          advName: 'Bluepad32 on esp32',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        final ScanResult cachedOnly = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:12',
          platformName: 'Bluepad32-CachedOnly',
          advName: '',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        final ScanResult unnamedBluepad = _makeScanResult(
          id: 'AA:BB:CC:DD:EE:13',
          platformName: '',
          advName: '',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );

        await tester.pumpWidget(
          _wrapWithMaterialApp(
            ListView(
              children: <Widget>[
                ScanResultTile(result: rcCar),
                ScanResultTile(result: esp32Host),
                ScanResultTile(result: cachedOnly),
                ScanResultTile(result: unnamedBluepad),
              ],
            ),
          ),
        );

        expect(find.text('Bluepad32 rc car'), findsOneWidget);
        expect(find.text('Cached OS Name: Bluepad32'), findsOneWidget);
        expect(find.text('Bluepad32 on esp32'), findsOneWidget);
        expect(find.text('Cached OS Name: BP32'), findsOneWidget);
        expect(find.text('Bluepad32-CachedOnly'), findsOneWidget);
        expect(find.text('Bluepad32 Device'), findsOneWidget);
      },
    );
  });

  group('3.2 SystemDeviceTile Widget Tests', () {
    testWidgets(
      'SystemDeviceTile switches between CONNECT and OPEN based on connectionState',
      (WidgetTester tester) async {
        final StreamController<BluetoothConnectionState> connectionController =
            StreamController<BluetoothConnectionState>.broadcast();
        addTearDown(connectionController.close);

        final TestBluetoothDevice device = TestBluetoothDevice(
          id: '11:22:33:44:55:66',
          testPlatformName: 'Bluepad32-System',
          connectionStateStream: connectionController.stream,
        );

        int connectCalls = 0;
        int openCalls = 0;

        await tester.pumpWidget(
          _wrapWithMaterialApp(
            SystemDeviceTile(
              device: device,
              onConnect: () => connectCalls++,
              onOpen: () => openCalls++,
            ),
          ),
        );

        expect(find.text('Bluepad32-System'), findsOneWidget);
        expect(find.text('11:22:33:44:55:66'), findsOneWidget);
        expect(find.text('CONNECT'), findsOneWidget);

        await tester.tap(find.text('CONNECT'));
        await tester.pump();
        expect(connectCalls, equals(1));
        expect(openCalls, equals(0));

        connectionController.add(BluetoothConnectionState.connected);
        await tester.pump();

        expect(find.text('OPEN'), findsOneWidget);
        await tester.tap(find.text('OPEN'));
        await tester.pump();
        expect(openCalls, equals(1));
      },
    );
  });

  group('3.3 ScanScreen Discovery, Filtering, Sorting, Lifecycle, & Error Snackbars', () {
    testWidgets(
      'ScanScreen empty state, scanning spinner/STOP button, and SCAN/STOP callbacks',
      (WidgetTester tester) async {
        final StreamController<List<ScanResult>> scanResultsController =
            StreamController<List<ScanResult>>.broadcast();
        final StreamController<bool> isScanningController =
            StreamController<bool>.broadcast();
        addTearDown(scanResultsController.close);
        addTearDown(isScanningController.close);

        List<Guid>? requestedSystemServices;
        List<Guid>? requestedScanServices;
        int stopScanCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanScreen(
              scanResultsStream: scanResultsController.stream,
              isScanningStream: isScanningController.stream,
              onSystemDevices: (List<Guid> services) async {
                requestedSystemServices = services;
                return <BluetoothDevice>[];
              },
              onStartScan: ({required List<Guid> withServices}) async {
                requestedScanServices = withServices;
              },
              onStopScan: () async {
                stopScanCalls++;
              },
            ),
          ),
        );

        expect(
          find.text('Tap SCAN to search for Bluepad32 devices.'),
          findsOneWidget,
        );
        expect(find.text('SCAN'), findsOneWidget);

        await tester.tap(find.text('SCAN'));
        await tester.pump();

        expect(
          requestedSystemServices,
          equals(<Guid>[Bluepad32Uuids.service]),
        );
        expect(
          requestedScanServices,
          equals(<Guid>[Bluepad32Uuids.service]),
        );

        // Emit scanning = true (use pump(), NEVER pumpAndSettle() while spinner is active).
        isScanningController.add(true);
        await tester.pump();

        expect(
          find.text('Scanning for Bluepad32 devices...'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('STOP'), findsOneWidget);

        await tester.tap(find.text('STOP'));
        await tester.pump();
        expect(stopScanCalls, equals(1));

        isScanningController.add(false);
        await tester.pumpAndSettle();
        expect(find.text('SCAN'), findsOneWidget);
      },
    );

    testWidgets(
      'ScanScreen Bluepad32 Only vs All BLE Devices filter and RSSI sorting',
      (WidgetTester tester) async {
        final StreamController<List<ScanResult>> scanResultsController =
            StreamController<List<ScanResult>>.broadcast();
        final StreamController<bool> isScanningController =
            StreamController<bool>.broadcast();
        addTearDown(scanResultsController.close);
        addTearDown(isScanningController.close);

        List<Guid>? lastStartScanServices;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanScreen(
              scanResultsStream: scanResultsController.stream,
              isScanningStream: isScanningController.stream,
              onSystemDevices: (_) async => <BluetoothDevice>[],
              onStartScan: ({required List<Guid> withServices}) async {
                lastStartScanServices = withServices;
              },
            ),
          ),
        );

        final ScanResult genericStrong = _makeScanResult(
          id: 'AA:00:00:00:00:01',
          platformName: 'FitnessBand',
          rssi: -40,
        );
        final ScanResult genericWeak = _makeScanResult(
          id: 'AA:00:00:00:00:02',
          platformName: 'SmartWatch',
          rssi: -75,
        );
        final ScanResult bpWeak = _makeScanResult(
          id: 'BB:00:00:00:00:01',
          platformName: 'Bluepad32-Weak',
          rssi: -80,
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        final ScanResult bpStrong = _makeScanResult(
          id: 'BB:00:00:00:00:02',
          platformName: 'Bluepad32-Strong',
          rssi: -50,
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );

        scanResultsController.add(<ScanResult>[
          genericWeak,
          bpWeak,
          genericStrong,
          bpStrong,
        ]);
        await tester.pumpAndSettle();

        // Default 'Bluepad32 Only' hides non-Bluepad32 peripherals and sorts by RSSI desc.
        expect(find.text('FitnessBand'), findsNothing);
        expect(find.text('SmartWatch'), findsNothing);
        expect(find.text('Bluepad32-Strong'), findsOneWidget);
        expect(find.text('Bluepad32-Weak'), findsOneWidget);

        expect(
          tester.getTopLeft(find.text('Bluepad32-Strong')).dy,
          lessThan(tester.getTopLeft(find.text('Bluepad32-Weak')).dy),
        );

        // Switch to 'All BLE Devices'.
        await tester.tap(find.text('All BLE Devices'));
        await tester.pumpAndSettle();

        expect(find.text('Bluepad32-Strong'), findsOneWidget);
        expect(find.text('Bluepad32-Weak'), findsOneWidget);
        expect(find.text('FitnessBand'), findsOneWidget);
        expect(find.text('SmartWatch'), findsOneWidget);

        final double yBpStrong =
            tester.getTopLeft(find.text('Bluepad32-Strong')).dy;
        final double yBpWeak =
            tester.getTopLeft(find.text('Bluepad32-Weak')).dy;
        final double yGenericStrong =
            tester.getTopLeft(find.text('FitnessBand')).dy;
        final double yGenericWeak =
            tester.getTopLeft(find.text('SmartWatch')).dy;

        expect(yBpStrong, lessThan(yBpWeak));
        expect(yBpWeak, lessThan(yGenericStrong));
        expect(yGenericStrong, lessThan(yGenericWeak));

        // Tapping SCAN in 'All BLE Devices' mode passes empty withServices list.
        await tester.tap(find.text('SCAN'));
        await tester.pump();
        expect(lastStartScanServices, isEmpty);

        // Switch back to 'Bluepad32 Only'.
        await tester.tap(find.text('Bluepad32 Only'));
        await tester.pumpAndSettle();
        expect(find.text('FitnessBand'), findsNothing);
        expect(find.text('Bluepad32-Strong'), findsOneWidget);
      },
    );

    testWidgets(
      'ScanScreen pull-to-refresh advances 500ms timer, renders SystemDeviceTile, and navigates to /DeviceScreen',
      (WidgetTester tester) async {
        final StreamController<List<ScanResult>> scanResultsController =
            StreamController<List<ScanResult>>.broadcast();
        final StreamController<bool> isScanningController =
            StreamController<bool>.broadcast();
        final StreamController<BluetoothConnectionState> sysConnController =
            StreamController<BluetoothConnectionState>.broadcast();
        addTearDown(scanResultsController.close);
        addTearDown(isScanningController.close);
        addTearDown(sysConnController.close);

        final TestBluetoothDevice sysDevice = TestBluetoothDevice(
          id: '11:22:33:44:55:00',
          testPlatformName: 'Bluepad32-SystemHost',
          connectionStateStream: sysConnController.stream,
        );

        BluetoothDevice? navigatedDevice;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanScreen(
              scanResultsStream: scanResultsController.stream,
              isScanningStream: isScanningController.stream,
              onSystemDevices: (_) async => <BluetoothDevice>[sysDevice],
              onStartScan: ({required List<Guid> withServices}) async {},
              deviceScreenBuilder:
                  (BuildContext context, BluetoothDevice device) {
                navigatedDevice = device;
                return Scaffold(
                  appBar: AppBar(title: Text('Dest: ${device.platformName}')),
                );
              },
            ),
          ),
        );

        // Trigger pull-to-refresh and advance fake clock past the 500ms delayed future.
        await tester.fling(
          find.byType(ListView),
          const Offset(0, 300),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();

        expect(find.byType(SystemDeviceTile), findsOneWidget);
        expect(find.text('Bluepad32-SystemHost'), findsOneWidget);

        // Tap CONNECT on SystemDeviceTile -> navigates to /DeviceScreen.
        await tester.tap(find.text('CONNECT'));
        await tester.pumpAndSettle();
        expect(navigatedDevice, same(sysDevice));
        expect(find.text('Dest: Bluepad32-SystemHost'), findsOneWidget);

        // Pop back to ScanScreen.
        Navigator.of(tester.element(find.text('Dest: Bluepad32-SystemHost')))
            .pop();
        await tester.pumpAndSettle();

        // Mark system device as connected so button shows OPEN, then tap OPEN.
        sysConnController.add(BluetoothConnectionState.connected);
        await tester.pumpAndSettle();
        expect(find.text('OPEN'), findsOneWidget);
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        expect(find.text('Dest: Bluepad32-SystemHost'), findsOneWidget);

        Navigator.of(tester.element(find.text('Dest: Bluepad32-SystemHost')))
            .pop();
        await tester.pumpAndSettle();

        // Emit a ScanResultTile and tap Connect -> navigates to /DeviceScreen.
        final ScanResult discovered = _makeScanResult(
          id: 'CC:DD:EE:FF:00:11',
          platformName: 'Bluepad32-Discovered',
          serviceUuids: <Guid>[Bluepad32Uuids.service],
        );
        scanResultsController.add(<ScanResult>[discovered]);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        expect(find.text('Dest: Bluepad32-Discovered'), findsOneWidget);
      },
    );

    testWidgets(
      'ScanScreen displays error SnackBars on scanResultsStream, onSystemDevices, onStartScan, and onStopScan failures',
      (WidgetTester tester) async {
        final StreamController<List<ScanResult>> scanResultsController =
            StreamController<List<ScanResult>>.broadcast();
        final StreamController<bool> isScanningController =
            StreamController<bool>.broadcast();
        addTearDown(scanResultsController.close);
        addTearDown(isScanningController.close);

        bool throwOnSystemDevices = false;
        bool throwOnStartScan = false;
        bool throwOnStopScan = false;

        await tester.pumpWidget(
          MaterialApp(
            home: ScanScreen(
              scanResultsStream: scanResultsController.stream,
              isScanningStream: isScanningController.stream,
              onSystemDevices: (_) async {
                if (throwOnSystemDevices) {
                  throw Exception('sys-fail');
                }
                return <BluetoothDevice>[];
              },
              onStartScan: ({required List<Guid> withServices}) async {
                if (throwOnStartScan) {
                  throw Exception('start-fail');
                }
              },
              onStopScan: () async {
                if (throwOnStopScan) {
                  throw Exception('stop-fail');
                }
              },
            ),
          ),
        );

        // 1. scanResultsStream error.
        scanResultsController.addError(Exception('stream-fail'));
        await tester.pump();
        expect(find.textContaining('Scan Error:'), findsOneWidget);

        // 2. onSystemDevices error.
        throwOnSystemDevices = true;
        await tester.tap(find.text('SCAN'));
        await tester.pump();
        expect(find.textContaining('System Devices Error:'), findsOneWidget);

        // 3. onStartScan error.
        throwOnSystemDevices = false;
        throwOnStartScan = true;
        await tester.tap(find.text('SCAN'));
        await tester.pump();
        expect(find.textContaining('Start Scan Error:'), findsOneWidget);

        // 4. onStopScan error.
        isScanningController.add(true);
        await tester.pump();
        throwOnStopScan = true;
        await tester.tap(find.text('STOP'));
        await tester.pump();
        expect(find.textContaining('Stop Scan Error:'), findsOneWidget);

        isScanningController.add(false);
        await tester.pumpAndSettle();
      },
    );
  });
}
