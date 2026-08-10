import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_progress.dart';

/// Home tab. Greeting, Today's Focus hero, quick actions, progress, and
/// upcoming exams. Live numbers wire up with the API client (Phase 6 of
/// the mobile plan) — until then every section is an honest empty state.
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
                const SizedBox(height: 20),
                _SectionTitle(title: 'QUICK ACTIONS'),
                const SizedBox(height: 10),
                _QuickActionsGrid(),
                const SizedBox(height: 20),
                _SectionTitle(title: 'YOUR PROGRESS'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _StatRow(
                        icon: Icons.local_fire_department,
                        label: 'Study streak',
                        value: '0 days',
                      ),
                      Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1),
                      _StatRow(
                        icon: Icons.quiz_outlined,
                        label: 'Quizzes completed',
                        value: '—',
                      ),
                      Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1),
                      _StatRow(
                        icon: Icons.notes,
                        label: 'Notes created',
                        value: '—',
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle(title: 'UPCOMING'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Icon(
                        Icons.event_outlined,
                        size: 26,
                        color: g.textMuted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No upcoming exams',
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add an exam and see a countdown here as it approaches.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: g.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: context.glass.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    const actions = [
      (Icons.upload_file, 'Upload notes', AppRoutes.notebooks),
      (Icons.auto_awesome, 'Summarize', AppRoutes.notebooks),
      (Icons.style_outlined, 'Flashcards', AppRoutes.notebooks),
      (Icons.quiz_outlined, 'Quiz', AppRoutes.notebooks),
      (Icons.event_available_outlined, 'Study plan', AppRoutes.study),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = context.isPhone ? 2 : 3;
        final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in actions)
              SizedBox(
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go(a.$3),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: g.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: g.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.$1, size: 20, color: g.primary),
                          const SizedBox(height: 10),
                          Text(
                            a.$2,
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
