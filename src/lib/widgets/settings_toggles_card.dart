// Material 3 dashboard card for toggling BLE radio, controller scanning, and MAC allowlist enforcement (`AC03`, `AC04`, `AC07`).

import 'package:flutter/material.dart';

/// Material 3 dashboard card containing the three connection and security
/// toggle switches:
/// 1. "BLE Connections Enabled" (`AC03`)
/// 2. "Scan / Pair New Controllers" (`AC04`)
/// 3. "Enforce Allowlist" (`AC07`)
class SettingsTogglesCard extends StatelessWidget {
  /// Whether BLE controller connections are enabled (`AC03`).
  final bool bleEnabled;

  /// Whether controller inquiry/scanning is active (`AC04`).
  final bool scanningEnabled;

  /// Whether the Bluetooth MAC allowlist is enforced (`AC07`).
  final bool allowlistEnabled;

  /// Whether the switches are interactive.
  final bool enabled;

  /// Callback invoked when the user toggles "BLE Connections Enabled" (`AC03`).
  final ValueChanged<bool>? onBleEnabledChanged;

  /// Callback invoked when the user toggles "Scan / Pair New Controllers" (`AC04`).
  final ValueChanged<bool>? onScanningChanged;

  /// Callback invoked when the user toggles "Enforce Allowlist" (`AC07`).
  final ValueChanged<bool>? onAllowlistEnabledChanged;

  /// Creates a [SettingsTogglesCard].
  const SettingsTogglesCard({
    super.key,
    required this.bleEnabled,
    required this.scanningEnabled,
    required this.allowlistEnabled,
    this.enabled = true,
    this.onBleEnabledChanged,
    this.onScanningChanged,
    this.onAllowlistEnabledChanged,
  });

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
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: <Widget>[
                  Icon(Icons.tune, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Connections & Security',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('switch_ble_enabled'),
              secondary: Icon(
                Icons.bluetooth,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('BLE Connections Enabled'),
              subtitle: const Text(
                'Allow Bluetooth Low Energy gamepads and clients to connect',
              ),
              value: bleEnabled,
              onChanged: enabled ? onBleEnabledChanged : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              key: const Key('switch_scanning_enabled'),
              secondary: Icon(
                Icons.radar,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('Scan / Pair New Controllers'),
              subtitle: const Text(
                'Actively scan for and pair nearby controllers in pairing mode',
              ),
              value: scanningEnabled,
              onChanged: enabled ? onScanningChanged : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              key: const Key('switch_allowlist_enabled'),
              secondary: Icon(
                Icons.verified_user_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('Enforce Allowlist'),
              subtitle: const Text(
                'Only accept connections from MAC addresses in the allowlist',
              ),
              value: allowlistEnabled,
              onChanged: enabled ? onAllowlistEnabledChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
