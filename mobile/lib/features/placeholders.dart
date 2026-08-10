import 'package:flutter/material.dart';

import '../shared/widgets/feature_placeholder.dart';

/// Study tab — flashcards / quizzes / planner live here (Phases 11–13).
class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.school_outlined,
      title: 'Study',
      description:
          'Flashcards, quizzes, and your study plan — everything you generate '
          'from your notebooks, in one place.',
      note: 'Coming in a later phase of the mobile build.',
    );
  }
}

/// Progress tab — streak, quiz performance, subject breakdown (Phase 14).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.insights_outlined,
      title: 'Progress',
      description:
          'Your study streak, quiz scores, session history, and weak areas — '
          'clear and readable on any screen size.',
      note: 'Coming in a later phase of the mobile build.',
    );
  }
}
