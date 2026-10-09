// Material 3 dashboard card presenting firmware telemetry (`AC01`, `AC02`),
// BLE service identity (`AC0D`), authentication state (`AC0E`), and connection status.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/bluepad32_client.dart';

/// Material 3 dashboard card displaying Bluepad32 firmware version (`AC01`),
/// BLE service name (`AC0D`) with inline rename dialog, authentication status
/// (`AC0E`), BLE connection status, active vs. maximum controller slots (`AC02`),
/// and a manual refresh action.
class SystemInfoCard extends StatelessWidget {
  /// Current immutable state of the Bluepad32 peripheral.
  final Bluepad32State state;

  /// Callback invoked when the user taps the manual Refresh button.
  final VoidCallback? onRefresh;

  /// Callback invoked when the user submits a new service name (`AC0D`).
  final Future<void> Function(String name)? onRenameService;

  /// Optional fallback display name of the BLE peripheral.
  final String? deviceName;

  /// Optional hardware/remote identifier string of the BLE peripheral.
  final String? remoteId;

  /// Creates a [SystemInfoCard].
  const SystemInfoCard({
    super.key,
    required this.state,
    this.onRefresh,
    this.onRenameService,
    this.deviceName,
    this.remoteId,
  });

  Future<void> _showRenameDialog(
    BuildContext context,
    String initialName,
  ) async {
    if (onRenameService == null) {
      return;
    }
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _RenameServiceDialog(
        initialName: initialName,
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await onRenameService!(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int activeCount = state.activeControllers.length;
    final String firmwareLabel = state.firmwareVersion ?? 'Unknown';
    final String effectiveDeviceName = state.serviceName.isNotEmpty
        ? state.serviceName
        : (deviceName != null && deviceName!.isNotEmpty
            ? deviceName!
            : 'Bluepad32 System Info');
    final String initialRenameValue = state.serviceName.isNotEmpty
        ? state.serviceName
        : (deviceName != null &&
                deviceName!.isNotEmpty &&
                deviceName != 'Bluepad32 Dashboard'
            ? deviceName!
            : 'Bluepad32');
    final bool canEditServiceName = state.isConnected &&
        !state.isConnecting &&
        !state.requiresAuthentication &&
        onRenameService != null;

    final (String statusLabel, Color badgeBg, Color badgeFg, IconData statusIcon) =
        switch ((state.isConnecting, state.isConnected)) {
      (true, _) => (
          'Connecting...',
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          Icons.bluetooth_searching,
        ),
      (false, true) => (
          'Connected',
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
          Icons.bluetooth_connected,
        ),
      (false, false) => (
          'Disconnected',
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Icons.bluetooth_disabled,
        ),
    };

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
                  Icons.memory,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Service Name',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              effectiveDeviceName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onRenameService != null) ...<Widget>[
                            const SizedBox(width: 4),
                            IconButton(
                              key: const Key('edit_service_name_button'),
                              tooltip: 'Rename Bluepad32 Service',
                              visualDensity: VisualDensity.compact,
                              onPressed: canEditServiceName
                                  ? () => _showRenameDialog(
                                        context,
                                        initialRenameValue,
                                      )
                                  : null,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                          ],
                        ],
                      ),
                      if (remoteId != null && remoteId!.isNotEmpty)
                        Text(
                          remoteId!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (state.isPasswordProtected) ...<Widget>[
                  Container(
                    key: const Key('system_info_auth_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: state.requiresAuthentication
                          ? colorScheme.errorContainer
                          : colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          state.requiresAuthentication
                              ? Icons.lock_outline
                              : Icons.verified_user_outlined,
                          size: 14,
                          color: state.requiresAuthentication
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          state.requiresAuthentication
                              ? 'Locked'
                              : 'Authenticated',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: state.requiresAuthentication
                                ? colorScheme.onErrorContainer
                                : colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  key: const Key('connection_status_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(statusIcon, size: 14, color: badgeFg),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: badgeFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('system_info_refresh_button'),
                  tooltip: 'Refresh',
                  onPressed: state.isConnected && !state.isRefreshing
                      ? onRefresh
                      : null,
                  icon: state.isRefreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricTile(
                    icon: Icons.developer_board,
                    label: 'Firmware Version',
                    value: firmwareLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.sports_esports,
                    label: 'Active Controllers',
                    value: state.requiresAuthentication
                        ? 'Locked'
                        : '$activeCount / ${state.maxConnections}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog for editing the peripheral's advertised BLE service name (`AC0D`),
/// enforcing the `1..29` UTF-8 byte budget required by the 31-byte Legacy BLE
/// Scan Response (`SCAN_RSP`) PDU (`2B AD header + <= 29B Complete Local Name`).
class _RenameServiceDialog extends StatefulWidget {
  final String initialName;

  const _RenameServiceDialog({
    required this.initialName,
  });

  @override
  State<_RenameServiceDialog> createState() => _RenameServiceDialogState();
}

class _RenameServiceDialogState extends State<_RenameServiceDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Service name cannot be empty.';
      });
      return;
    }
    final int byteLength = utf8.encode(trimmed).length;
    if (byteLength > Bluepad32Client.maxServiceNameBytes) {
      setState(() {
        _errorText =
            'Service name must be ${Bluepad32Client.maxServiceNameBytes} UTF-8 bytes or fewer.';
      });
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Bluepad32 Service'),
      content: TextField(
        key: const Key('service_name_text_field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Service Name',
          hintText: 'Bluepad32 rc car',
          helperText: '1–29 UTF-8 bytes (advertised over BLE)',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('cancel_rename_service_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_rename_service_button'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Compact summary pill inside [SystemInfoCard] displaying a labeled telemetry metric.
class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
