/// Material 3 dashboard card and interactive 28-field bottom-sheet editor for
/// configuring virtual child devices (`AC09`), controller mapping presets (`AC06`),
/// and the 28-byte `uni_gamepad_mappings_t` custom remapping matrix (`AC0F`).
///
/// Organizes the 28 fields of [CustomGamepadMappings] into 5 logical sections inside
/// [CustomMappingsEditorSheet] (Face & Shoulder Buttons, Analog Sticks & Inversion,
/// D-Pad Directions, Triggers / Pedals, and System & Misc Buttons) with quick preset
/// chips (`Xbox Default`, `Switch A/B & X/Y`, `Swap Sticks`) and a live modified-count
/// badge.
library;

import 'package:flutter/material.dart';

import '../models/gamepad_mappings.dart';

/// Material 3 dashboard card for configuring "Virtual Devices Enabled" (`AC09`),
/// "Controller Mappings Type" (`AC06`: Xbox, Nintendo Switch, or Custom), and
/// the interactive 28-byte "Customize Remapping Matrix" (`AC0F`).
class MappingsCard extends StatelessWidget {
  /// Whether virtual child devices (such as touchpad mice) are enabled (`AC09`).
  final bool virtualDevicesEnabled;

  /// Active controller face-button and custom remapping configuration (`AC06` & `AC0F`).
  final GamepadMappings mappings;

  /// Whether the controls in this card are interactive.
  final bool enabled;

  /// Callback invoked when the user toggles "Virtual Devices Enabled" (`AC09`).
  final ValueChanged<bool>? onVirtualDevicesChanged;

  /// Callback invoked when the user selects a new [GamepadMappingsType] (`AC06`).
  final ValueChanged<GamepadMappingsType>? onMappingsTypeChanged;

  /// Callback invoked when the user applies or resets the 28-byte [CustomGamepadMappings] (`AC0F` / `AC06`).
  final ValueChanged<CustomGamepadMappings>? onApplyCustomMappings;

  /// Alias callback for [onApplyCustomMappings].
  final ValueChanged<CustomGamepadMappings>? onCustomMappingsChanged;

  /// Creates a [MappingsCard].
  const MappingsCard({
    super.key,
    required this.virtualDevicesEnabled,
    required this.mappings,
    this.enabled = true,
    this.onVirtualDevicesChanged,
    this.onMappingsTypeChanged,
    this.onApplyCustomMappings,
    this.onCustomMappingsChanged,
  });

  ValueChanged<CustomGamepadMappings>? get _effectiveOnCustomMappingsChanged =>
      onApplyCustomMappings ?? onCustomMappingsChanged;

  Future<void> _openCustomMappingsEditor(BuildContext context) async {
    final ValueChanged<CustomGamepadMappings>? callback =
        _effectiveOnCustomMappingsChanged;
    if (!enabled || callback == null) {
      return;
    }

    final CustomGamepadMappings? result =
        await showModalBottomSheet<CustomGamepadMappings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return CustomMappingsEditorSheet(
          initialMappings: mappings.customMappings,
        );
      },
    );

    if (result != null) {
      callback(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final ValueChanged<CustomGamepadMappings>? customCallback =
        _effectiveOnCustomMappingsChanged;
    final int remappedCount = mappings.customMappings.modifiedCount;
    final String summaryText = remappedCount == 0
        ? 'Default Xbox layout'
        : '$remappedCount ${remappedCount == 1 ? 'control' : 'controls'} remapped';

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.tune_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Customize Remapping Matrix',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          key: const Key('custom_mappings_summary_text'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: remappedCount > 0
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontWeight: remappedCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (remappedCount > 0) ...<Widget>[
                    TextButton.icon(
                      key: const Key('reset_custom_mappings_button'),
                      onPressed: enabled && customCallback != null
                          ? () => customCallback(
                                CustomGamepadMappings.defaultXbox,
                              )
                          : null,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('Reset'),
                    ),
                    const SizedBox(width: 4),
                  ],
                  FilledButton.tonalIcon(
                    key: const Key('open_custom_mappings_editor_button'),
                    onPressed: enabled && customCallback != null
                        ? () => _openCustomMappingsEditor(context)
                        : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Configure'),
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

/// Interactive Material 3 modal bottom sheet for editing all 28 fields of
/// [CustomGamepadMappings] (`uni_gamepad_mappings_t` / `AC0F`).
class CustomMappingsEditorSheet extends StatefulWidget {
  /// Initial 28-byte custom remapping state used to seed the editor.
  final CustomGamepadMappings initialMappings;

  /// Creates a [CustomMappingsEditorSheet].
  const CustomMappingsEditorSheet({
    super.key,
    this.initialMappings = CustomGamepadMappings.defaultXbox,
  });

  @override
  State<CustomMappingsEditorSheet> createState() =>
      _CustomMappingsEditorSheetState();
}

class _CustomMappingsEditorSheetState extends State<CustomMappingsEditorSheet> {
  late CustomGamepadMappings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialMappings;
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow<T>({
    required BuildContext context,
    required Key dropdownKey,
    required String sourceLabel,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(
              sourceLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: DropdownButtonHideUnderline(
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                child: DropdownButton<T>(
                  key: dropdownKey,
                  value: value,
                  isExpanded: true,
                  isDense: true,
                  items: <DropdownMenuItem<T>>[
                    for (final T item in items)
                      DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          itemLabel(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (T? next) {
                    if (next != null) {
                      onChanged(next);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final int modifiedCount = _draft.modifiedCount;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 1. Sticky Top Header + Quick Preset Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.tune, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Custom Remapping Matrix',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      key: const Key('custom_mappings_live_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: modifiedCount > 0
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$modifiedCount remapped',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: modifiedCount > 0
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    ActionChip(
                      key: const Key('preset_xbox_default_chip'),
                      avatar: const Icon(Icons.restore, size: 16),
                      label: const Text('Xbox Default'),
                      onPressed: () {
                        setState(() {
                          _draft = CustomGamepadMappings.defaultXbox;
                        });
                      },
                    ),
                    KeyedSubtree(
                      key: const Key('preset_switch_ab_xy_chip'),
                      child: ActionChip(
                        key: const Key('preset_switch_layout_chip'),
                        avatar: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Switch A/B & X/Y'),
                        onPressed: () {
                          setState(() {
                            _draft = CustomGamepadMappings.nintendoSwitch;
                          });
                        },
                      ),
                    ),
                    ActionChip(
                      key: const Key('preset_swap_sticks_chip'),
                      avatar: const Icon(Icons.compare_arrows, size: 16),
                      label: const Text('Swap Sticks'),
                      onPressed: () {
                        setState(() {
                          _draft = _draft.withSwappedSticks();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Scrollable 5-Section Body
          Expanded(
            child: ListView(
              key: const Key('custom_mappings_scroll_view'),
              padding: const EdgeInsets.all(16.0),
              children: <Widget>[
                // Section 1: Face & Shoulder Buttons (10)
                _buildSectionCard(
                  context: context,
                  icon: Icons.gamepad_outlined,
                  title: 'Face & Shoulder Buttons',
                  children: <Widget>[
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_a_dropdown'),
                      sourceLabel: 'Physical A (South)',
                      value: _draft.buttonA,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) =>
                          setState(() => _draft = _draft.copyWith(buttonA: v)),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_b_dropdown'),
                      sourceLabel: 'Physical B (East)',
                      value: _draft.buttonB,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) =>
                          setState(() => _draft = _draft.copyWith(buttonB: v)),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_x_dropdown'),
                      sourceLabel: 'Physical X (West)',
                      value: _draft.buttonX,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) =>
                          setState(() => _draft = _draft.copyWith(buttonX: v)),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_y_dropdown'),
                      sourceLabel: 'Physical Y (North)',
                      value: _draft.buttonY,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) =>
                          setState(() => _draft = _draft.copyWith(buttonY: v)),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey:
                          const Key('remap_button_shoulder_l_dropdown'),
                      sourceLabel: 'Left Shoulder (L1)',
                      value: _draft.buttonShoulderL,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonShoulderL: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey:
                          const Key('remap_button_shoulder_r_dropdown'),
                      sourceLabel: 'Right Shoulder (R1)',
                      value: _draft.buttonShoulderR,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonShoulderR: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_trigger_l_dropdown'),
                      sourceLabel: 'Left Trigger (L2)',
                      value: _draft.buttonTriggerL,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonTriggerL: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_trigger_r_dropdown'),
                      sourceLabel: 'Right Trigger (R2)',
                      value: _draft.buttonTriggerR,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonTriggerR: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_thumb_l_dropdown'),
                      sourceLabel: 'Left Thumb (L3)',
                      value: _draft.buttonThumbL,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonThumbL: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_button_thumb_r_dropdown'),
                      sourceLabel: 'Right Thumb (R3)',
                      value: _draft.buttonThumbR,
                      items: GamepadButtonTarget.values,
                      itemLabel: (GamepadButtonTarget t) => t.label,
                      onChanged: (GamepadButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(buttonThumbR: v),
                      ),
                    ),
                  ],
                ),

                // Section 2: Analog Sticks & Inversion (4 axes + 4 inversion switches)
                _buildSectionCard(
                  context: context,
                  icon: Icons.control_camera_outlined,
                  title: 'Analog Sticks & Inversion',
                  children: <Widget>[
                    _buildDropdownRow<GamepadAxisTarget>(
                      context: context,
                      dropdownKey: const Key('remap_axis_x_dropdown'),
                      sourceLabel: 'Left Stick X Axis',
                      value: _draft.axisX,
                      items: GamepadAxisTarget.values,
                      itemLabel: (GamepadAxisTarget t) => t.label,
                      onChanged: (GamepadAxisTarget v) =>
                          setState(() => _draft = _draft.copyWith(axisX: v)),
                    ),
                    SwitchListTile(
                      key: const Key('invert_axis_x_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Invert Left Stick X'),
                      value: _draft.axisXInverted,
                      onChanged: (bool v) => setState(
                        () => _draft = _draft.copyWith(axisXInverted: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadAxisTarget>(
                      context: context,
                      dropdownKey: const Key('remap_axis_y_dropdown'),
                      sourceLabel: 'Left Stick Y Axis',
                      value: _draft.axisY,
                      items: GamepadAxisTarget.values,
                      itemLabel: (GamepadAxisTarget t) => t.label,
                      onChanged: (GamepadAxisTarget v) =>
                          setState(() => _draft = _draft.copyWith(axisY: v)),
                    ),
                    SwitchListTile(
                      key: const Key('invert_axis_y_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Invert Left Stick Y'),
                      value: _draft.axisYInverted,
                      onChanged: (bool v) => setState(
                        () => _draft = _draft.copyWith(axisYInverted: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadAxisTarget>(
                      context: context,
                      dropdownKey: const Key('remap_axis_rx_dropdown'),
                      sourceLabel: 'Right Stick X Axis',
                      value: _draft.axisRx,
                      items: GamepadAxisTarget.values,
                      itemLabel: (GamepadAxisTarget t) => t.label,
                      onChanged: (GamepadAxisTarget v) =>
                          setState(() => _draft = _draft.copyWith(axisRx: v)),
                    ),
                    SwitchListTile(
                      key: const Key('invert_axis_rx_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Invert Right Stick X'),
                      value: _draft.axisRxInverted,
                      onChanged: (bool v) => setState(
                        () => _draft = _draft.copyWith(axisRxInverted: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadAxisTarget>(
                      context: context,
                      dropdownKey: const Key('remap_axis_ry_dropdown'),
                      sourceLabel: 'Right Stick Y Axis',
                      value: _draft.axisRy,
                      items: GamepadAxisTarget.values,
                      itemLabel: (GamepadAxisTarget t) => t.label,
                      onChanged: (GamepadAxisTarget v) =>
                          setState(() => _draft = _draft.copyWith(axisRy: v)),
                    ),
                    SwitchListTile(
                      key: const Key('invert_axis_ry_switch'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Invert Right Stick Y'),
                      value: _draft.axisRyInverted,
                      onChanged: (bool v) => setState(
                        () => _draft = _draft.copyWith(axisRyInverted: v),
                      ),
                    ),
                  ],
                ),

                // Section 3: D-Pad Directions (4)
                _buildSectionCard(
                  context: context,
                  icon: Icons.open_with_outlined,
                  title: 'D-Pad Directions',
                  children: <Widget>[
                    _buildDropdownRow<GamepadDpadTarget>(
                      context: context,
                      dropdownKey: const Key('remap_dpad_up_dropdown'),
                      sourceLabel: 'Physical D-Pad Up',
                      value: _draft.dpadUp,
                      items: GamepadDpadTarget.values,
                      itemLabel: (GamepadDpadTarget t) => t.label,
                      onChanged: (GamepadDpadTarget v) =>
                          setState(() => _draft = _draft.copyWith(dpadUp: v)),
                    ),
                    _buildDropdownRow<GamepadDpadTarget>(
                      context: context,
                      dropdownKey: const Key('remap_dpad_down_dropdown'),
                      sourceLabel: 'Physical D-Pad Down',
                      value: _draft.dpadDown,
                      items: GamepadDpadTarget.values,
                      itemLabel: (GamepadDpadTarget t) => t.label,
                      onChanged: (GamepadDpadTarget v) =>
                          setState(() => _draft = _draft.copyWith(dpadDown: v)),
                    ),
                    _buildDropdownRow<GamepadDpadTarget>(
                      context: context,
                      dropdownKey: const Key('remap_dpad_left_dropdown'),
                      sourceLabel: 'Physical D-Pad Left',
                      value: _draft.dpadLeft,
                      items: GamepadDpadTarget.values,
                      itemLabel: (GamepadDpadTarget t) => t.label,
                      onChanged: (GamepadDpadTarget v) =>
                          setState(() => _draft = _draft.copyWith(dpadLeft: v)),
                    ),
                    _buildDropdownRow<GamepadDpadTarget>(
                      context: context,
                      dropdownKey: const Key('remap_dpad_right_dropdown'),
                      sourceLabel: 'Physical D-Pad Right',
                      value: _draft.dpadRight,
                      items: GamepadDpadTarget.values,
                      itemLabel: (GamepadDpadTarget t) => t.label,
                      onChanged: (GamepadDpadTarget v) => setState(
                        () => _draft = _draft.copyWith(dpadRight: v),
                      ),
                    ),
                  ],
                ),

                // Section 4: Triggers / Pedals (2)
                _buildSectionCard(
                  context: context,
                  icon: Icons.speed_outlined,
                  title: 'Triggers / Pedals',
                  children: <Widget>[
                    _buildDropdownRow<GamepadPedalTarget>(
                      context: context,
                      dropdownKey: const Key('remap_pedal_brake_dropdown'),
                      sourceLabel: 'Brake Trigger (L2)',
                      value: _draft.brake,
                      items: GamepadPedalTarget.values,
                      itemLabel: (GamepadPedalTarget t) => t.label,
                      onChanged: (GamepadPedalTarget v) =>
                          setState(() => _draft = _draft.copyWith(brake: v)),
                    ),
                    _buildDropdownRow<GamepadPedalTarget>(
                      context: context,
                      dropdownKey: const Key('remap_pedal_throttle_dropdown'),
                      sourceLabel: 'Throttle Trigger (R2)',
                      value: _draft.throttle,
                      items: GamepadPedalTarget.values,
                      itemLabel: (GamepadPedalTarget t) => t.label,
                      onChanged: (GamepadPedalTarget v) =>
                          setState(() => _draft = _draft.copyWith(throttle: v)),
                    ),
                  ],
                ),

                // Section 5: System & Misc Buttons (4)
                _buildSectionCard(
                  context: context,
                  icon: Icons.menu,
                  title: 'System & Misc Buttons',
                  children: <Widget>[
                    _buildDropdownRow<GamepadMiscButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_misc_select_dropdown'),
                      sourceLabel: 'Physical Select',
                      value: _draft.miscButtonSelect,
                      items: GamepadMiscButtonTarget.values,
                      itemLabel: (GamepadMiscButtonTarget t) => t.label,
                      onChanged: (GamepadMiscButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(miscButtonSelect: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadMiscButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_misc_start_dropdown'),
                      sourceLabel: 'Physical Start',
                      value: _draft.miscButtonStart,
                      items: GamepadMiscButtonTarget.values,
                      itemLabel: (GamepadMiscButtonTarget t) => t.label,
                      onChanged: (GamepadMiscButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(miscButtonStart: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadMiscButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_misc_system_dropdown'),
                      sourceLabel: 'Physical System',
                      value: _draft.miscButtonSystem,
                      items: GamepadMiscButtonTarget.values,
                      itemLabel: (GamepadMiscButtonTarget t) => t.label,
                      onChanged: (GamepadMiscButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(miscButtonSystem: v),
                      ),
                    ),
                    _buildDropdownRow<GamepadMiscButtonTarget>(
                      context: context,
                      dropdownKey: const Key('remap_misc_capture_dropdown'),
                      sourceLabel: 'Physical Capture',
                      value: _draft.miscButtonCapture,
                      items: GamepadMiscButtonTarget.values,
                      itemLabel: (GamepadMiscButtonTarget t) => t.label,
                      onChanged: (GamepadMiscButtonTarget v) => setState(
                        () => _draft = _draft.copyWith(miscButtonCapture: v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Sticky Bottom Action Bar
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  key: const Key('cancel_custom_mappings_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('apply_custom_mappings_button'),
                  onPressed: () => Navigator.of(context).pop(_draft),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Apply Custom Mappings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
