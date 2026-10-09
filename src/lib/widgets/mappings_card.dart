// Material 3 dashboard card for configuring virtual child devices (`AC09`) and button mappings (`AC06`).

import 'package:flutter/material.dart';

import '../models/gamepad_mappings.dart';

/// Material 3 dashboard card for configuring "Virtual Devices Enabled" (`AC09`)
/// and "Controller Mappings Type" (`AC06`: Xbox, Nintendo Switch, or Custom).
class MappingsCard extends StatelessWidget {
  /// Whether virtual child devices (such as touchpad mice) are enabled (`AC09`).
  final bool virtualDevicesEnabled;

  /// Active controller face-button mapping configuration (`AC06`).
  final GamepadMappings mappings;

  /// Whether the controls in this card are interactive.
  final bool enabled;

  /// Callback invoked when the user toggles "Virtual Devices Enabled" (`AC09`).
  final ValueChanged<bool>? onVirtualDevicesChanged;

  /// Callback invoked when the user selects a new [GamepadMappingsType] (`AC06`).
  final ValueChanged<GamepadMappingsType>? onMappingsTypeChanged;

  /// Creates a [MappingsCard].
  const MappingsCard({
    super.key,
    required this.virtualDevicesEnabled,
    required this.mappings,
    this.enabled = true,
    this.onVirtualDevicesChanged,
    this.onMappingsTypeChanged,
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
                  Icon(Icons.gamepad_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Virtual Devices & Mappings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('switch_virtual_devices_enabled'),
              secondary: Icon(
                Icons.mouse_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: const Text('Virtual Devices Enabled'),
              subtitle: const Text(
                'Expose secondary controller peripherals (e.g., DualSense touchpad mouse)',
              ),
              value: virtualDevicesEnabled,
              onChanged: enabled ? onVirtualDevicesChanged : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Controller Mappings Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mappings.type.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<GamepadMappingsType>(
                      key: const Key('mappings_type_segmented_button'),
                      segments: <ButtonSegment<GamepadMappingsType>>[
                        for (final GamepadMappingsType preset
                            in GamepadMappingsType.values)
                          ButtonSegment<GamepadMappingsType>(
                            value: preset,
                            label: Text(preset.label),
                          ),
                      ],
                      selected: <GamepadMappingsType>{mappings.type},
                      onSelectionChanged: enabled &&
                              onMappingsTypeChanged != null
                          ? (Set<GamepadMappingsType> selection) {
                              if (selection.isNotEmpty) {
                                onMappingsTypeChanged!(selection.first);
                              }
                            }
                          : null,
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
