import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';

const _goalChoices = <({String value, String label, IconData icon})>[
  (value: 'summaries', label: 'AI summaries', icon: Icons.auto_awesome),
  (value: 'flashcards', label: 'Flashcards', icon: Icons.style),
  (value: 'quizzes', label: 'Quizzes', icon: Icons.quiz),
  (
    value: 'study planning',
    label: 'Study planning',
    icon: Icons.calendar_month,
  ),
  (
    value: 'staying motivated',
    label: 'Staying motivated',
    icon: Icons.local_fire_department,
  ),
];
const _minuteChoices = [30, 60, 90, 120, 180];

class _ExamRow {
  _ExamRow();
  final name = TextEditingController();
  String? date;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 5;
  final _course = TextEditingController();
  final _subjects = TextEditingController();
  final _exams = <_ExamRow>[_ExamRow()];
  int _dailyMinutes = 60;
  final Set<String> _goals = {};
  int _step = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _course.addListener(_onFieldChanged);
    _subjects.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _course.removeListener(_onFieldChanged);
    _subjects.removeListener(_onFieldChanged);
    _course.dispose();
    _subjects.dispose();
    for (final r in _exams) {
      r.name.dispose();
    }
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _course.text.trim().length >= 2,
    1 => _subjects.text.trim().isNotEmpty,
    2 => true,
    3 => true,
    _ => _goals.isNotEmpty,
  };

  void _next() {
    setState(() {
      _error = null;
      if (_step < _stepCount - 1) _step++;
    });
  }

  void _back() {
    setState(() {
      _error = null;
      if (_step > 0) _step--;
    });
  }

  Future<void> _pickExamDate(_ExamRow row) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.date == null
          ? now.add(const Duration(days: 30))
          : DateTime.tryParse(row.date!) ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      row.date =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(onboardingControllerProvider.notifier)
        .submit(
          OnboardingPayload(
            course: _course.text.trim(),
            subjects: _subjects.text.trim(),
            exams: [
              for (final r in _exams)
                if (r.date != null)
                  OnboardingExam(
                    name: r.name.text.trim().isEmpty
                        ? null
                        : r.name.text.trim(),
                    date: r.date!,
                  ),
            ],
            dailyMinutes: _dailyMinutes,
            goals: [
              for (final c in _goalChoices)
                if (_goals.contains(c.value)) c.value,
            ],
          ),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SwissCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      color: fg,
                      child: Icon(
                        Icons.auto_stories,
                        size: 26,
                        color: isDark
                            ? SwissColors.darkBackground
                            : SwissColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SET UP YOUR STUDY FLOW',
                      textAlign: TextAlign.center,
                      style: SwissTypography.section.copyWith(color: fg),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Five quick questions — takes about 30 seconds.',
                      textAlign: TextAlign.center,
                      style: SwissTypography.body.copyWith(color: mutedFg),
                    ),
                    const SizedBox(height: 20),
                    SwissProgressBar(value: (_step + 1) / _stepCount),
                    const SizedBox(height: 8),
                    Text(
                      'Step ${_step + 1} of $_stepCount — ${_stepTitle(_step)}',
                      textAlign: TextAlign.center,
                      style: SwissTypography.caption.copyWith(color: mutedFg),
                    ),
                    const SizedBox(height: 20),
                    ..._buildStep(context, fg, mutedFg),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: SwissTypography.body.copyWith(
                          color: SwissColors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (_step > 0)
                          SwissButton(
                            label: 'Back',
                            variant: SwissButtonVariant.secondary,
                            onPressed: _busy ? null : _back,
                          ),
                        if (_step > 0) const SizedBox(width: 10),
                        Expanded(
                          child: SwissButton(
                            label: _step < _stepCount - 1
                                ? 'Continue'
                                : 'Finish setup',
                            icon: _step < _stepCount - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            fullWidth: true,
                            onPressed: _busy
                                ? null
                                : (_step < _stepCount - 1
                                      ? (_canContinue ? _next : null)
                                      : (_canContinue ? _finish : null)),
                          ),
                        ),
                      ],
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

  String _stepTitle(int s) => switch (s) {
    0 => 'Your course',
    1 => 'Your subjects',
    2 => 'Your exams',
    3 => 'Study time',
    _ => 'Your goals',
  };

  List<Widget> _buildStep(BuildContext context, Color fg, Color mutedFg) {
    final header = Text(switch (_step) {
      0 => 'What are you studying?',
      1 => 'Your subjects',
      2 => 'When are your exams?',
      3 => 'How long do you study each day?',
      _ => 'What do you want help with?',
    }, style: SwissTypography.subheading.copyWith(color: fg));
    final body = switch (_step) {
      0 => SwissInput(
        controller: _course,
        label: 'Course',
        hintText: 'e.g. Medicine, Biology, Law',
      ),
      1 => SwissInput(
        controller: _subjects,
        label: 'Subjects',
        hintText: 'e.g. Anatomy, Physiology',
      ),
      2 => _buildExamsStep(fg, mutedFg),
      3 => _buildMinutesStep(fg, mutedFg),
      _ => _buildGoalsStep(fg, mutedFg),
    };
    return [header, const SizedBox(height: 14), body];
  }

  Widget _buildExamsStep(Color fg, Color mutedFg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Optional — add up to 3.',
          style: SwissTypography.body.copyWith(color: mutedFg),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _exams.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          SwissCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SwissInput(
                    controller: _exams[i].name,
                    hintText: 'Exam name',
                  ),
                ),
                const SizedBox(width: 10),
                SwissButton(
                  label: _exams[i].date ?? 'Pick date',
                  icon: Icons.event,
                  compact: true,
                  variant: _exams[i].date == null
                      ? SwissButtonVariant.secondary
                      : SwissButtonVariant.primary,
                  onPressed: () => _pickExamDate(_exams[i]),
                ),
              ],
            ),
          ),
        ],
        if (_exams.length < 3) ...[
          const SizedBox(height: 10),
          SwissButton(
            label: 'Add another exam',
            icon: Icons.add,
            variant: SwissButtonVariant.ghost,
            onPressed: () => setState(() => _exams.add(_ExamRow())),
          ),
        ],
      ],
    );
  }

  Widget _buildMinutesStep(Color fg, Color mutedFg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$_dailyMinutes minutes per day',
          style: SwissTypography.bodyBold.copyWith(color: fg),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _minuteChoices)
              SwissButton(
                label: '$m min',
                compact: true,
                variant: _dailyMinutes == m
                    ? SwissButtonVariant.primary
                    : SwissButtonVariant.secondary,
                onPressed: () => setState(() => _dailyMinutes = m),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A realistic daily target keeps your study plan useful.',
          style: SwissTypography.caption.copyWith(color: mutedFg),
        ),
      ],
    );
  }

  Widget _buildGoalsStep(Color fg, Color mutedFg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick at least one — this personalizes your dashboard.',
          style: SwissTypography.body.copyWith(color: mutedFg),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _goalChoices)
              SwissButton(
                label: c.label,
                icon: c.icon,
                compact: true,
                variant: _goals.contains(c.value)
                    ? SwissButtonVariant.primary
                    : SwissButtonVariant.secondary,
                onPressed: () => setState(() {
                  if (!_goals.add(c.value)) _goals.remove(c.value);
                }),
              ),
          ],
        ),
      ],
    );
  }
}
