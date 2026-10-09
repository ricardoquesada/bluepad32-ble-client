// Expandable list tile for displaying a discovered BLE peripheral and highlighting
// Bluepad32 devices advertising UUID `4627C4A4-AC00-46B9-B688-AFC5C1BF7F63`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/bluepad32_uuids.dart';

/// List tile displaying a discovered BLE [ScanResult] with special highlighting
/// for peripherals advertising the Bluepad32 GATT service or name.
class ScanResultTile extends StatefulWidget {
  /// Creates a [ScanResultTile] for the given [result].
  const ScanResultTile({
    super.key,
    required this.result,
    this.onTap,
  });

  /// Discovered BLE scan result and advertisement data.
  final ScanResult result;

  /// Callback invoked when the user taps the Connect / Open action button.
  final VoidCallback? onTap;

  /// Returns `true` if [result] advertises [Bluepad32Uuids.service] or a
  /// device/advertisement name containing `'bluepad32'`.
  static bool isBluepad32Peripheral(ScanResult result) {
    final AdvertisementData adv = result.advertisementData;
    if (adv.serviceUuids.contains(Bluepad32Uuids.service)) {
      return true;
    }
    final String platformName = result.device.platformName.toLowerCase();
    final String advName = adv.advName.toLowerCase();
    return platformName.contains('bluepad32') || advName.contains('bluepad32');
  }

  @override
  State<ScanResultTile> createState() => _ScanResultTileState();
}

class _ScanResultTileState extends State<ScanResultTile> {
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.result.device.connectionState.listen(
      (BluetoothConnectionState state) {
        _connectionState = state;
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  String _getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((int i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]';
  }

  String _getNiceManufacturerData(List<List<int>> data) {
    return data
        .map((List<int> val) => _getNiceHexArray(val))
        .join(', ')
        .toUpperCase();
  }

  String _getNiceServiceData(Map<Guid, List<int>> data) {
    return data.entries
        .map((MapEntry<Guid, List<int>> v) =>
            '${v.key}: ${_getNiceHexArray(v.value)}')
        .join(', ')
        .toUpperCase();
  }

  String _getNiceServiceUuids(List<Guid> serviceUuids) {
    return serviceUuids.join(', ').toUpperCase();
  }

  bool get _isConnected =>
      _connectionState == BluetoothConnectionState.connected;

  bool get _isBluepad32 => ScanResultTile.isBluepad32Peripheral(widget.result);

  Widget _buildTitle(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String name = widget.result.device.platformName.isNotEmpty
        ? widget.result.device.platformName
        : (widget.result.advertisementData.advName.isNotEmpty
            ? widget.result.advertisementData.advName
            : 'Unnamed Device');

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: _isBluepad32 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (_isBluepad32) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.sports_esports,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Bluepad32',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Text(
          widget.result.device.remoteId.str,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    final bool connectable = widget.result.advertisementData.connectable;
    if (_isConnected) {
      return FilledButton.tonal(
        onPressed: connectable ? widget.onTap : null,
        child: const Text('Open'),
      );
    }
    return FilledButton(
      onPressed: connectable ? widget.onTap : null,
      child: const Text('Connect'),
    );
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdvertisementData adv = widget.result.advertisementData;
    final ThemeData theme = Theme.of(context);
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            _isBluepad32 ? Icons.sports_esports : Icons.bluetooth,
            size: 18,
            color: _isBluepad32
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          Text(
            '${widget.result.rssi} dBm',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
      trailing: _buildConnectButton(context),
      children: <Widget>[
        if (adv.advName.isNotEmpty) _buildAdvRow(context, 'Name', adv.advName),
        if (adv.txPowerLevel != null)
          _buildAdvRow(context, 'Tx Power Level', '${adv.txPowerLevel}'),
        if ((adv.appearance ?? 0) > 0)
          _buildAdvRow(
            context,
            'Appearance',
            '0x${adv.appearance!.toRadixString(16)}',
          ),
        if (adv.msd.isNotEmpty)
          _buildAdvRow(
            context,
            'Manufacturer Data',
            _getNiceManufacturerData(adv.msd),
          ),
        if (adv.serviceUuids.isNotEmpty)
          _buildAdvRow(
            context,
            'Service UUIDs',
            _getNiceServiceUuids(adv.serviceUuids),
          ),
        if (adv.serviceData.isNotEmpty)
          _buildAdvRow(
            context,
            'Service Data',
            _getNiceServiceData(adv.serviceData),
          ),
      ],
    );
  }
}
