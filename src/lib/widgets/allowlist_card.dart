// Material 3 dashboard card and modal input dialog for managing the Bluetooth MAC allowlist (`AC08`).

import 'package:flutter/material.dart';

import '../models/mac_address.dart';

/// Material 3 dashboard card displaying the Bluetooth MAC allowlist (`AC08`),
/// allowing removal of entries and addition of validated MAC addresses via a
/// modal [AlertDialog].
class AllowlistCard extends StatelessWidget {
  /// Non-zero Bluetooth MAC addresses currently persisted in the allowlist (`AC08`).
  final List<MacAddress> addresses;

  /// Whether allowlist enforcement (`AC07`) is currently active on the firmware.
  final bool allowlistEnabled;

  /// Whether add/remove actions are interactive.
  final bool enabled;

  /// Callback invoked when a validated [MacAddress] is submitted via the Add dialog.
  final ValueChanged<MacAddress>? onAddAddress;

  /// Callback invoked when the user deletes an existing [MacAddress] from the allowlist.
  final ValueChanged<MacAddress>? onRemoveAddress;

  /// Creates an [AllowlistCard].
  const AllowlistCard({
    super.key,
    required this.addresses,
    this.allowlistEnabled = false,
    this.enabled = true,
    this.onAddAddress,
    this.onRemoveAddress,
  });

  Future<void> _showAddMacDialog(BuildContext context) async {
    final MacAddress? added = await showDialog<MacAddress>(
      context: context,
      builder: (BuildContext dialogContext) => _AddMacAddressDialog(
        existingAddresses: addresses,
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (added != null) {
      onAddAddress?.call(added);
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
                Icon(Icons.shield_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bluetooth Allowlist',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        allowlistEnabled
                            ? 'Allowlist enforcement is active'
                            : 'Allowlist enforcement is currently disabled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const Key('add_mac_address_button'),
                  onPressed: enabled ? () => _showAddMacDialog(context) : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add MAC Address'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (addresses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No MAC addresses in allowlist.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: <Widget>[
                  for (int i = 0; i < addresses.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 8),
                    Container(
                      key: Key('allowlist_mac_${addresses[i]}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.perm_device_information,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              addresses[i].toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('delete_mac_${addresses[i]}'),
                            tooltip: 'Remove ${addresses[i]}',
                            onPressed: enabled && onRemoveAddress != null
                                ? () => onRemoveAddress!(addresses[i])
                                : null,
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
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

class _AddMacAddressDialog extends StatefulWidget {
  final List<MacAddress> existingAddresses;

  const _AddMacAddressDialog({
    required this.existingAddresses,
  });

  @override
  State<_AddMacAddressDialog> createState() => _AddMacAddressDialogState();
}

class _AddMacAddressDialogState extends State<_AddMacAddressDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateMac(String? value) {
    final String raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Please enter a Bluetooth MAC address (AA:BB:CC:DD:EE:FF).';
    }
    final MacAddress? parsed = MacAddress.tryParse(raw);
    if (parsed == null) {
      return 'Invalid MAC format. Use AA:BB:CC:DD:EE:FF.';
    }
    if (parsed.isZero) {
      return 'Cannot add all-zero address (00:00:00:00:00:00).';
    }
    if (widget.existingAddresses.contains(parsed)) {
      return 'MAC address ${parsed.toString()} is already in the allowlist.';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final MacAddress parsed = MacAddress.parse(_controller.text);
      Navigator.of(context).pop(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add MAC Address'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Enter a 6-octet hexadecimal Bluetooth MAC address:',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('mac_address_text_field'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'MAC Address',
                hintText: 'AA:BB:CC:DD:EE:FF',
                border: OutlineInputBorder(),
              ),
              validator: _validateMac,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_add_mac_button'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
