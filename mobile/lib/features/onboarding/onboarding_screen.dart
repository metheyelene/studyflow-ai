import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_progress.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';

/// The five onboarding goals. Values must match the backend's GOAL_OPTIONS
/// (src/lib/onboarding.ts); labels are the user-facing copy.
const _goalChoices = <({String value, String label, IconData icon})>[
  (value: 'summaries', label: 'AI summaries', icon: Icons.auto_awesome_outlined),
  (value: 'flashcards', label: 'Flashcards', icon: Icons.style_outlined),
  (value: 'quizzes', label: 'Quizzes', icon: Icons.quiz_outlined),
  (value: 'study planning', label: 'Study planning', icon: Icons.calendar_month_outlined),
  (value: 'staying motivated', label: 'Staying motivated', icon: Icons.local_fire_department_outlined),
];

const _minuteChoices = [30, 60, 90, 120, 180];

class _ExamRow {
  _ExamRow();
  final name = TextEditingController();
  String? date;
}

/// Five-question onboarding flow, mirroring the web form's fields so the
/// backend validates both clients identically: course, subjects, exams
/// (optional, up to 3), daily study minutes, and goals (at least one).
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
  void dispose() {
    _course.dispose();
    _subjects.dispose();
    for (final row in _exams) {
      row.name.dispose();
    }
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _course.text.trim().length >= 2,
        1 => _subjects.text.trim().isNotEmpty,
        2 => true, // exams are optional
        3 => true,
        _ => _goals.isNotEmpty,
      };

  String? get _stepHint => switch (_step) {
        0 => 'e.g. Medicine, Biology, Law, Computer Science',
        1 => 'e.g. Anatomy, Physiology, Biochemistry',
        _ => null,
      };

  void _next() {
    setState(() {
      _error = null;
      if (_step < _stepCount - 1) {
        _step++;
      }
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
      row.date = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
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
              for (final row in _exams)
                if (row.date != null)
                  OnboardingExam(
                    name: row.name.text.trim().isEmpty ? null : row.name.text.trim(),
                    date: row.date!,
                  ),
            ],
            dailyMinutes: _dailyMinutes,
            // Preserve the choice order for stable analytics tags.
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
    // On success the router redirects to /home automatically.
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                tone: GlassTone.floating,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(Icons.auto_stories, size: 26, color: g.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set up your study flow',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Five quick questions — takes about 30 seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: g.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    GlassProgress(value: (_step + 1) / _stepCount),
                    const SizedBox(height: 8),
                    Text(
                      'Step ${_step + 1} of $_stepCount — ${_stepTitle(_step)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: g.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._buildStep(context),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: g.danger, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (_step > 0)
                          GlassButton(
                            label: 'Back',
                            variant: GlassButtonVariant.glass,
                            onPressed: _busy ? null : _back,
                          ),
                        if (_step > 0) const SizedBox(width: 10),
                        Expanded(
                          child: GlassButton(
                            label: _step < _stepCount - 1 ? 'Continue' : 'Finish setup',
                            icon: _step < _stepCount - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            expand: true,
                            onPressed: _busy
                                ? null
                                : _step < _stepCount - 1
                                    ? (_canContinue ? _next : null)
                                    : (_canContinue ? _finish : null),
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

  String _stepTitle(int step) => switch (step) {
        0 => 'Your course',
        1 => 'Your subjects',
        2 => 'Your exams',
        3 => 'Study time',
        _ => 'Your goals',
      };

  List<Widget> _buildStep(BuildContext context) {
    final g = context.glass;
    final header = Text(
      switch (_step) {
        0 => 'What are you studying?',
        1 => 'Your subjects',
        2 => 'When are your exams?',
        3 => 'How long do you study each day?',
        _ => 'What do you want help with?',
      },
      style: Theme.of(context).textTheme.titleMedium,
    );

    final body = switch (_step) {
      0 => GlassInput(
          controller: _course,
          label: 'Course',
          hintText: _stepHint,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.school_outlined,
          // Keep the Continue button's enabled state live as the user types.
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _canContinue ? _next() : null,
        ),
      1 => GlassInput(
          controller: _subjects,
          label: 'Subjects',
          hintText: _stepHint,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.menu_book_outlined,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _canContinue ? _next() : null,
        ),
      2 => _buildExamsStep(g),
      3 => _buildMinutesStep(g),
      _ => _buildGoalsStep(g),
    };

    return [header, const SizedBox(height: 14), body];
  }

  Widget _buildExamsStep(GlassTheme g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Optional — add up to 3. Skip ahead if you prefer.',
          style: TextStyle(color: g.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _exams.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          GlassCard(
            child: Row(
              children: [
                Expanded(
                  child: GlassInput(
                    controller: _exams[i].name,
                    hintText: 'Exam name (optional)',
                    label: 'Exam ${i + 1}',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 10),
                GlassButton(
                  label: _exams[i].date ?? 'Pick date',
                  icon: Icons.event_outlined,
                  variant: _exams[i].date == null
                      ? GlassButtonVariant.glass
                      : GlassButtonVariant.primary,
                  size: GlassButtonSize.small,
                  onPressed: () => _pickExamDate(_exams[i]),
                ),
              ],
            ),
          ),
        ],
        if (_exams.length < 3) ...[
          const SizedBox(height: 10),
          GlassButton(
            label: 'Add another exam',
            icon: Icons.add,
            variant: GlassButtonVariant.text,
            onPressed: () => setState(() => _exams.add(_ExamRow())),
          ),
        ],
      ],
    );
  }

  Widget _buildMinutesStep(GlassTheme g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$_dailyMinutes minutes per day',
          style: TextStyle(
            color: g.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in _minuteChoices)
              GlassPill(
                label: '$minutes min',
                selected: _dailyMinutes == minutes,
                onTap: () => setState(() => _dailyMinutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A realistic daily target keeps your study plan useful.',
          style: TextStyle(color: g.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildGoalsStep(GlassTheme g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick at least one — this personalizes your dashboard.',
          style: TextStyle(color: g.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in _goalChoices)
              GlassPill(
                label: choice.label,
                icon: choice.icon,
                selected: _goals.contains(choice.value),
                onTap: () => setState(() {
                  if (!_goals.add(choice.value)) {
                    _goals.remove(choice.value);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }
}
