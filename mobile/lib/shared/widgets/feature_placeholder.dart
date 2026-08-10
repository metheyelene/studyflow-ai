import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass/glass_card.dart';

/// Honest empty state for features that are still being built — never a
/// dead screen: it explains what is coming and where it lives today.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.note,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlassCard(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, size: 26, color: g.primary),
                ),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
                ),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    note!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: g.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
