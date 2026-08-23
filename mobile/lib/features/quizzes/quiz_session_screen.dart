import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'quiz_models.dart';
import 'quizzes_repository.dart';

/// Swiss quiz session — rectangular options, no glass.
class QuizSessionScreen extends ConsumerWidget {
  const QuizSessionScreen({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(quizzesRepositoryProvider);

    return FutureBuilder<QuizDetail>(
      future: repo.quiz(quizId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _SessionScaffold(
            title: 'Loading quiz…',
            child: const Center(child: SwissProcessingState(label: 'Loading')),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _SessionScaffold(
            title: 'Quiz',
            child: SwissErrorState(
              title: 'Error',
              message: 'Could not load this quiz.',
              onRetry: () => context.popOrHome(),
            ),
          );
        }
        return _SessionScaffold(
          title: snapshot.data!.quiz.title,
          child: _SessionBody(detail: snapshot.data!),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
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
                    onPressed: () => context.popOrHome(),
                    icon: Icon(Icons.arrow_back, color: fg),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SwissEyebrow(text: 'Quiz session'),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwissTypography.subheading.copyWith(color: fg),
                        ),
                      ],
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
  late List<int?> _answers = List<int?>.filled(
    widget.detail.questions.length,
    null,
  );
  int _index = 0;
  QuizResult? _result;
  bool _submitting = false;
  String? _submitError;

  QuizDetail get detail => widget.detail;
  int get _total => detail.questions.length;

  void _select(int i) {
    if (_answers[_index] != null || _submitting) return;
    HapticFeedback.selectionClick();
    setState(() => _answers[_index] = i);
  }

  void _next() => setState(() => _index++);

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await ref
          .read(quizzesRepositoryProvider)
          .submit(
            detail.quiz.id,
            answers: _answers.map((a) => a ?? 0).toList(),
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e is QuizzesException
            ? e.message
            : 'Could not score your answers.';
      });
    }
  }

  void _retake() => setState(() {
    _answers = List<int?>.filled(_total, null);
    _index = 0;
    _result = null;
    _submitError = null;
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    if (_total == 0)
      return SwissEmptyState(
        sectionNumber: '01',
        title: 'Empty quiz',
        description: 'Generate a new quiz from a notebook.',
      );
    if (_result != null) return _Results(result: _result!, onRetake: _retake);

    final q = detail.questions[_index];
    final selected = _answers[_index];
    final answered = selected != null;
    final isLast = _index == _total - 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${_index + 1} of $_total',
                style: SwissTypography.label.copyWith(color: fg),
              ),
            ),
            Text(
              '$_index correct so far',
              style: SwissTypography.label.copyWith(color: SwissColors.red),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwissProgressBar(value: (_index + (answered ? 1 : 0)) / _total),
        const SizedBox(height: 22),
        Text(
          q.question,
          style: SwissTypography.subheading.copyWith(color: fg, fontSize: 21),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < q.options.length; i++) ...[
          _OptionTile(
            index: i,
            text: q.options[i],
            state: answered
                ? (i == q.correctIndex
                      ? _Opt.correct
                      : i == selected
                      ? _Opt.wrong
                      : _Opt.dimmed)
                : _Opt.neutral,
            onTap: () => _select(i),
            fg: fg,
            mutedFg: mutedFg,
          ),
          if (i < q.options.length - 1) const SizedBox(height: 10),
        ],
        if (answered) ...[
          const SizedBox(height: 16),
          if (q.explanation != null && q.explanation!.isNotEmpty)
            SwissCard(
              child: Text(
                q.explanation!,
                style: SwissTypography.body.copyWith(color: fg),
              ),
            ),
          const SizedBox(height: 14),
          SwissButton(
            label: isLast ? 'See results' : 'Next question',
            icon: isLast ? Icons.flag : Icons.arrow_forward,
            fullWidth: true,
            onPressed: isLast ? _submit : _next,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 10),
            Text(
              _submitError!,
              textAlign: TextAlign.center,
              style: SwissTypography.body.copyWith(color: SwissColors.red),
            ),
          ],
        ],
      ],
    );
  }
}

enum _Opt { neutral, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
    required this.fg,
    required this.mutedFg,
  });
  final int index;
  final String text;
  final _Opt state;
  final VoidCallback onTap;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    final letter = String.fromCharCode(65 + index);
    final isAnswered = state != _Opt.neutral;
    final borderColor = state == _Opt.correct
        ? SwissColors.red
        : state == _Opt.wrong
        ? SwissColors.red
        : fg;
    final bg = state == _Opt.correct
        ? SwissColors.red.withValues(alpha: 0.1)
        : state == _Opt.wrong
        ? SwissColors.red.withValues(alpha: 0.05)
        : Colors.transparent;

    return GestureDetector(
      onTap: state == _Opt.neutral ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: borderColor,
            width: state == _Opt.correct || state == _Opt.wrong
                ? SwissShapes.borderMedium
                : SwissShapes.borderThin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              color: SwissColors.red.withValues(alpha: 0.1),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: SwissTypography.label.copyWith(color: SwissColors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: SwissTypography.body.copyWith(color: fg),
              ),
            ),
            if (isAnswered)
              Icon(
                state == _Opt.correct ? Icons.check : Icons.close,
                size: 22,
                color: state == _Opt.correct ? SwissColors.red : mutedFg,
              ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        SwissCard(
          child: Column(
            children: [
              Text(
                '${result.percent}%',
                style: SwissTypography.display.copyWith(color: fg),
              ),
              const SizedBox(height: 8),
              Text(
                result.percent >= 60 ? 'Good work' : 'Worth another pass',
                style: SwissTypography.subheading.copyWith(color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                'You answered ${result.score} of ${result.total} correctly.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SwissEyebrow(text: 'Review'),
        const SizedBox(height: 8),
        for (var i = 0; i < result.perQuestion.length; i++) ...[
          _ReviewItem(item: result.perQuestion[i], number: i + 1),
          if (i < result.perQuestion.length - 1) const SwissHairline(),
        ],
        const SizedBox(height: 18),
        SwissButton(
          label: 'Retake quiz',
          icon: Icons.refresh,
          variant: SwissButtonVariant.secondary,
          fullWidth: true,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.correct ? Icons.check : Icons.close,
                size: 18,
                color: item.correct ? fg : SwissColors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.question,
                  style: SwissTypography.bodyBold.copyWith(color: fg),
                ),
              ),
            ],
          ),
          if (item.selectedIndex < item.options.length)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Text(
                'You chose: ${item.options[item.selectedIndex]}',
                style: SwissTypography.caption.copyWith(
                  color: item.correct ? fg : SwissColors.red,
                ),
              ),
            ),
          if (!item.correct && item.correctIndex < item.options.length)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                'Correct: ${item.options[item.correctIndex]}',
                style: SwissTypography.caption.copyWith(color: fg),
              ),
            ),
          if (item.explanation != null && item.explanation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 8),
              child: Text(
                item.explanation!,
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
            ),
        ],
      ),
    );
  }
}
