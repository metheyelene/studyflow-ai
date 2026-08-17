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
import 'dashboard_repository.dart';

/// Home tab — an editorial composition, not a dashboard.
///
/// One hero focus (Today's Focus), large typography, generous negative
/// space. The greeting is the entry; the hero is the single dominant
/// moment (a big numeral on the open canvas — no card box); sections
/// below it are quiet supporting rows. Live widgets (AI usage, exams)
/// come from the API with skeleton/error states; nothing is invented.
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
          20,
          AppSpacing.xl,
          20,
          context.isPhone ? 120 : 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Greeting(firstName: firstName),
                const SizedBox(height: AppSpacing.huge),
                _FocusHero(dashboard: dashboard),
                const SizedBox(height: AppSpacing.huge),
                const _SectionTitle(title: 'RECENT SPACES'),
                const SizedBox(height: 8),
                const _RecentSpaces(),
                const SizedBox(height: AppSpacing.xxxl),
                const _SectionTitle(title: 'QUICK ACTIONS'),
                const SizedBox(height: 14),
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

/// Editorial greeting: small tracked eyebrow, the first name in display
/// type, and one quiet supporting line. The name — not a card — is the
/// entry to the screen.
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
          style: AppText.eyebrow.copyWith(color: g.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          firstName ?? 'Friend',
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(color: g.textPrimary),
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

/// Today's Focus — the one hero moment. Flat on the canvas (no card box):
/// a white eyebrow, a large numeral, one label, one quiet sub-line, and
/// the single primary CTA. The glossy control carries all the material.
class _FocusHero extends ConsumerWidget {
  const _FocusHero({required this.dashboard});

  final AsyncValue<DashboardSnapshot> dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S FOCUS",
          style: AppText.eyebrow.copyWith(color: g.primary),
        ),
        const SizedBox(height: 10),
        dashboard.when(
          loading: () => const _FocusSkeleton(),
          error: (_, _) => _FocusError(
            onRetry: () =>
                ref.read(dashboardControllerProvider.notifier).refresh(),
          ),
          data: (snapshot) => _FocusStats(usage: snapshot.usage),
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassButton(
          label: 'Start studying',
          icon: Icons.arrow_forward,
          size: GlassButtonSize.large,
          expand: true,
          onPressed: () => context.go(AppRoutes.study),
        ),
      ],
    );
  }
}

/// The hero numeral: how much AI study work is available this cycle.
/// The number is the largest type on the screen; the plan/cycle detail
/// drops to a muted sub-line.
class _FocusStats extends StatelessWidget {
  const _FocusStats({required this.usage});

  final AiUsage usage;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final planLabel = switch (usage.plan) {
      'premium' => 'Premium',
      'founding_member' => 'Founding member',
      _ => 'Free plan',
    };
    final number = usage.limit > 0 ? '${usage.remaining}' : '—';
    final sub = usage.remaining > 0
        ? '$planLabel · resets on the 1st'
        : 'Allowance used · resets on the 1st';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(color: g.textPrimary, height: 1.0),
        ),
        const SizedBox(height: 4),
        Text(
          'AI actions left',
          style: TextStyle(
            color: g.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(sub, style: AppText.small.copyWith(color: g.textMuted)),
      ],
    );
  }
}

class _FocusSkeleton extends StatelessWidget {
  const _FocusSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        GlassSkeleton(width: 120, height: 56, radius: 14),
        SizedBox(height: 10),
        GlassSkeleton(width: 150, height: 16),
        SizedBox(height: 8),
        GlassSkeleton(width: 190, height: 12),
      ],
    );
  }
}

class _FocusError extends ConsumerWidget {
  const _FocusError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return Row(
      children: [
        Icon(
          Icons.cloud_off,
          size: 20,
          color: g.textMuted.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not load your usage.',
            style: AppText.small.copyWith(color: g.textMuted),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: g.primary),
          child: const Text('Retry'),
        ),
      ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppText.eyebrow.copyWith(color: context.glass.textMuted),
    );
  }
}

/// Recent Study Spaces — the real notebook list on the open canvas
/// (hairline dividers, no card box). Shows what the user actually has
/// and opens it.
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your study spaces will appear here. Add your first PDF or '
                'notes and StudyFlow will organize them.',
                style: AppText.small.copyWith(color: g.textMuted, height: 1.4),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.notebooks),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create a study space'),
                style: TextButton.styleFrom(foregroundColor: g.primary),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < notebooks.length; i++) ...[
              _SpaceRow(notebook: notebooks[i]),
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

/// One notebook row on the open canvas: accent icon tile, title, source
/// metadata, and a chevron. Tapping enters the study space.
class _SpaceRow extends StatelessWidget {
  const _SpaceRow({required this.notebook});

  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final count = notebook.sourceCount;
    return InkWell(
      onTap: () => context.push('/notebooks/${notebook.id}'),
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book, size: 17, color: g.primary),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 1),
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

/// Quiet 3×2 action grid. Small translucent tiles, white icon, muted
/// label — supporting controls that stay out of the hero's way.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = [
    (Icons.upload_file, 'Upload notes', AppRoutes.notebooks, false),
    (Icons.auto_awesome, 'Summarize', AppRoutes.notebooks, false),
    (Icons.style, 'Flashcards', AppRoutes.flashcards, true),
    (Icons.quiz, 'Quiz', AppRoutes.quizzes, true),
    // Audio is a shell tab now, so go to it (like Upload notes/Study
    // plan) rather than pushing a full-screen route over the shell.
    (Icons.mic, 'Podcast', AppRoutes.audio, false),
    (Icons.event_available, 'Study plan', AppRoutes.study, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 10 : 0),
            child: Row(
              children: [
                for (var col = 0; col < 3; col++) ...[
                  Expanded(
                    child: _QuietAction(
                      icon: _actions[row * 3 + col].$1,
                      label: _actions[row * 3 + col].$2,
                      onTap: () {
                        final a = _actions[row * 3 + col];
                        a.$4 ? context.push(a.$3) : context.go(a.$3);
                      },
                    ),
                  ),
                  if (col != 2) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _QuietAction extends StatefulWidget {
  const _QuietAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuietAction> createState() => _QuietActionState();
}

class _QuietActionState extends State<_QuietAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: g.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: g.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 18, color: g.primary),
                    const SizedBox(height: 6),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
