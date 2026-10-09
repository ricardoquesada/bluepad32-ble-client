// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

/// Alias for [FlutterBlueApp].
typedef Bluepad32App = FlutterBlueApp;

/// Root application widget that displays [ScanScreen] when the Bluetooth
/// adapter is on, or [BluetoothOffScreen] otherwise.
class FlutterBlueApp extends StatefulWidget {
  final Stream<BluetoothAdapterState>? adapterStateStream;

  const FlutterBlueApp({
    super.key,
    this.adapterStateStream,
  });

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  static const Color _seedColor = Color(0xFF1E88E5);

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;

  @override
  void initState() {
    super.initState();
    final Stream<BluetoothAdapterState> stream =
        widget.adapterStateStream ?? FlutterBluePlus.adapterState;
    _adapterStateStateSubscription = stream.listen(
      (BluetoothAdapterState state) {
        _adapterState = state;
        if (mounted) {
          setState(() {});
        }
      },
      onError: (Object _) {
        // Ignore platform-unsupported errors in headless test environments.
      },
    );
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget screen = _adapterState == BluetoothAdapterState.on
        ? const ScanScreen()
        : BluetoothOffScreen(adapterState: _adapterState);

    return MaterialApp(
      title: 'Bluepad32 BLE Client',
      color: _seedColor,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: screen,
      navigatorObservers: <NavigatorObserver>[BluetoothAdapterStateObserver()],
    );
  }
}

/// Observer that listens for Bluetooth turning off and pops `/DeviceScreen`.
class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      _adapterStateSubscription ??=
          FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        if (state != BluetoothAdapterState.on) {
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
