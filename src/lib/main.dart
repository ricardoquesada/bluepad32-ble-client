// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Application entry point, root Material 3 widget tree, and Bluetooth adapter
/// lifecycle navigation observer for the Bluepad32 BLE Client.
///
/// Routes between [ScanScreen] when the host Bluetooth adapter is active and
/// [BluetoothOffScreen] when Bluetooth is disabled or unavailable, and
/// automatically pops `/DeviceScreen` if the adapter turns off mid-session.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'screens/bluetooth_off_screen.dart';
import 'screens/scan_screen.dart';

/// Initializes `flutter_blue_plus` verbose logging and launches [FlutterBlueApp].
void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(const FlutterBlueApp());
}

/// Alias for [FlutterBlueApp] matching the Bluepad32 domain naming convention.
typedef Bluepad32App = FlutterBlueApp;

/// Root application widget that displays [ScanScreen] when the Bluetooth
/// adapter is on, or [BluetoothOffScreen] otherwise.
///
/// Exposes optional [adapterStateStream] and [scanScreenBuilder] injection
/// seams so headless widget tests can drive adapter state transitions and
/// route navigation without invoking native `flutter_blue_plus` platform
/// channels.
class FlutterBlueApp extends StatefulWidget {
  /// Optional override stream of [BluetoothAdapterState] transitions used by
  /// widget tests to simulate Bluetooth turning on or off.
  ///
  /// Defaults to [FlutterBluePlus.adapterState] in production.
  final Stream<BluetoothAdapterState>? adapterStateStream;

  /// Optional builder used to construct the home screen when the adapter state
  /// is [BluetoothAdapterState.on].
  ///
  /// Defaults to constructing a const [ScanScreen] when omitted.
  final WidgetBuilder? scanScreenBuilder;

  /// Creates the root [FlutterBlueApp] widget.
  const FlutterBlueApp({
    super.key,
    this.adapterStateStream,
    this.scanScreenBuilder,
  });

  @override
  State<FlutterBlueApp> createState() => _FlutterBlueAppState();
}

class _FlutterBlueAppState extends State<FlutterBlueApp> {
  /// Primary Material 3 brand seed color (Blue 600).
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
        // Ignore platform-unsupported errors emitted by FlutterBluePlus in
        // headless VM test environments or unsupported desktop targets.
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
        ? (widget.scanScreenBuilder?.call(context) ?? const ScanScreen())
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
      navigatorObservers: <NavigatorObserver>[
        BluetoothAdapterStateObserver(
          adapterStateStream: widget.adapterStateStream,
        ),
      ],
    );
  }
}

/// [NavigatorObserver] that monitors the Bluetooth adapter state while
/// `/DeviceScreen` is active and automatically pops the route if the adapter
/// leaves [BluetoothAdapterState.on].
///
/// Prevents the user from remaining stranded on a stale peripheral configuration
/// dashboard after host Bluetooth is disabled.
class BluetoothAdapterStateObserver extends NavigatorObserver {
  /// Optional override stream of [BluetoothAdapterState] transitions for
  /// deterministic widget testing.
  final Stream<BluetoothAdapterState>? adapterStateStream;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  /// Creates a [BluetoothAdapterStateObserver] optionally bound to a test
  /// [adapterStateStream].
  BluetoothAdapterStateObserver({this.adapterStateStream});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/DeviceScreen') {
      // Start listening for adapter state loss as soon as /DeviceScreen is pushed.
      final Stream<BluetoothAdapterState> stream =
          adapterStateStream ?? FlutterBluePlus.adapterState;
      _adapterStateSubscription ??=
          stream.listen((BluetoothAdapterState state) {
        if (state != BluetoothAdapterState.on) {
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the adapter state subscription when leaving /DeviceScreen to avoid
    // duplicate listeners or premature pops on subsequent routes.
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = null;
  }
}
