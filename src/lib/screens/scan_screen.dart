/// BLE discovery screen with Bluepad32 service UUID filtering
/// (`4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`) and RSSI-prioritized peripheral list.
///
/// Queries both system-connected peripherals and live BLE advertisements,
/// allowing users to filter exclusively for Bluepad32 hosts or inspect all
/// nearby BLE peripherals before navigating to [DeviceScreen].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/bluepad32_uuids.dart';
import '../utils/snackbar.dart';
import '../widgets/scan_result_tile.dart';
import '../widgets/system_device_tile.dart';
import 'device_screen.dart';

/// Screen for discovering nearby Bluepad32 BLE peripherals and initiating
/// connections.
///
/// Exposes optional stream and callback overrides ([scanResultsStream],
/// [isScanningStream], [onSystemDevices], [onStartScan], [onStopScan], and
/// [deviceScreenBuilder]) so widget tests can verify discovery, filtering,
/// sorting, pull-to-refresh, and error snackbars without native BLE hardware.
class ScanScreen extends StatefulWidget {
  /// Creates a [ScanScreen] widget.
  const ScanScreen({
    super.key,
    this.scanResultsStream,
    this.isScanningStream,
    this.onSystemDevices,
    this.onStartScan,
    this.onStopScan,
    this.deviceScreenBuilder,
  });

  /// Optional override stream of discovered BLE scan results for widget testing.
  ///
  /// Defaults to [FlutterBluePlus.scanResults] when omitted.
  final Stream<List<ScanResult>>? scanResultsStream;

  /// Optional override stream of scan-in-progress state for widget testing.
  ///
  /// Defaults to [FlutterBluePlus.isScanning] when omitted.
  final Stream<bool>? isScanningStream;

  /// Optional override callback for querying system-connected Bluepad32 devices.
  ///
  /// Defaults to [FlutterBluePlus.systemDevices] when omitted.
  final Future<List<BluetoothDevice>> Function(List<Guid> withServices)?
      onSystemDevices;

  /// Optional override callback for starting a BLE scan.
  ///
  /// Defaults to [FlutterBluePlus.startScan] when omitted.
  final Future<void> Function({required List<Guid> withServices})? onStartScan;

  /// Optional override callback for stopping an active BLE scan.
  ///
  /// Defaults to [FlutterBluePlus.stopScan] when omitted.
  final Future<void> Function()? onStopScan;

  /// Optional builder for the destination screen pushed when a device is selected.
  ///
  /// Defaults to constructing [DeviceScreen] for the selected [BluetoothDevice].
  final Widget Function(BuildContext context, BluetoothDevice device)?
      deviceScreenBuilder;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = <BluetoothDevice>[];
  List<ScanResult> _scanResults = <ScanResult>[];
  bool _isScanning = false;
  bool _filterByBluepad32 = true;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    final Stream<List<ScanResult>> resultsStream =
        widget.scanResultsStream ?? FlutterBluePlus.scanResults;
    _scanResultsSubscription = resultsStream.listen(
      (List<ScanResult> results) {
        if (mounted) {
          setState(() => _scanResults = results);
        }
      },
      onError: (Object e) {
        Snackbar.show(ABC.b, prettyException('Scan Error:', e), success: false);
      },
    );

    final Stream<bool> scanningStream =
        widget.isScanningStream ?? FlutterBluePlus.isScanning;
    _isScanningSubscription = scanningStream.listen((bool state) {
      if (mounted) {
        setState(() => _isScanning = state);
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  /// Queries OS-connected Bluepad32 devices and starts a 15-second BLE scan.
  ///
  /// When `_filterByBluepad32` is enabled, restricts hardware/OS scan filtering
  /// to [Bluepad32Uuids.service]; otherwise scans all BLE advertisements while
  /// still requesting [Bluepad32Uuids.service] in `webOptionalServices` for Web
  /// Bluetooth access.
  Future<void> onScanPressed() async {
    try {
      final List<Guid> services = <Guid>[Bluepad32Uuids.service];
      _systemDevices = widget.onSystemDevices != null
          ? await widget.onSystemDevices!(services)
          : await FlutterBluePlus.systemDevices(services);
    } catch (e) {
      Snackbar.show(
        ABC.b,
        prettyException('System Devices Error:', e),
        success: false,
      );
    }
    try {
      final List<Guid> withServices = _filterByBluepad32
          ? <Guid>[Bluepad32Uuids.service]
          : const <Guid>[];
      if (widget.onStartScan != null) {
        await widget.onStartScan!(withServices: withServices);
      } else {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15),
          withServices: withServices,
          webOptionalServices: <Guid>[
            Bluepad32Uuids.service,
          ],
        );
      }
    } catch (e) {
      Snackbar.show(
        ABC.b,
        prettyException('Start Scan Error:', e),
        success: false,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Stops an active BLE scan and reports any platform failure via [Snackbar].
  Future<void> onStopPressed() async {
    try {
      if (widget.onStopScan != null) {
        await widget.onStopScan!();
      } else {
        await FlutterBluePlus.stopScan();
      }
    } catch (e) {
      Snackbar.show(
        ABC.b,
        prettyException('Stop Scan Error:', e),
        success: false,
      );
    }
  }

  /// Navigates to [DeviceScreen] without firing a duplicate unawaited
  /// `connectAndUpdateStream()` call, allowing [DeviceScreen] and
  /// `Bluepad32Client.connect()` to own the connection + MTU + service
  /// discovery sequence cleanly.
  void onConnectPressed(BluetoothDevice device) {
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          widget.deviceScreenBuilder?.call(context, device) ??
          DeviceScreen(device: device),
      settings: const RouteSettings(name: '/DeviceScreen'),
    );
    Navigator.of(context).push(route);
  }

  /// Initiates a new scan on pull-to-refresh if not already scanning and
  /// returns a short delay so the [RefreshIndicator] animation settles smoothly.
  Future<void> onRefresh() {
    if (!_isScanning) {
      onScanPressed();
    }
    if (mounted) {
      setState(() {});
    }
    return Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildScanButton(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Widget button = _isScanning
        ? FilledButton.tonalIcon(
            onPressed: onStopPressed,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('STOP'),
          )
        : FilledButton.icon(
            onPressed: onScanPressed,
            icon: const Icon(Icons.bluetooth_searching, size: 18),
            label: const Text('SCAN'),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_isScanning) _buildSpinner(),
        button,
      ],
    );
  }

  Widget _buildSpinner() {
    return const Padding(
      padding: EdgeInsets.only(right: 12.0),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(
            Icons.filter_list,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          FilterChip(
            label: const Text('Bluepad32 Only'),
            selected: _filterByBluepad32,
            onSelected: (bool selected) {
              setState(() {
                _filterByBluepad32 = true;
              });
            },
          ),
          FilterChip(
            label: const Text('All BLE Devices'),
            selected: !_filterByBluepad32,
            onSelected: (bool selected) {
              setState(() {
                _filterByBluepad32 = false;
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSystemDeviceTiles() {
    return _systemDevices
        .map(
          (BluetoothDevice d) => SystemDeviceTile(
            device: d,
            onOpen: () => onConnectPressed(d),
            onConnect: () => onConnectPressed(d),
          ),
        )
        .toList();
  }

  /// Filters and sorts discovered [ScanResult] items into [ScanResultTile]s.
  ///
  /// Bluepad32 peripherals are always pinned above generic BLE peripherals, and
  /// ties within each group are ordered by strongest signal (descending RSSI).
  List<Widget> _buildScanResultTiles() {
    final List<ScanResult> visibleResults = _filterByBluepad32
        ? _scanResults.where(ScanResultTile.isBluepad32Peripheral).toList()
        : List<ScanResult>.from(_scanResults);

    // Sort Bluepad32 peripherals to the top when viewing all BLE devices,
    // then order by strongest RSSI (descending).
    visibleResults.sort((ScanResult a, ScanResult b) {
      final bool aIsBp = ScanResultTile.isBluepad32Peripheral(a);
      final bool bIsBp = ScanResultTile.isBluepad32Peripheral(b);
      if (aIsBp != bIsBp) {
        return aIsBp ? -1 : 1;
      }
      return b.rssi.compareTo(a.rssi);
    });

    return visibleResults
        .map(
          (ScanResult r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> systemTiles = _buildSystemDeviceTiles();
    final List<Widget> scanTiles = _buildScanResultTiles();

    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bluepad32 Devices'),
          actions: <Widget>[
            _buildScanButton(context),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildFilterBar(context),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  children: <Widget>[
                    ...systemTiles,
                    ...scanTiles,
                    if (systemTiles.isEmpty && scanTiles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.sports_esports_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isScanning
                                  ? 'Scanning for Bluepad32 devices...'
                                  : 'Tap SCAN to search for Bluepad32 devices.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
