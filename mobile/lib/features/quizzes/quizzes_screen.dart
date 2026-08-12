import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../notebooks/notebooks_controller.dart';
import 'quiz_models.dart';
import 'quizzes_controller.dart';
import 'quizzes_repository.dart';

/// Quiz history for the user: generate-from-notebook, retake, delete.
class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzes = ref.watch(quizzesControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.popOrHome(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Quizzes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                GlassBadge(
                  label: quizzes.valueOrNull == null
                      ? '—'
                      : '${quizzes.valueOrNull!.quizzes.length}',
                  icon: Icons.quiz_outlined,
                ),
                const SizedBox(width: 10),
                GlassButton(
                  label: 'New quiz',
                  icon: Icons.add,
                  size: GlassButtonSize.small,
                  onPressed: () => _openGenerateSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: quizzes.when(
              loading: () => const _QuizzesLoading(),
              error: (err, _) => _QuizzesError(
                message: err is QuizzesException
                    ? err.message
                    : 'Could not load your quizzes.',
                onRetry: () =>
                    ref.read(quizzesControllerProvider.notifier).refresh(),
              ),
              data: (state) {
                if (state.quizzes.isEmpty) {
                  return _EmptyQuizzes(
                    onGenerate: () => _openGenerateSheet(context, ref),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    context.isPhone ? 96 : 24,
                  ),
                  itemCount: state.quizzes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _QuizCard(
                    quiz: state.quizzes[i],
                    onOpen: () => context.push(
                      '${AppRoutes.quizzes}/${state.quizzes[i].id}',
                    ),
                    onDelete: () =>
                        _confirmDelete(context, ref, state.quizzes[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerateSheet(BuildContext context, WidgetRef ref) async {
    final detail = await showGlassSheet<QuizDetail>(
      context: context,
      builder: (_) => const _GenerateQuizSheet(),
    );
    if (detail == null || !context.mounted) return;
    context.push('${AppRoutes.quizzes}/${detail.quiz.id}');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    QuizSummary quiz,
  ) async {
    final confirmed = await showGlassModal<bool>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete this quiz?',
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '“${quiz.title}” and its ${quiz.attempts} attempt${quiz.attempts == 1 ? '' : 's'} will be removed. This can\'t be undone.',
            style: TextStyle(
              color: context.glass.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassButton(
                label: 'Cancel',
                variant: GlassButtonVariant.text,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(quizzesControllerProvider.notifier).delete(quiz.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the quiz. Please try again.'),
        ),
      );
    }
  }
}

class _QuizzesLoading extends StatelessWidget {
  const _QuizzesLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => GlassCard(
        child: Row(
          children: [
            const GlassSkeleton(width: 42, height: 42, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  GlassSkeleton(width: 170, height: 15),
                  SizedBox(height: 8),
                  GlassSkeleton(width: 110, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizzesError extends StatelessWidget {
  const _QuizzesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text(
                'Could not load your quizzes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Try again',
                icon: Icons.refresh,
                variant: GlassButtonVariant.glass,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQuizzes extends StatelessWidget {
  const _EmptyQuizzes({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, context.isPhone ? 110 : 40),
      child: GlassCard(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.quiz_outlined, size: 24, color: g.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'No quizzes yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a quiz from a notebook and StudyFlow AI writes '
              'multiple-choice questions from your material, with '
              'explanations for every answer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Generate a quiz',
              icon: Icons.auto_awesome,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({
    required this.quiz,
    required this.onOpen,
    required this.onDelete,
  });

  final QuizSummary quiz;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  String get _meta {
    final parts = [
      '${quiz.questionCount} questions',
      (quiz.difficulty),
      if (quiz.bestScore != null && quiz.bestTotal != null)
        'best ${quiz.bestScore}/${quiz.bestTotal}',
      '${quiz.attempts} attempt${quiz.attempts == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.quiz_outlined, size: 21, color: g.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_meta · ${relativeTime(quiz.createdAt, DateTime.now())}',
                        style: TextStyle(color: g.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: g.textMuted,
                  ),
                  tooltip: 'Delete quiz',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a notebook + difficulty, generate the quiz.
class _GenerateQuizSheet extends ConsumerStatefulWidget {
  const _GenerateQuizSheet();

  @override
  ConsumerState<_GenerateQuizSheet> createState() => _GenerateQuizSheetState();
}

class _GenerateQuizSheetState extends ConsumerState<_GenerateQuizSheet> {
  String _difficulty = 'medium';
  String? _busyNotebookId;
  String? _error;

  Future<void> _generate(String notebookId) async {
    setState(() {
      _busyNotebookId = notebookId;
      _error = null;
    });
    try {
      final detail = await ref
          .read(quizzesControllerProvider.notifier)
          .generate(notebookId, difficulty: _difficulty);
      if (!mounted) return;
      Navigator.of(context).pop(detail);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyNotebookId = null;
        _error = e is QuizzesException
            ? e.message
            : 'Could not generate that quiz. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final notebooks = ref.watch(notebooksControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generate a quiz',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'StudyFlow AI reads the notebook\'s sources and writes '
            'multiple-choice questions from the material. Uses one AI action.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in const ['easy', 'medium', 'hard']) ...[
                if (d != 'easy') const SizedBox(width: 8),
                Expanded(
                  child: GlassButton(
                    label: d[0].toUpperCase() + d.substring(1),
                    variant: _difficulty == d
                        ? GlassButtonVariant.primary
                        : GlassButtonVariant.glass,
                    size: GlassButtonSize.small,
                    onPressed: () => setState(() => _difficulty = d),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (notebooks.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (notebooks.hasError)
            Text(
              'Could not load your notebooks.',
              style: TextStyle(color: g.danger, fontSize: 13),
            )
          else if ((notebooks.valueOrNull ?? const []).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'You don\'t have any notebooks yet. Create one, add a source, '
                'then come back to generate.',
                style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: notebooks.valueOrNull!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final nb = notebooks.valueOrNull![i];
                  final busy = _busyNotebookId == nb.id;
                  return GlassButton(
                    label: busy ? 'Generating…' : nb.title,
                    icon: Icons.auto_awesome,
                    variant: GlassButtonVariant.glass,
                    expand: true,
                    onPressed: busy ? null : () => _generate(nb.id),
                  );
                },
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: g.danger, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
