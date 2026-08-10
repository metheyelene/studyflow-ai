import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_progress.dart';

/// Home tab. Greeting + Today's Focus hero; the live data wiring lands
/// with the API client (Phase 6 of the mobile plan).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(color: g.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to study?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                GlassCard(
                  tone: GlassTone.floating,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S FOCUS",
                        style: TextStyle(
                          color: g.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your first note to start building a study system.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const GlassRing(value: 0, label: '0/20'),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI actions',
                                  style: TextStyle(color: g.textMuted, fontSize: 13),
                                ),
                                Text(
                                  'resets on the 1st',
                                  style: TextStyle(
                                    color: g.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR PROGRESS',
                        style: TextStyle(
                          color: g.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        icon: Icons.local_fire_department,
                        label: 'Study streak',
                        value: '0 days',
                      ),
                      const Divider(color: Color(0x14000000), height: 1),
                      _StatRow(
                        icon: Icons.quiz_outlined,
                        label: 'Quizzes completed',
                        value: '—',
                      ),
                      const Divider(color: Color(0x14000000), height: 1),
                      _StatRow(
                        icon: Icons.notes,
                        label: 'Notes created',
                        value: '—',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: g.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: g.textMuted, fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              color: g.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
