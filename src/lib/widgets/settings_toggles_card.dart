// Material 3 dashboard card for toggling BLE radio, controller scanning, MAC allowlist enforcement, and allowed HID device types (`AC03`, `AC04`, `AC07`, `AC10`).

import 'package:flutter/material.dart';

import '../models/bluepad32_state.dart';

/// Material 3 dashboard card containing the connection and security controls:
/// 1. "BLE Connections Enabled" (`AC03`)
/// 2. "Scan / Pair New Controllers" (`AC04`)
/// 3. "Enforce Allowlist" (`AC07`)
/// 4. "Allowed HID Device Types" (`AC10`: Gamepads, Mice, Keyboards)
class SettingsTogglesCard extends StatelessWidget {
  /// Whether BLE controller connections are enabled (`AC03`).
  final bool bleEnabled;

  /// Whether controller inquiry/scanning is active (`AC04`).
  final bool scanningEnabled;

  /// Whether the Bluetooth MAC allowlist is enforced (`AC07`).
  final bool allowlistEnabled;

  /// Bitmask of allowed HID device categories (`AC10`, `0x00`..`0x07`).
  final int allowedHidDeviceTypes;

  /// Whether the switches and filter chips are interactive.
  final bool enabled;

  /// Callback invoked when the user toggles "BLE Connections Enabled" (`AC03`).
  final ValueChanged<bool>? onBleEnabledChanged;

  /// Callback invoked when the user toggles "Scan / Pair New Controllers" (`AC04`).
  final ValueChanged<bool>? onScanningChanged;

  /// Callback invoked when the user toggles "Enforce Allowlist" (`AC07`).
  final ValueChanged<bool>? onAllowlistEnabledChanged;

  /// Callback invoked when the user updates the "Allowed HID Device Types" bitmask (`AC10`).
  final ValueChanged<int>? onAllowedHidDeviceTypesChanged;

  /// Creates a [SettingsTogglesCard].
  const SettingsTogglesCard({
    super.key,
    required this.bleEnabled,
    required this.scanningEnabled,
    required this.allowlistEnabled,
    this.allowedHidDeviceTypes = Bluepad32HidDeviceTypes.all,
    this.enabled = true,
    this.onBleEnabledChanged,
    this.onScanningChanged,
    this.onAllowlistEnabledChanged,
    this.onAllowedHidDeviceTypesChanged,
  });

  void _toggleBit(int bit, bool selected) {
    final ValueChanged<int>? callback = onAllowedHidDeviceTypesChanged;
    if (callback == null) {
      return;
    }
    final int current = allowedHidDeviceTypes & Bluepad32HidDeviceTypes.all;
    final int next = selected ? (current | bit) : (current & ~bit);
    callback(next & Bluepad32HidDeviceTypes.all);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isGamepadAllowed =
        (allowedHidDeviceTypes & Bluepad32HidDeviceTypes.gamepad) != 0;
    final bool isMouseAllowed =
        (allowedHidDeviceTypes & Bluepad32HidDeviceTypes.mouse) != 0;
    final bool isKeyboardAllowed =
        (allowedHidDeviceTypes & Bluepad32HidDeviceTypes.keyboard) != 0;
    final bool chipsInteractive =
        enabled && onAllowedHidDeviceTypesChanged != null;

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
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.devices_other_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Allowed HID Device Types',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Filter which Bluetooth HID device classes are accepted during discovery',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: <Widget>[
                            FilterChip(
                              key: const Key('chip_hid_allow_gamepad'),
                              avatar: const Icon(
                                Icons.sports_esports_outlined,
                                size: 18,
                              ),
                              label: const Text('Gamepads'),
                              selected: isGamepadAllowed,
                              onSelected: chipsInteractive
                                  ? (bool selected) => _toggleBit(
                                        Bluepad32HidDeviceTypes.gamepad,
                                        selected,
                                      )
                                  : null,
                            ),
                            FilterChip(
                              key: const Key('chip_hid_allow_mouse'),
                              avatar: const Icon(
                                Icons.mouse_outlined,
                                size: 18,
                              ),
                              label: const Text('Mice'),
                              selected: isMouseAllowed,
                              onSelected: chipsInteractive
                                  ? (bool selected) => _toggleBit(
                                        Bluepad32HidDeviceTypes.mouse,
                                        selected,
                                      )
                                  : null,
                            ),
                            FilterChip(
                              key: const Key('chip_hid_allow_keyboard'),
                              avatar: const Icon(
                                Icons.keyboard_outlined,
                                size: 18,
                              ),
                              label: const Text('Keyboards'),
                              selected: isKeyboardAllowed,
                              onSelected: chipsInteractive
                                  ? (bool selected) => _toggleBit(
                                        Bluepad32HidDeviceTypes.keyboard,
                                        selected,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
