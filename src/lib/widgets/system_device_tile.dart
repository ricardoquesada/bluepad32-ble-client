// List tile for displaying OS-level already-connected BLE devices matching the Bluepad32 service.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// List tile representing a system-connected [BluetoothDevice].
class SystemDeviceTile extends StatefulWidget {
  /// System-connected BLE peripheral.
  final BluetoothDevice device;

  /// Callback invoked when the device is already connected and the user taps `OPEN`.
  final VoidCallback onOpen;

  /// Callback invoked when the device is disconnected and the user taps `CONNECT`.
  final VoidCallback onConnect;

  /// Creates a [SystemDeviceTile].
  const SystemDeviceTile({
    required this.device,
    required this.onOpen,
    required this.onConnect,
    super.key,
  });

  @override
  State<SystemDeviceTile> createState() => _SystemDeviceTileState();
}

class _SystemDeviceTileState extends State<SystemDeviceTile> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      _connectionState = state;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.device.platformName),
      subtitle: Text(widget.device.remoteId.str),
      trailing: ElevatedButton(
        onPressed: isConnected ? widget.onOpen : widget.onConnect,
        child: isConnected ? const Text('OPEN') : const Text('CONNECT'),
      ),
    );
  }
}
