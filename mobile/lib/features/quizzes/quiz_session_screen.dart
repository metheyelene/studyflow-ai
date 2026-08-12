import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import 'quiz_models.dart';
import 'quizzes_repository.dart';

/// A take-quiz session: answer each question with immediate feedback, then
/// submit the completed attempt for server-side scoring and see a breakdown.
class QuizSessionScreen extends ConsumerWidget {
  const QuizSessionScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final repo = ref.watch(quizzesRepositoryProvider);

    return FutureBuilder<QuizDetail>(
      future: repo.quiz(quizId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SessionScaffold(
            title: 'Loading quiz…',
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SessionScaffold(
            title: 'Quiz',
            child: Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 26, color: g.textMuted),
                    const SizedBox(height: 12),
                    Text('Could not load this quiz', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: 'Back',
                      icon: Icons.arrow_back,
                      variant: GlassButtonVariant.glass,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final detail = snapshot.data!;
        return _SessionScaffold(
          title: detail.quiz.title,
          child: _SessionBody(detail: detail),
        );
      },
    );
  }
}

class _SessionScaffold extends StatelessWidget {
  const _SessionScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SessionBody extends ConsumerStatefulWidget {
  const _SessionBody({required this.detail});

  final QuizDetail detail;

  @override
  ConsumerState<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends ConsumerState<_SessionBody> {
  late List<int?> _answers = List<int?>.filled(widget.detail.questions.length, null);
  int _index = 0;
  QuizResult? _result;
  bool _submitting = false;
  String? _submitError;

  QuizDetail get detail => widget.detail;
  int get _total => detail.questions.length;
  bool get _answered => _answers[_index] != null;

  void _select(int optionIndex) {
    if (_answered || _submitting) return;
    setState(() => _answers[_index] = optionIndex);
  }

  void _next() {
    setState(() => _index++);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await ref
          .read(quizzesRepositoryProvider)
          .submit(detail.quiz.id, answers: _answers.map((a) => a ?? 0).toList());
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is QuizzesException
            ? e.message
            : 'Could not score your answers. Please try again.';
      });
    }
  }

  void _retake() {
    setState(() {
      _answers = List<int?>.filled(_total, null);
      _index = 0;
      _result = null;
      _submitError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return const _EmptyQuiz();
    }
    if (_result != null) {
      return _Results(result: _result!, onRetake: _retake);
    }

    final question = detail.questions[_index];
    final selected = _answers[_index];
    final answered = selected != null;
    final isLast = _index == _total - 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Text(
              'Question ${_index + 1} of $_total',
              style: TextStyle(
                color: context.glass.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_index + (answered ? 1 : 0)) / _total,
            minHeight: 5,
            backgroundColor: context.glass.border,
            valueColor: AlwaysStoppedAnimation(context.glass.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          question.question,
          style: TextStyle(
            color: context.glass.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < question.options.length; i++) ...[
          _OptionTile(
            index: i,
            text: question.options[i],
            state: answered
                ? (i == question.correctIndex
                    ? _OptionState.correct
                    : i == selected
                        ? _OptionState.wrong
                        : _OptionState.neutral)
                : _OptionState.neutral,
            onTap: () => _select(i),
          ),
          if (i < question.options.length - 1) const SizedBox(height: 8),
        ],
        if (answered) ...[
          const SizedBox(height: 16),
          _FeedbackCard(
            correct: selected == question.correctIndex,
            explanation: question.explanation,
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: isLast ? 'See results' : 'Next question',
            icon: isLast ? Icons.flag_outlined : Icons.arrow_forward,
            expand: true,
            onPressed: isLast ? _submit : _next,
          ),
          if (_submitting) ...[
            const SizedBox(height: 10),
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (_submitError != null) ...[
            const SizedBox(height: 10),
            Text(
              _submitError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.glass.danger, fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }
}

enum _OptionState { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final letter = String.fromCharCode(65 + index); // A, B, C, D
    final Color? borderColor = switch (state) {
      _OptionState.correct => g.success,
      _OptionState.wrong => g.danger,
      _OptionState.neutral => null,
    };
    final Color? bg = switch (state) {
      _OptionState.correct => g.success.withValues(alpha: 0.12),
      _OptionState.wrong => g.danger.withValues(alpha: 0.10),
      _OptionState.neutral => null,
    };
    final Color labelColor = switch (state) {
      _OptionState.correct => g.success,
      _OptionState.wrong => g.danger,
      _OptionState.neutral => g.primary,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state == _OptionState.neutral ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg ?? g.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? g.border),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 14.5,
                    height: 1.35,
                  ),
                ),
              ),
              if (state == _OptionState.correct)
                Icon(Icons.check_circle, size: 20, color: g.success)
              else if (state == _OptionState.wrong)
                Icon(Icons.cancel, size: 20, color: g.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.correct, this.explanation});

  final bool correct;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final color = correct ? g.success : g.danger;
    return GlassCard(
      tone: GlassTone.floating,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                    size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  correct ? 'Correct' : 'Not quite',
                  style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (explanation != null && explanation!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                explanation!,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyQuiz extends StatelessWidget {
  const _EmptyQuiz();

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
              Icon(Icons.quiz_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text('This quiz is empty', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Delete it and generate a new one from a notebook with sources.',
                textAlign: TextAlign.center,
                style: TextStyle(color: g.textMuted, fontSize: 13.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, required this.onRetake});

  final QuizResult result;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final passed = result.percent >= 60;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GlassCard(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (passed ? g.success : g.warning).withValues(alpha: 0.12),
                    border: Border.all(
                      color: (passed ? g.success : g.warning).withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${result.percent}%',
                    style: TextStyle(
                      color: passed ? g.success : g.warning,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  passed ? 'Good work' : 'Worth another pass',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'You answered ${result.score} of ${result.total} correctly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Review',
          style: TextStyle(
            color: g.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < result.perQuestion.length; i++) ...[
          _ReviewItem(item: result.perQuestion[i], number: i + 1),
          if (i < result.perQuestion.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        GlassButton(
          label: 'Retake quiz',
          icon: Icons.refresh,
          variant: GlassButtonVariant.glass,
          onPressed: onRetake,
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.item, required this.number});

  final QuizAnswerResult item;
  final int number;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.correct ? Icons.check_circle : Icons.cancel,
                  size: 18,
                  color: item.correct ? g.success : g.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$number. ${item.question}',
                    style: TextStyle(
                      color: g.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.selectedIndex < item.options.length)
              Text(
                'You chose: ${item.options[item.selectedIndex]}',
                style: TextStyle(
                  color: item.correct ? g.success : g.danger,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            if (!item.correct && item.correctIndex < item.options.length) ...[
              const SizedBox(height: 3),
              Text(
                'Correct: ${item.options[item.correctIndex]}',
                style: TextStyle(color: g.success, fontSize: 13, height: 1.35),
              ),
            ],
            if (item.explanation != null && item.explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.explanation!,
                style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
