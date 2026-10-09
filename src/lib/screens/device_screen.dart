// Primary Material 3 dashboard screen for monitoring and configuring a Bluepad32 BLE peripheral.

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bluepad32_client.dart';
import '../utils/snackbar.dart';
import '../widgets/allowlist_card.dart';
import '../widgets/connected_controllers_card.dart';
import '../widgets/mappings_card.dart';
import '../widgets/settings_toggles_card.dart';
import '../widgets/system_actions_card.dart';
import '../widgets/system_info_card.dart';

/// Material 3 dashboard screen for monitoring and configuring a connected
/// Bluepad32 BLE peripheral.
class DeviceScreen extends StatefulWidget {
  /// Target BLE peripheral when launched from `ScanScreen`.
  final BluetoothDevice? device;

  /// Optional injected [Bluepad32Client] for dependency injection and widget tests.
  final Bluepad32Client? client;

  /// Whether to automatically invoke [Bluepad32Client.connect] in [State.initState]
  /// when the client is not yet connected.
  final bool autoConnect;

  /// Creates a [DeviceScreen] bound to either a [device] or an injected [client].
  const DeviceScreen({
    super.key,
    this.device,
    this.client,
    this.autoConnect = true,
  }) : assert(
          device != null || client != null,
          'Either device or client must be provided to DeviceScreen.',
        );

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final Bluepad32Client _client;
  // Tracks whether `_client` was created internally by this state (and should be
  // disposed on unmount) vs. injected externally by a caller or test.
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _client = widget.client!;
      _ownsClient = false;
    } else {
      _client = Bluepad32Client(device: widget.device!);
      _ownsClient = true;
    }

    if (widget.autoConnect &&
        !_client.state.isConnected &&
        !_client.state.isConnecting) {
      _client.connect();
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
    super.dispose();
  }

  String get _deviceTitle {
    final BluetoothDevice? dev = widget.device ?? _client.device;
    if (dev != null && dev.platformName.isNotEmpty) {
      return dev.platformName;
    }
    return 'Bluepad32 Dashboard';
  }

  String? get _remoteId {
    final BluetoothDevice? dev = widget.device ?? _client.device;
    return dev?.remoteId.str;
  }

  Widget _buildConnectionActionButton(
    BuildContext context,
    Bluepad32State state,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (state.isConnecting) {
      return Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: FilledButton.tonalIcon(
          onPressed: _client.disconnect,
          icon: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Cancel'),
        ),
      );
    }

    if (state.isConnected) {
      return Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: FilledButton.tonalIcon(
          key: const Key('appbar_disconnect_button'),
          onPressed: _client.disconnect,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
          icon: const Icon(Icons.bluetooth_disabled, size: 18),
          label: const Text('Disconnect'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: FilledButton.icon(
        key: const Key('appbar_connect_button'),
        onPressed: _client.connect,
        icon: const Icon(Icons.bluetooth_connected, size: 18),
        label: const Text('Connect'),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String errorMessage) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      key: const Key('dashboard_error_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            key: const Key('dismiss_error_button'),
            tooltip: 'Dismiss error',
            onPressed: _client.clearError,
            icon: Icon(
              Icons.close,
              color: colorScheme.onErrorContainer,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: ListenableBuilder(
        listenable: _client,
        builder: (BuildContext context, Widget? _) {
          final Bluepad32State state = _client.state;
          final bool interactive = state.isConnected && !state.isConnecting;

          return Scaffold(
            appBar: AppBar(
              title: Text(_deviceTitle),
              actions: <Widget>[
                _buildConnectionActionButton(context, state),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _client.refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (state.errorMessage != null)
                      _buildErrorBanner(context, state.errorMessage!),
                    SystemInfoCard(
                      state: state,
                      deviceName: _deviceTitle,
                      remoteId: _remoteId,
                      onRefresh: _client.refreshAll,
                    ),
                    const SizedBox(height: 12),
                    ConnectedControllersCard(
                      controllers: state.controllers,
                      maxConnections: state.maxConnections,
                      enabled: interactive,
                      onDisconnect: _client.disconnectController,
                    ),
                    const SizedBox(height: 12),
                    SettingsTogglesCard(
                      bleEnabled: state.bleEnabled,
                      scanningEnabled: state.scanningEnabled,
                      allowlistEnabled: state.allowlistEnabled,
                      enabled: interactive,
                      onBleEnabledChanged: _client.setBleEnabled,
                      onScanningChanged: _client.setControllerScanning,
                      onAllowlistEnabledChanged: _client.setAllowlistEnabled,
                    ),
                    const SizedBox(height: 12),
                    AllowlistCard(
                      addresses: state.allowlistAddresses,
                      allowlistEnabled: state.allowlistEnabled,
                      enabled: interactive,
                      onAddAddress: _client.addAllowlistAddress,
                      onRemoveAddress: _client.removeAllowlistAddress,
                    ),
                    const SizedBox(height: 12),
                    MappingsCard(
                      virtualDevicesEnabled: state.virtualDevicesEnabled,
                      mappings: state.mappings,
                      enabled: interactive,
                      onVirtualDevicesChanged: _client.setVirtualDevicesEnabled,
                      onMappingsTypeChanged: _client.setMappingsType,
                    ),
                    const SizedBox(height: 12),
                    SystemActionsCard(
                      enabled: interactive,
                      onDeleteBondKeys: _client.deleteStoredBondKeys,
                      onResetDevice: _client.resetDevice,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
