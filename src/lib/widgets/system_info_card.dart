// Material 3 dashboard card presenting firmware telemetry (`AC01`, `AC02`) and BLE connection status.

import 'package:flutter/material.dart';

import '../models/bluepad32_state.dart';

/// Material 3 dashboard card displaying Bluepad32 firmware version (`AC01`),
/// BLE connection status, active vs. maximum controller slots (`AC02`), and
/// a manual refresh action.
class SystemInfoCard extends StatelessWidget {
  /// Current immutable state of the Bluepad32 peripheral.
  final Bluepad32State state;

  /// Callback invoked when the user taps the manual Refresh button.
  final VoidCallback? onRefresh;

  /// Optional display name of the BLE peripheral.
  final String? deviceName;

  /// Optional hardware/remote identifier string of the BLE peripheral.
  final String? remoteId;

  /// Creates a [SystemInfoCard].
  const SystemInfoCard({
    super.key,
    required this.state,
    this.onRefresh,
    this.deviceName,
    this.remoteId,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int activeCount = state.activeControllers.length;
    final String firmwareLabel = state.firmwareVersion ?? 'Unknown';

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
                        deviceName != null && deviceName!.isNotEmpty
                            ? deviceName!
                            : 'Bluepad32 System Info',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                    value: '$activeCount / ${state.maxConnections}',
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
