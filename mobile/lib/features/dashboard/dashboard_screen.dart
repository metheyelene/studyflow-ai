import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/exam_countdown_card.dart';
import '../authentication/auth_controller.dart';
import '../authentication/auth_models.dart';
import '../notebooks/notebook.dart';
import '../notebooks/notebooks_controller.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import 'dashboard_controller.dart';

/// Home tab — an editorial command center, not a dashboard.
///
/// Composition: greeting → a single subject-led hero (the study space you
/// should continue, in display type, with one CTA) → a quiet AI-allowance
/// bar → numbered recent spaces on hairlines → compact action pills →
/// the next exam. Large type and open canvas carry the hierarchy; the
/// only "box" on the screen is the white glossy CTA.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    // Personal, but deterministic: a time-of-day greeting would make the
    // Home golden (and any regenerated baseline) hour-dependent.
    final auth = ref.watch(authControllerProvider);
    final firstName = auth is AuthAuthenticated
        ? auth.user.name.trim().split(' ').first
        : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          AppSpacing.xl,
          24,
          context.isPhone ? 120 : 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Greeting(firstName: firstName),
                const SizedBox(height: AppSpacing.xxl),
                const _ContinueHero(),
                const SizedBox(height: AppSpacing.xl),
                _UsageBar(dashboard: dashboard),
                const SizedBox(height: AppSpacing.xxxl),
                const _SectionTitle(title: 'RECENT'),
                const SizedBox(height: 6),
                const _RecentSpaces(),
                const SizedBox(height: AppSpacing.xxxl),
                const _SectionTitle(title: 'QUICK'),
                const SizedBox(height: 12),
                const _QuickActions(),
                const SizedBox(height: AppSpacing.xxxl),
                const _SectionTitle(title: 'UPCOMING'),
                const SizedBox(height: 12),
                _UpcomingExams(dashboard: dashboard),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Editorial greeting: a tracked eyebrow, the first name in confident
/// display type, and one quiet line. The name — not a card — opens the
/// screen.
class _Greeting extends StatelessWidget {
  const _Greeting({this.firstName});

  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK',
          style: AppText.eyebrow.copyWith(
            color: g.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          firstName ?? 'Friend',
          style: TextStyle(
            color: g.textPrimary,
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to study?',
          style: TextStyle(color: g.textMuted, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }
}

/// The single dominant moment: the study space to continue, in large
/// display type on the open canvas, with one primary CTA. The subject —
/// not a stat — is the hero.
class _ContinueHero extends ConsumerWidget {
  const _ContinueHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(notebooksControllerProvider);

    return state.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          GlassSkeleton(width: 150, height: 14),
          SizedBox(height: 12),
          GlassSkeleton(width: 260, height: 44),
          SizedBox(height: 12),
          GlassSkeleton(width: 190, height: 13),
        ],
      ),
      error: (_, _) => _HeroEmpty(
        onTap: () => context.go(AppRoutes.notebooks),
        title: 'Add your first study space',
        sub: 'Upload a PDF or your notes and StudyFlow will organize them.',
      ),
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return _HeroEmpty(
            onTap: () => context.go(AppRoutes.notebooks),
            title: 'Your study space is empty',
            sub: 'Upload a PDF or your notes and StudyFlow will organize them.',
          );
        }
        final focus = notebooks.first;
        final count = focus.sourceCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONTINUE STUDYING',
              style: AppText.eyebrow.copyWith(
                color: g.primary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              focus.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: g.textPrimary,
                fontSize: 40,
                height: 1.04,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              count == 1 ? '1 source' : '$count sources',
              style: AppText.eyebrow.copyWith(
                color: g.textMuted,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassButton(
              label: 'Continue studying',
              icon: Icons.arrow_forward,
              size: GlassButtonSize.large,
              expand: true,
              onPressed: () => context.push('/notebooks/${focus.id}'),
            ),
          ],
        );
      },
    );
  }
}

/// A calm empty-hero for a brand-new user: the same editorial moment, but
/// inviting creation.
class _HeroEmpty extends StatelessWidget {
  const _HeroEmpty({
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'START HERE',
          style: AppText.eyebrow.copyWith(color: g.primary, letterSpacing: 1.4),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: g.textPrimary,
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          sub,
          style: TextStyle(color: g.textMuted, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassButton(
          label: 'Create a study space',
          icon: Icons.add,
          size: GlassButtonSize.large,
          expand: true,
          onPressed: onTap,
        ),
      ],
    );
  }
}

/// The AI allowance — a supporting detail, not the hero. A thin progress
/// bar and a compact line carry the stat that used to dominate.
class _UsageBar extends ConsumerWidget {
  const _UsageBar({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return dashboard.when(
      loading: () => const GlassSkeleton(width: 220, height: 20),
      error: (_, _) => Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 18,
            color: g.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load your usage.',
              style: AppText.small.copyWith(color: g.textMuted),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
            style: TextButton.styleFrom(
              foregroundColor: g.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (snapshot) {
        final usage = snapshot.usage;
        final planLabel = switch (usage.plan) {
          'premium' => 'Premium',
          'founding_member' => 'Founding member',
          _ => 'Free plan',
        };
        final remaining = usage.remaining;
        final frac = (usage.percent / 100).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$remaining',
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 22,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      'AI actions left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(color: g.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      planLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.caption.copyWith(color: g.textMuted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Thin monochrome allowance bar.
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Container(color: g.textPrimary.withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: frac,
                      child: Container(color: g.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Resets on the 1st',
              style: AppText.caption.copyWith(
                color: g.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppText.eyebrow.copyWith(
            color: context.glass.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: context.glass.textPrimary.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

/// Recent study spaces — a numbered editorial list on the open canvas
/// (hairline dividers, no card box).
class _RecentSpaces extends ConsumerWidget {
  const _RecentSpaces();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(notebooksControllerProvider);
    return state.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          GlassSkeleton(width: 210, height: 16),
          SizedBox(height: 10),
          GlassSkeleton(width: 150, height: 13),
        ],
      ),
      error: (_, _) => Text(
        'Could not load your study spaces.',
        style: AppText.small.copyWith(color: g.textMuted),
      ),
      data: (notebooks) {
        if (notebooks.isEmpty) {
          return Text(
            'Your study spaces will appear here.',
            style: AppText.small.copyWith(color: g.textMuted),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < notebooks.length; i++) ...[
              _SpaceRow(index: i + 1, notebook: notebooks[i]),
              if (i != notebooks.length - 1)
                Divider(
                  color: g.textPrimary.withValues(alpha: 0.06),
                  height: 1,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One notebook row: index numeral, title, source metadata, chevron.
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({required this.index, required this.notebook});

  final int index;
  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final count = notebook.sourceCount;
    return InkWell(
      onTap: () => context.push('/notebooks/${notebook.id}'),
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: g.textMuted.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium.copyWith(color: g.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1 ? '1 source' : '$count sources',
                    style: AppText.small.copyWith(color: g.textMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: g.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact glossy action pills in one horizontal row — floating controls,
/// not a tile grid.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  // (icon, label, route, isShellTab): shell tabs switch via context.go;
  // dedicated screens push over the shell.
  static const _actions = [
    (Icons.auto_awesome, 'Ask AI', AppRoutes.notebooks, true),
    (Icons.style, 'Flashcards', AppRoutes.flashcards, false),
    (Icons.quiz, 'Quiz', AppRoutes.quizzes, false),
    (Icons.mic, 'Podcast', AppRoutes.audio, true),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _actions.length; i++) ...[
            if (i != 0) const SizedBox(width: 10),
            GlassButton(
              label: _actions[i].$2,
              icon: _actions[i].$1,
              variant: GlassButtonVariant.glass,
              size: GlassButtonSize.medium,
              onPressed: () {
                final action = _actions[i];
                // Shell tabs switch via go; dedicated screens push over
                // the shell (matching the pre-pill behavior).
                action.$4 ? context.go(action.$3) : context.push(action.$3);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingExams extends ConsumerWidget {
  const _UpcomingExams({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return dashboard.when(
      loading: () => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            GlassSkeleton(width: 180, height: 15),
            SizedBox(height: 10),
            GlassSkeleton(width: 260, height: 12),
          ],
        ),
      ),
      error: (_, _) => GlassCard(
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: 22,
              color: g.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load your exams.',
                style: AppText.small.copyWith(color: g.textMuted),
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
              style: TextButton.styleFrom(foregroundColor: g.primary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (snapshot) {
        if (snapshot.exams.isEmpty) {
          return GlassCard(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Icon(
                  Icons.event,
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
                  'Exams from your study setup appear here with a countdown as they approach.',
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: g.textMuted),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final exam in snapshot.exams) ...[
              ExamCountdownCard(exam: exam),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
