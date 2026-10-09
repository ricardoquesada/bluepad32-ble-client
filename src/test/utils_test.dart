/// Unit and widget tests for utility helpers in `lib/utils/`.
///
/// Covers:
/// - [StreamControllerReemit] and [StreamNewStreamWithInitialValue] value
///   caching, immediate replay on subscription, broadcast vs. single-subscription
///   pause/resume forwarding, and listener lifecycle cleanup
/// - [prettyException] formatting across [FlutterBluePlusException],
///   [PlatformException], and generic exceptions, plus [Snackbar] key routing
///   and presentation
/// - [Extra] extension methods on [BluetoothDevice] (`isConnecting`,
///   `isDisconnecting`, `connectAndUpdateStream`, and `disconnectAndUpdateStream`).
library;

import 'dart:async';

import 'package:bluepad32_client/utils/extra.dart';
import 'package:bluepad32_client/utils/snackbar.dart';
import 'package:bluepad32_client/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [BluetoothDevice] test double that overrides [connect] and
/// [disconnect] without invoking native `flutter_blue_plus` platform channels.
class TestBluetoothDevice extends BluetoothDevice {
  /// Creates a [TestBluetoothDevice] for verifying [Extra] stream extensions.
  TestBluetoothDevice({
    required String id,
    this.testPlatformName = '',
    Stream<BluetoothConnectionState>? connectionStateStream,
  })  : _connectionStateStream = connectionStateStream ??
            Stream<BluetoothConnectionState>.value(
              BluetoothConnectionState.disconnected,
            ),
        super(remoteId: DeviceIdentifier(id));

  /// Simulated device name returned by [platformName].
  final String testPlatformName;
  final Stream<BluetoothConnectionState> _connectionStateStream;

  /// Number of times [connect] was invoked.
  int connectCallCount = 0;

  /// Most recent [License] passed to [connect].
  License? lastConnectLicense;

  /// Number of times [disconnect] was invoked.
  int disconnectCallCount = 0;

  /// Most recent `queue` flag passed to [disconnect].
  bool? lastDisconnectQueue;

  @override
  String get platformName => testPlatformName;

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateStream;

  @override
  Future<void> connect({
    required License license,
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    connectCallCount++;
    lastConnectLicense = license;
  }

  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    disconnectCallCount++;
    lastDisconnectQueue = queue;
  }
}

void main() {
  group('2.1 StreamControllerReemit & StreamNewStreamWithInitialValue', () {
    test('StreamControllerReemit caches initialValue, re-emits on subscription, and updates on add', () async {
      final StreamControllerReemit<int> reemit =
          StreamControllerReemit<int>(initialValue: 10);

      expect(reemit.value, equals(10));

      final List<int> listener1Events = <int>[];
      final StreamSubscription<int> sub1 =
          reemit.stream.listen(listener1Events.add);

      await Future<void>.delayed(Duration.zero);
      expect(listener1Events, equals(<int>[10]));

      reemit.add(20);
      expect(reemit.value, equals(20));
      await Future<void>.delayed(Duration.zero);
      expect(listener1Events, equals(<int>[10, 20]));

      final List<int> listener2Events = <int>[];
      final StreamSubscription<int> sub2 =
          reemit.stream.listen(listener2Events.add);

      await Future<void>.delayed(Duration.zero);
      expect(listener2Events, equals(<int>[20]));

      await sub1.cancel();

      reemit.add(30);
      await Future<void>.delayed(Duration.zero);
      expect(listener1Events, equals(<int>[10, 20]));
      expect(listener2Events, equals(<int>[20, 30]));

      await sub2.cancel();
      await reemit.close();
    });

    test('StreamControllerReemit with null initialValue only emits after add', () async {
      final StreamControllerReemit<String> reemit =
          StreamControllerReemit<String>();

      expect(reemit.value, isNull);

      final List<String> events = <String>[];
      final StreamSubscription<String> sub = reemit.stream.listen(events.add);

      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      reemit.add('hello');
      expect(reemit.value, equals('hello'));
      await Future<void>.delayed(Duration.zero);
      expect(events, equals(<String>['hello']));

      await sub.cancel();
      await reemit.close();
    });

    test('StreamNewStreamWithInitialValue on broadcast stream handles listeners, errors, and done', () async {
      final StreamController<int> source = StreamController<int>.broadcast();
      final Stream<int> transformed = source.stream.newStreamWithInitialValue(0);

      final List<int> data = <int>[];
      final List<Object> errors = <Object>[];
      bool doneCalled = false;

      final StreamSubscription<int> sub1 = transformed.listen(
        data.add,
        onError: errors.add,
        onDone: () {
          doneCalled = true;
        },
      );

      await Future<void>.delayed(Duration.zero);
      expect(data, equals(<int>[0]));

      source.add(1);
      source.addError('boom');
      await Future<void>.delayed(Duration.zero);

      expect(data, equals(<int>[0, 1]));
      expect(errors, equals(<Object>['boom']));

      await source.close();
      await Future<void>.delayed(Duration.zero);
      expect(doneCalled, isTrue);

      await sub1.cancel();
    });

    test('StreamNewStreamWithInitialValue on single-subscription stream forwards pause, resume, error, and done', () async {
      final StreamController<int> source = StreamController<int>();
      final Stream<int> transformed =
          source.stream.newStreamWithInitialValue(42);

      final List<int> data = <int>[];
      final List<Object> errors = <Object>[];
      bool doneCalled = false;

      final StreamSubscription<int> sub = transformed.listen(
        data.add,
        onError: errors.add,
        onDone: () {
          doneCalled = true;
        },
      );

      await Future<void>.delayed(Duration.zero);
      expect(data, equals(<int>[42]));

      sub.pause();
      await Future<void>.delayed(Duration.zero);
      expect(source.isPaused, isTrue);

      sub.resume();
      await Future<void>.delayed(Duration.zero);
      expect(source.isPaused, isFalse);

      source.add(99);
      source.addError('err');
      await source.close();
      await Future<void>.delayed(Duration.zero);

      expect(data, equals(<int>[42, 99]));
      expect(errors, equals(<Object>['err']));
      expect(doneCalled, isTrue);

      await sub.cancel();
    });
  });

  group('2.2 Snackbar & prettyException', () {
    test('prettyException formats FlutterBluePlusException, PlatformException, and generic errors', () {
      expect(
        prettyException(
          'Prefix:',
          FlutterBluePlusException(ErrorPlatform.fbp, 'op', 1, 'GATT failed'),
        ),
        equals('Prefix: GATT failed'),
      );
      expect(
        prettyException(
          'Prefix:',
          PlatformException(code: 'ERR', message: 'Native failure'),
        ),
        equals('Prefix: Native failure'),
      );
      expect(
        prettyException('Prefix: ', Exception('Generic')),
        equals('Prefix: Exception: Generic'),
      );
    });

    testWidgets('Snackbar.getSnackbar and Snackbar.show render success and error SnackBars', (WidgetTester tester) async {
      expect(Snackbar.getSnackbar(ABC.a), same(Snackbar.snackBarKeyA));
      expect(Snackbar.getSnackbar(ABC.b), same(Snackbar.snackBarKeyB));
      expect(Snackbar.getSnackbar(ABC.c), same(Snackbar.snackBarKeyC));

      await tester.pumpWidget(
        MaterialApp(
          home: ScaffoldMessenger(
            key: Snackbar.snackBarKeyA,
            child: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      Snackbar.show(ABC.a, 'Operation succeeded', success: true);
      await tester.pump();

      expect(find.text('Operation succeeded'), findsOneWidget);
      final SnackBar successBar =
          tester.widget<SnackBar>(find.byType(SnackBar));
      expect(successBar.backgroundColor, equals(Colors.blue));

      Snackbar.show(ABC.a, 'Operation failed', success: false);
      await tester.pump();

      expect(find.text('Operation failed'), findsOneWidget);
      final SnackBar errorBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(errorBar.backgroundColor, equals(Colors.red));
    });
  });

  group('2.3 Extra Extension on BluetoothDevice', () {
    test('Extra isConnecting, isDisconnecting, connectAndUpdateStream, and disconnectAndUpdateStream', () async {
      final TestBluetoothDevice device = TestBluetoothDevice(
        id: 'AA:BB:CC:DD:EE:99',
        testPlatformName: 'Bluepad32-Test',
      );

      final List<bool> connectingStates = <bool>[];
      final List<bool> disconnectingStates = <bool>[];

      final StreamSubscription<bool> connectSub =
          device.isConnecting.listen(connectingStates.add);
      final StreamSubscription<bool> disconnectSub =
          device.isDisconnecting.listen(disconnectingStates.add);

      await Future<void>.delayed(Duration.zero);
      expect(connectingStates, equals(<bool>[false]));
      expect(disconnectingStates, equals(<bool>[false]));

      await device.connectAndUpdateStream();
      await Future<void>.delayed(Duration.zero);

      expect(device.connectCallCount, equals(1));
      expect(device.lastConnectLicense, equals(License.nonprofit));
      expect(connectingStates, equals(<bool>[false, true, false]));

      await device.disconnectAndUpdateStream(queue: false);
      await Future<void>.delayed(Duration.zero);

      expect(device.disconnectCallCount, equals(1));
      expect(device.lastDisconnectQueue, isFalse);
      expect(disconnectingStates, equals(<bool>[false, true, false]));

      await connectSub.cancel();
      await disconnectSub.cancel();
    });
  });
}
