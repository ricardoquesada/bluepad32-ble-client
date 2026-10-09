// Reactive GATT client service layer and transport abstraction for Bluepad32 BLE peripherals.
//
// Coordinates connection establishment, MTU negotiation, GATT service discovery,
// `AC05` notification streaming, and typed reads/writes across `AC01`–`AC0C`.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/bluepad32_state.dart';
import '../models/bluepad32_uuids.dart';
import '../utils/extra.dart';

export '../models/bluepad32_state.dart';
export '../models/bluepad32_uuids.dart';

/// Abstraction over the BLE GATT transport used by [Bluepad32Client].
///
/// Decouples GATT characteristic reads, writes, notifications, and connection
/// lifecycle from concrete [BluetoothDevice] platform channels so unit and
/// widget tests can deterministically verify client behavior without BLE hardware.
abstract class Bluepad32GattTransport {
  /// Emits peripheral connection state transitions.
  Stream<BluetoothConnectionState> get connectionStateStream;

  /// Emits incoming `AC05` (`connectedDevices`) notification or read payloads.
  Stream<List<int>> get connectedDevicesNotificationStream;

  /// Connects to the peripheral (negotiating MTU), discovers the Bluepad32 GATT
  /// service (`4627c4a4-ac00-46b9-b688-afc5c1bf7f63`), locates characteristics
  /// `AC01`–`AC0C`, and enables notifications on `AC05`.
  Future<void> connectAndDiscover();

  /// Disconnects from the peripheral and cancels active GATT subscriptions.
  Future<void> disconnect();

  /// Reads the raw value of the characteristic identified by [uuid].
  Future<List<int>> readCharacteristic(Guid uuid);

  /// Writes [value] to the characteristic identified by [uuid].
  Future<void> writeCharacteristic(Guid uuid, List<int> value);

  /// Releases any internal stream controllers or subscriptions.
  void dispose();
}

/// Production [Bluepad32GattTransport] backed by a `flutter_blue_plus` [BluetoothDevice].
class _DeviceBluepad32GattTransport implements Bluepad32GattTransport {
  final BluetoothDevice _device;
  final Map<Guid, BluetoothCharacteristic> _characteristics =
      <Guid, BluetoothCharacteristic>{};
  final StreamController<List<int>> _notificationController =
      StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _ac05Subscription;

  _DeviceBluepad32GattTransport(this._device);

  @override
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _device.connectionState;

  @override
  Stream<List<int>> get connectedDevicesNotificationStream =>
      _notificationController.stream;

  @override
  Future<void> connectAndDiscover() async {
    // 1. Connect and await automatic Android MTU=512 negotiation before service discovery.
    await _device.connectAndUpdateStream();

    // 2. Discover GATT services and locate the primary Bluepad32 service.
    final List<BluetoothService> services = await _device.discoverServices();
    BluetoothService? bluepadService;
    for (final BluetoothService service in services) {
      if (service.uuid == Bluepad32Uuids.service) {
        bluepadService = service;
        break;
      }
    }
    if (bluepadService == null) {
      throw StateError(
        'Bluepad32 GATT service (${Bluepad32Uuids.service}) not found on device.',
      );
    }

    // 3. Index characteristics AC01..AC0C by UUID.
    _characteristics.clear();
    for (final BluetoothCharacteristic characteristic
        in bluepadService.characteristics) {
      _characteristics[characteristic.uuid] = characteristic;
    }

    // 4. Subscribe to AC05 (connectedDevices) via onValueReceived to avoid
    // the initial empty `[]` emission from lastValueStream.
    await _ac05Subscription?.cancel();
    _ac05Subscription = null;

    final BluetoothCharacteristic? connectedDevicesChar =
        _characteristics[Bluepad32Uuids.connectedDevices];
    if (connectedDevicesChar != null) {
      final StreamSubscription<List<int>> sub =
          connectedDevicesChar.onValueReceived.listen((List<int> bytes) {
        if (!_notificationController.isClosed) {
          _notificationController.add(bytes);
        }
      });
      _device.cancelWhenDisconnected(sub);
      _ac05Subscription = sub;
      await connectedDevicesChar.setNotifyValue(true);
    }
  }

  @override
  Future<void> disconnect() async {
    await _ac05Subscription?.cancel();
    _ac05Subscription = null;
    _characteristics.clear();
    await _device.disconnectAndUpdateStream();
  }

  @override
  Future<List<int>> readCharacteristic(Guid uuid) async {
    final BluetoothCharacteristic? characteristic = _characteristics[uuid];
    if (characteristic == null) {
      throw StateError('GATT characteristic $uuid is not available.');
    }
    return characteristic.read();
  }

  @override
  Future<void> writeCharacteristic(Guid uuid, List<int> value) async {
    final BluetoothCharacteristic? characteristic = _characteristics[uuid];
    if (characteristic == null) {
      throw StateError('GATT characteristic $uuid is not available.');
    }
    await characteristic.write(value);
  }

  @override
  void dispose() {
    _ac05Subscription?.cancel();
    _ac05Subscription = null;
    _notificationController.close();
  }
}

/// In-memory fake [Bluepad32GattTransport] for unit and widget tests.
///
/// Records all GATT writes and allows tests to seed characteristic read responses,
/// push `AC05` notifications, and simulate disconnection or write exceptions.
class FakeBluepad32GattTransport implements Bluepad32GattTransport {
  final Map<Guid, List<int>> _characteristicValues = <Guid, List<int>>{};
  final Map<Guid, List<Uint8List>> _writeLog = <Guid, List<Uint8List>>{};
  final Map<Guid, Object Function(List<int> value)> _writeThrowers =
      <Guid, Object Function(List<int> value)>{};

  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final StreamController<List<int>> _notificationController =
      StreamController<List<int>>.broadcast();

  /// Number of times [connectAndDiscover] was invoked.
  int connectCallCount = 0;

  /// Number of times [disconnect] was invoked.
  int disconnectCallCount = 0;

  /// Number of times each characteristic was read.
  final Map<Guid, int> readCounts = <Guid, int>{};

  /// Creates an in-memory GATT transport pre-populated with default Bluepad32
  /// characteristic payloads.
  FakeBluepad32GattTransport({
    String firmwareVersion = 'v4.2.0',
    int maxConnections = 4,
    bool bleEnabled = true,
    bool scanningEnabled = false,
    List<ConnectedController>? controllers,
    GamepadMappings mappings = const GamepadMappings(),
    bool allowlistEnabled = false,
    List<MacAddress> allowlistAddresses = const <MacAddress>[],
    bool virtualDevicesEnabled = true,
  }) {
    setCharacteristicValue(
      Bluepad32Uuids.version,
      utf8.encode(firmwareVersion),
    );
    setCharacteristicValue(
      Bluepad32Uuids.maxConnections,
      <int>[maxConnections & 0xFF],
    );
    setCharacteristicValue(
      Bluepad32Uuids.bleEnabled,
      <int>[bleEnabled ? 1 : 0],
    );
    setCharacteristicValue(
      Bluepad32Uuids.scanning,
      <int>[scanningEnabled ? 1 : 0],
    );

    final List<ConnectedController> initialSlots = controllers ??
        List<ConnectedController>.generate(
          maxConnections,
          ConnectedController.empty,
        );
    final BytesBuilder ac05Builder = BytesBuilder(copy: false);
    for (final ConnectedController slot in initialSlots) {
      ac05Builder.add(slot.toBytes());
    }
    setCharacteristicValue(
      Bluepad32Uuids.connectedDevices,
      ac05Builder.toBytes(),
    );
    setCharacteristicValue(
      Bluepad32Uuids.mappings,
      mappings.toBytes(),
    );
    setCharacteristicValue(
      Bluepad32Uuids.allowlistEnabled,
      <int>[allowlistEnabled ? 1 : 0],
    );
    setCharacteristicValue(
      Bluepad32Uuids.allowlistAddresses,
      MacAddress.listToBytes(allowlistAddresses),
    );
    setCharacteristicValue(
      Bluepad32Uuids.virtualDeviceEnabled,
      <int>[virtualDevicesEnabled ? 1 : 0],
    );
  }

  /// Sets the bytes returned when [uuid] is read.
  void setCharacteristicValue(Guid uuid, List<int> bytes) {
    _characteristicValues[uuid] = Uint8List.fromList(bytes);
  }

  /// Configures [writeCharacteristic] for [uuid] to throw the exception returned
  /// by [errorBuilder] after recording the write.
  void setWriteError(Guid uuid, Object Function(List<int> value)? errorBuilder) {
    if (errorBuilder == null) {
      _writeThrowers.remove(uuid);
    } else {
      _writeThrowers[uuid] = errorBuilder;
    }
  }

  /// Returns all payloads written to [uuid] in chronological order.
  List<Uint8List> writesFor(Guid uuid) =>
      List<Uint8List>.unmodifiable(_writeLog[uuid] ?? const <Uint8List>[]);

  /// Returns the most recent payload written to [uuid], or `null` if never written.
  Uint8List? lastWriteFor(Guid uuid) {
    final List<Uint8List>? writes = _writeLog[uuid];
    if (writes == null || writes.isEmpty) {
      return null;
    }
    return writes.last;
  }

  /// Pushes a simulated `AC05` notification payload to the client.
  void emitConnectedDevicesNotification(List<int> bytes) {
    if (!_notificationController.isClosed) {
      _notificationController.add(Uint8List.fromList(bytes));
    }
  }

  /// Pushes a simulated connection state change event to the client.
  void emitConnectionState(BluetoothConnectionState state) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  @override
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<List<int>> get connectedDevicesNotificationStream =>
      _notificationController.stream;

  @override
  Future<void> connectAndDiscover() async {
    connectCallCount++;
    emitConnectionState(BluetoothConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    emitConnectionState(BluetoothConnectionState.disconnected);
  }

  @override
  Future<List<int>> readCharacteristic(Guid uuid) async {
    readCounts[uuid] = (readCounts[uuid] ?? 0) + 1;
    return Uint8List.fromList(_characteristicValues[uuid] ?? const <int>[]);
  }

  @override
  Future<void> writeCharacteristic(Guid uuid, List<int> value) async {
    final Uint8List payload = Uint8List.fromList(value);
    _writeLog.putIfAbsent(uuid, () => <Uint8List>[]).add(payload);
    _characteristicValues[uuid] = payload;

    final Object Function(List<int> value)? thrower = _writeThrowers[uuid];
    if (thrower != null) {
      throw thrower(payload);
    }
  }

  @override
  void dispose() {
    _connectionStateController.close();
    _notificationController.close();
  }
}

/// Service layer managing BLE GATT communication and reactive state for a
/// Bluepad32 peripheral.
class Bluepad32Client extends ChangeNotifier {
  /// Underlying `flutter_blue_plus` device when running on a physical peripheral,
  /// or `null` in headless unit/widget tests.
  final BluetoothDevice? device;

  final Bluepad32GattTransport _transport;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notificationSubscription;
  Bluepad32State _state;
  bool _disposed = false;

  /// Creates a [Bluepad32Client] bound to a real [BluetoothDevice].
  Bluepad32Client({
    required BluetoothDevice this.device,
  })  : _transport = _DeviceBluepad32GattTransport(device),
        _state = const Bluepad32State() {
    _bindStreams();
  }

  /// Creates a [Bluepad32Client] backed by a custom or fake [Bluepad32GattTransport]
  /// and an optional [initialState] for unit and widget tests.
  Bluepad32Client.test({
    this.device,
    Bluepad32GattTransport? transport,
    Bluepad32State initialState = const Bluepad32State(isConnected: true),
  })  : _transport = transport ?? FakeBluepad32GattTransport(),
        _state = initialState {
    _bindStreams();
  }

  /// Current immutable snapshot of the Bluepad32 peripheral's state.
  Bluepad32State get state => _state;

  /// Underlying GATT transport (useful for inspecting fake transport state in tests).
  @visibleForTesting
  Bluepad32GattTransport get transport => _transport;

  void _bindStreams() {
    _notificationSubscription = _transport.connectedDevicesNotificationStream
        .listen(handleConnectedDevicesPayload);
    _connectionSubscription = _transport.connectionStateStream.listen(
      (BluetoothConnectionState connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected &&
            !_state.isConnecting &&
            _state.isConnected) {
          _updateState(
            _state.copyWith(
              isConnected: false,
              isRefreshing: false,
            ),
          );
        }
      },
    );
  }

  void _updateState(Bluepad32State newState) {
    if (_disposed) {
      return;
    }
    _state = newState;
    notifyListeners();
  }

  /// Directly replaces [state] and notifies listeners in unit/widget tests.
  @visibleForTesting
  void updateStateForTesting(Bluepad32State newState) {
    _updateState(newState);
  }

  /// Clears any active [Bluepad32State.errorMessage].
  void clearError() {
    if (_state.errorMessage != null) {
      _updateState(_state.copyWith(clearError: true));
    }
  }

  /// Connects to the Bluepad32 peripheral, negotiates MTU, discovers `AC01`–`AC0C`,
  /// subscribes to `AC05` notifications, and hydrates all state via [refreshAll].
  Future<void> connect() async {
    _updateState(
      _state.copyWith(
        isConnecting: true,
        clearError: true,
      ),
    );

    try {
      await _transport.connectAndDiscover();
      _updateState(
        _state.copyWith(
          isConnecting: false,
          isConnected: true,
          clearError: true,
        ),
      );
      await refreshAll();
    } catch (e) {
      _updateState(
        _state.copyWith(
          isConnecting: false,
          isConnected: false,
          errorMessage: 'Failed to connect to Bluepad32 device: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Disconnects from the Bluepad32 peripheral.
  Future<void> disconnect() async {
    try {
      await _transport.disconnect();
    } catch (e) {
      _updateState(
        _state.copyWith(
          isConnected: false,
          isConnecting: false,
          isRefreshing: false,
          errorMessage: 'Disconnect error: ${_formatError(e)}',
        ),
      );
      return;
    }

    _updateState(
      _state.copyWith(
        isConnected: false,
        isConnecting: false,
        isRefreshing: false,
        clearError: true,
      ),
    );
  }

  /// Sequentially reads characteristics `AC01` through `AC09` and updates [state].
  Future<void> refreshAll() async {
    _updateState(
      _state.copyWith(
        isRefreshing: true,
        clearError: true,
      ),
    );

    try {
      // AC01: Firmware Version (UTF-8 string)
      final List<int> versionBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.version);
      final String version = utf8
          .decode(versionBytes, allowMalformed: true)
          .replaceAll('\x00', '')
          .trim();

      // AC02: Max Supported Connections (uint8_t)
      final List<int> maxConnBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.maxConnections);
      final int maxConnections =
          maxConnBytes.isNotEmpty && (maxConnBytes[0] & 0xFF) > 0
              ? (maxConnBytes[0] & 0xFF)
              : 4;

      // AC03: BLE Connections Enabled (uint8_t)
      final List<int> bleBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.bleEnabled);
      final bool bleEnabled = bleBytes.isNotEmpty && bleBytes[0] != 0;

      // AC04: Scan / Pair New Controllers (uint8_t)
      final List<int> scanBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.scanning);
      final bool scanningEnabled = scanBytes.isNotEmpty && scanBytes[0] != 0;

      // AC05: Connected Controllers (N * 16-byte compact_device_t)
      final List<int> devicesBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.connectedDevices);
      final List<ConnectedController> controllers = _mergeControllers(
        existing: const <ConnectedController>[],
        incomingBytes: devicesBytes,
        maxConnections: maxConnections,
      );

      // AC06: Controller Mappings Type (uint8_t)
      final List<int> mappingsBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.mappings);
      final GamepadMappings mappings = GamepadMappings.fromBytes(mappingsBytes);

      // AC07: Allowlist Enforced (uint8_t)
      final List<int> allowlistEnabledBytes =
          await _transport.readCharacteristic(Bluepad32Uuids.allowlistEnabled);
      final bool allowlistEnabled =
          allowlistEnabledBytes.isNotEmpty && allowlistEnabledBytes[0] != 0;

      // AC08: Allowlist Addresses (K * 6-byte bd_addr_t)
      final List<int> allowlistAddrBytes = await _transport
          .readCharacteristic(Bluepad32Uuids.allowlistAddresses);
      final List<MacAddress> allowlistAddresses =
          MacAddress.listFromBytes(allowlistAddrBytes);

      // AC09: Virtual Devices Enabled (uint8_t)
      final List<int> virtualBytes = await _transport
          .readCharacteristic(Bluepad32Uuids.virtualDeviceEnabled);
      final bool virtualDevicesEnabled =
          virtualBytes.isNotEmpty && virtualBytes[0] != 0;

      _updateState(
        _state.copyWith(
          isRefreshing: false,
          isConnected: true,
          clearError: true,
          firmwareVersion: version.isEmpty ? 'Unknown' : version,
          maxConnections: maxConnections,
          bleEnabled: bleEnabled,
          scanningEnabled: scanningEnabled,
          controllers: controllers,
          mappings: mappings,
          allowlistEnabled: allowlistEnabled,
          allowlistAddresses: allowlistAddresses,
          virtualDevicesEnabled: virtualDevicesEnabled,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          isRefreshing: false,
          errorMessage: 'Failed to read Bluepad32 state: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Processes an incoming `AC05` payload (either a 64-byte full-table packet
  /// or a 16-byte single-slot notification) and merges updated slots by `idx`.
  ///
  /// Ignores payloads shorter than [ConnectedController.byteLength] (such as an
  /// initial empty `[]` emission).
  @visibleForTesting
  void handleConnectedDevicesPayload(List<int> bytes) {
    if (bytes.length < ConnectedController.byteLength) {
      return;
    }

    final List<ConnectedController> merged = _mergeControllers(
      existing: _state.controllers,
      incomingBytes: bytes,
      maxConnections: _state.maxConnections,
    );
    _updateState(_state.copyWith(controllers: merged));
  }

  List<ConnectedController> _mergeControllers({
    required List<ConnectedController> existing,
    required List<int> incomingBytes,
    required int maxConnections,
  }) {
    final Map<int, ConnectedController> byIdx = <int, ConnectedController>{};
    if (existing.isEmpty) {
      for (int i = 0; i < maxConnections; i++) {
        byIdx[i] = ConnectedController.empty(i);
      }
    } else {
      for (final ConnectedController c in existing) {
        byIdx[c.idx] = c;
      }
    }

    for (final ConnectedController updated
        in ConnectedController.listFromBytes(incomingBytes)) {
      byIdx[updated.idx] = updated;
    }

    final List<ConnectedController> result = byIdx.values.toList()
      ..sort((ConnectedController a, ConnectedController b) => a.idx.compareTo(b.idx));
    return List<ConnectedController>.unmodifiable(result);
  }

  /// Enables or disables BLE controller connections on the firmware (`AC03`).
  Future<void> setBleEnabled(bool enabled) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.bleEnabled,
        <int>[enabled ? 1 : 0],
      );
      _updateState(
        _state.copyWith(
          bleEnabled: enabled,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update BLE setting: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Starts or stops controller scanning/autoconnect on the firmware (`AC04`).
  Future<void> setControllerScanning(bool enabled) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.scanning,
        <int>[enabled ? 1 : 0],
      );
      _updateState(
        _state.copyWith(
          scanningEnabled: enabled,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update controller scanning: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Alias for [setControllerScanning].
  Future<void> setScanningEnabled(bool enabled) => setControllerScanning(enabled);

  /// Sets the active controller button mapping layout on the firmware (`AC06`).
  Future<void> setMappingsType(GamepadMappingsType type) async {
    final GamepadMappings updatedMappings = _state.mappings.copyWith(type: type);
    await setMappings(updatedMappings);
  }

  /// Writes [mappings] to `AC06` and updates [state].
  Future<void> setMappings(GamepadMappings mappings) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.mappings,
        mappings.toBytes(),
      );
      _updateState(
        _state.copyWith(
          mappings: mappings,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update controller mappings: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Enables or disables Bluetooth MAC allowlist enforcement (`AC07`).
  Future<void> setAllowlistEnabled(bool enabled) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.allowlistEnabled,
        <int>[enabled ? 1 : 0],
      );
      _updateState(
        _state.copyWith(
          allowlistEnabled: enabled,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update allowlist enforcement: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Replaces the persisted Bluetooth MAC allowlist (`AC08`).
  ///
  /// When [addresses] is empty (or contains only zero addresses), writes
  /// `MacAddress.zero.toBytes()` (`6` zero bytes: `00:00:00:00:00:00`) rather
  /// than a 0-byte payload so Android `BluetoothGatt` and iOS CoreBluetooth
  /// do not reject the write with `INVALID_ATTRIBUTE_VALUE_LENGTH`.
  Future<void> setAllowlistAddresses(List<MacAddress> addresses) async {
    final List<MacAddress> deduplicated = <MacAddress>[];
    for (final MacAddress addr in addresses) {
      if (!addr.isZero && !deduplicated.contains(addr)) {
        deduplicated.add(addr);
      }
    }

    final Uint8List payload = deduplicated.isEmpty
        ? MacAddress.zero.toBytes()
        : MacAddress.listToBytes(deduplicated);

    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.allowlistAddresses,
        payload,
      );
      _updateState(
        _state.copyWith(
          allowlistAddresses: deduplicated,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update allowlist addresses: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Appends [address] to the Bluetooth MAC allowlist (`AC08`) if not already present.
  Future<void> addAllowlistAddress(MacAddress address) async {
    if (address.isZero) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Cannot add all-zero MAC address (00:00:00:00:00:00) to allowlist.',
        ),
      );
      return;
    }
    if (_state.allowlistAddresses.contains(address)) {
      return;
    }
    await setAllowlistAddresses(<MacAddress>[
      ..._state.allowlistAddresses,
      address,
    ]);
  }

  /// Removes [address] from the Bluetooth MAC allowlist (`AC08`).
  Future<void> removeAllowlistAddress(MacAddress address) async {
    final List<MacAddress> remaining = _state.allowlistAddresses
        .where((MacAddress entry) => entry != address)
        .toList(growable: false);
    await setAllowlistAddresses(remaining);
  }

  /// Enables or disables virtual child devices on the firmware (`AC09`).
  Future<void> setVirtualDevicesEnabled(bool enabled) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.virtualDeviceEnabled,
        <int>[enabled ? 1 : 0],
      );
      _updateState(
        _state.copyWith(
          virtualDevicesEnabled: enabled,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to update virtual devices setting: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Disconnects the controller at slot [idx] (`AC0A`).
  Future<void> disconnectController(int idx) async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.disconnectDevice,
        <int>[idx & 0xFF],
      );
      final List<ConnectedController> updated = _state.controllers
          .map(
            (ConnectedController c) =>
                c.idx == idx ? ConnectedController.empty(idx) : c,
          )
          .toList(growable: false);
      _updateState(
        _state.copyWith(
          controllers: updated,
          clearError: true,
        ),
      );
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to disconnect controller #$idx: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Alias for [disconnectController].
  Future<void> disconnectDevice(int idx) => disconnectController(idx);

  /// Deletes all stored Bluetooth bond keys on the Bluepad32 device (`AC0B`).
  Future<void> deleteStoredBondKeys() async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.deleteStoredKeys,
        const <int>[1],
      );
      _updateState(_state.copyWith(clearError: true));
    } catch (e) {
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to delete stored bond keys: ${_formatError(e)}',
        ),
      );
    }
  }

  /// Alias for [deleteStoredBondKeys].
  Future<void> deleteStoredKeys() => deleteStoredBondKeys();

  /// Reboots the Bluepad32 device by writing `[1]` to `AC0C`.
  ///
  /// Because `uni_system_reboot()` executes immediately inside the firmware's
  /// ATT write callback, the peripheral may drop the BLE link before the ATT
  /// Write Response reaches the central. Any disconnection exception thrown
  /// during the `AC0C` write is treated as an expected reboot completion.
  Future<void> resetDevice() async {
    try {
      await _transport.writeCharacteristic(
        Bluepad32Uuids.resetDevice,
        const <int>[1],
      );
      _updateState(
        _state.copyWith(
          isConnected: false,
          isConnecting: false,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } catch (e) {
      if (_isDisconnectionException(e)) {
        _updateState(
          _state.copyWith(
            isConnected: false,
            isConnecting: false,
            isRefreshing: false,
            clearError: true,
          ),
        );
        return;
      }
      _updateState(
        _state.copyWith(
          errorMessage: 'Failed to reset device: ${_formatError(e)}',
        ),
      );
    }
  }

  bool _isDisconnectionException(Object error) {
    if (error is FlutterBluePlusException) {
      if (error.code == FbpErrorCode.deviceIsDisconnected.index) {
        return true;
      }
      final String desc = (error.description ?? '').toLowerCase();
      if (desc.contains('disconnect') || desc.contains('not connected')) {
        return true;
      }
    }
    final String message = error.toString().toLowerCase();
    return message.contains('disconnect') || message.contains('not connected');
  }

  String _formatError(Object error) {
    if (error is FlutterBluePlusException) {
      return error.description ?? error.toString();
    }
    return error.toString();
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _transport.dispose();
    super.dispose();
  }
}
