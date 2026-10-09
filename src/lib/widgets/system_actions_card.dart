// Material 3 Danger Zone dashboard card for destructive/system actions (`AC0B` and `AC0C`).

import 'package:flutter/material.dart';

/// Material 3 Danger Zone dashboard card providing confirmation-guarded buttons
/// for "Delete Stored Bond Keys" (`AC0B`) and "Reset / Reboot Device" (`AC0C`).
class SystemActionsCard extends StatelessWidget {
  /// Whether the system action buttons are interactive.
  final bool enabled;

  /// Callback invoked after the user confirms deleting stored Bluetooth bond keys (`AC0B`).
  final VoidCallback? onDeleteBondKeys;

  /// Callback invoked after the user confirms rebooting the Bluepad32 device (`AC0C`).
  final VoidCallback? onResetDevice;

  /// Creates a [SystemActionsCard].
  const SystemActionsCard({
    super.key,
    this.enabled = true,
    this.onDeleteBondKeys,
    this.onResetDevice,
  });

  Future<void> _confirmDeleteBondKeys(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Delete Stored Bond Keys?'),
          content: const Text(
            'This will erase all stored Bluetooth BR/EDR and BLE pairing keys '
            'on the Bluepad32 device. Previously paired controllers will need '
            'to be paired again.',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel_delete_bond_keys_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_delete_bond_keys_button'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Keys'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    if (confirmed == true) {
      onDeleteBondKeys?.call();
    }
  }

  Future<void> _confirmResetDevice(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Reset / Reboot Device?'),
          content: const Text(
            'This will immediately reboot the Bluepad32 microcontroller and '
            'disconnect all active controllers and BLE clients.',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel_reset_device_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_reset_device_button'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reboot'),
            ),
          ],
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    if (confirmed == true) {
      onResetDevice?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.errorContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                const SizedBox(width: 10),
                Text(
                  'Danger Zone',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'System maintenance actions take effect immediately on the Bluepad32 hardware.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const Key('delete_bond_keys_button'),
                  onPressed: enabled && onDeleteBondKeys != null
                      ? () => _confirmDeleteBondKeys(context)
                      : null,
                  icon: const Icon(Icons.key_off_outlined, size: 18),
                  label: const Text('Delete Stored Bond Keys'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('reset_device_button'),
                  onPressed: enabled && onResetDevice != null
                      ? () => _confirmResetDevice(context)
                      : null,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset / Reboot Device'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
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
