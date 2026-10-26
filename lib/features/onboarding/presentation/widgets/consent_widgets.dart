import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/theme/app_spacing.dart';

/// A titled paragraph in the consent summary.
class ConsentSection extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A consent toggle with a "Wajib"/"Opsional" tag.
class ConsentToggle extends StatelessWidget {
  const new({
    required this.label,
    required this.tag,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String tag;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: theme.textTheme.bodyLarge),
        subtitle: Text(tag),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}
