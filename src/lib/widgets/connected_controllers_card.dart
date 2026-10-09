// Material 3 dashboard card displaying active controller slots (`AC05`) and per-slot disconnect actions (`AC0A`).

import 'package:flutter/material.dart';

import '../models/connected_controller.dart';

/// Material 3 dashboard card rendering active controllers from `AC05` and
/// providing per-slot disconnection (`AC0A`).
class ConnectedControllersCard extends StatelessWidget {
  /// All controller slots reported by characteristic `AC05`.
  final List<ConnectedController> controllers;

  /// Maximum concurrent controller connections supported by the firmware (`AC02`).
  final int maxConnections;

  /// Whether interactive controls (such as per-slot Disconnect buttons) are enabled.
  final bool enabled;

  /// Callback invoked with the target slot `idx` when the user taps Disconnect (`AC0A`).
  final ValueChanged<int>? onDisconnect;

  /// Creates a [ConnectedControllersCard].
  const ConnectedControllersCard({
    super.key,
    required this.controllers,
    this.maxConnections = 4,
    this.enabled = true,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ConnectedController> activeControllers = controllers
        .where((ConnectedController c) => c.isConnected)
        .toList(growable: false);

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
                Icon(Icons.sports_esports, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connected Controllers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${activeControllers.length} / $maxConnections active',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeControllers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.videogame_asset_off_outlined,
                      size: 36,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No controllers connected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enable "Scan / Pair New Controllers" below to pair a gamepad.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: <Widget>[
                  for (int i = 0; i < activeControllers.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 10),
                    _ControllerSlotTile(
                      controller: activeControllers[i],
                      enabled: enabled,
                      onDisconnect: onDisconnect != null
                          ? () => onDisconnect!(activeControllers[i].idx)
                          : null,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ControllerSlotTile extends StatelessWidget {
  final ConnectedController controller;
  final bool enabled;
  final VoidCallback? onDisconnect;

  const _ControllerSlotTile({
    required this.controller,
    required this.enabled,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasSubtype =
        controller.controllerSubtype != Bluepad32ControllerSubtype.none;

    final Color stateBadgeBg = controller.isReady
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;
    final Color stateBadgeFg = controller.isReady
        ? colorScheme.onPrimaryContainer
        : colorScheme.onTertiaryContainer;

    return Container(
      key: Key('controller_slot_${controller.idx}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: colorScheme.primary,
                child: Icon(controller.controllerType.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${controller.idx}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.controllerType.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hasSubtype) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        controller.controllerSubtype.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          controller.address.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '•',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          controller.vendorProductHex,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: Key('disconnect_controller_${controller.idx}'),
                onPressed: enabled ? onDisconnect : null,
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Disconnect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _BadgeChip(
                icon: controller.isReady
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top,
                label: controller.state.displayName,
                backgroundColor: stateBadgeBg,
                foregroundColor: stateBadgeFg,
              ),
              _BadgeChip(
                icon: controller.incoming
                    ? Icons.call_received
                    : Icons.call_made,
                label: controller.incoming ? 'Incoming' : 'Outgoing',
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foregroundColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
