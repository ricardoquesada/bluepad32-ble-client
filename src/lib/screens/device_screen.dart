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

  /// Resolves the dashboard title, preferring the live `AC0D` [Bluepad32State.serviceName]
  /// over the OS-cached [BluetoothDevice.platformName] and falling back to
  /// `'Bluepad32 Dashboard'`.
  String get _deviceTitle {
    if (_client.state.serviceName.isNotEmpty) {
      return _client.state.serviceName;
    }
    final BluetoothDevice? dev = widget.device ?? _client.device;
    if (dev != null && dev.platformName.trim().isNotEmpty) {
      return dev.platformName.trim();
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
          final ColorScheme colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      _deviceTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.isPasswordProtected) ...<Widget>[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: state.requiresAuthentication
                          ? 'Locked (Password Required)'
                          : 'Authenticated',
                      child: Icon(
                        state.requiresAuthentication
                            ? Icons.lock_outline
                            : Icons.verified_user_outlined,
                        key: const Key('appbar_auth_badge'),
                        size: 18,
                        color: state.requiresAuthentication
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
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
                      onRenameService: _client.setServiceName,
                    ),
                    const SizedBox(height: 12),
                    if (state.requiresAuthentication)
                      PasswordAuthCard(
                        key: const Key('password_auth_card'),
                        enabled: interactive,
                        errorMessage: state.errorMessage,
                        onAuthenticate: _client.authenticate,
                      )
                    else ...<Widget>[
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
                        onVirtualDevicesChanged:
                            _client.setVirtualDevicesEnabled,
                        onMappingsTypeChanged: _client.setMappingsType,
                      ),
                      const SizedBox(height: 12),
                      SystemActionsCard(
                        enabled: interactive,
                        onDeleteBondKeys: _client.deleteStoredBondKeys,
                        onResetDevice: _client.resetDevice,
                      ),
                    ],
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

/// Material 3 card rendered on [DeviceScreen] when characteristic `AC0E`
/// reports [Bluepad32AuthStatus.required], prompting the user for the service
/// password before unlocking telemetry and configuration cards.
class PasswordAuthCard extends StatefulWidget {
  /// Whether the peripheral is connected and ready to accept password writes.
  final bool enabled;

  /// Optional active authentication error message.
  final String? errorMessage;

  /// Callback that submits the entered password to `AC0E`.
  final Future<bool> Function(String password) onAuthenticate;

  /// Creates a [PasswordAuthCard].
  const PasswordAuthCard({
    super.key,
    required this.enabled,
    required this.onAuthenticate,
    this.errorMessage,
  });

  @override
  State<PasswordAuthCard> createState() => _PasswordAuthCardState();
}

class _PasswordAuthCardState extends State<PasswordAuthCard> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.enabled || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await widget.onAuthenticate(_passwordController.text);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password Authentication Required',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This Bluepad32 BLE service is protected by a password. '
              'Enter the service password to unlock controller telemetry and settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('password_auth_text_field'),
                    controller: _passwordController,
                    enabled: widget.enabled && !_isSubmitting,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Service Password',
                      hintText: 'Enter password (1–31 bytes)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        key: const Key('toggle_password_visibility_button'),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('unlock_service_button'),
                  onPressed: widget.enabled && !_isSubmitting ? _submit : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open, size: 18),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
