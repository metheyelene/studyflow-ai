import 'package:flutter/material.dart';

import '../shared/widgets/feature_placeholder.dart';

/// Notebooks tab — placeholder until the notebooks client lands (Phase 7).
class NotebooksScreen extends StatelessWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.library_books_outlined,
      title: 'Notebooks',
      description:
          'Your private knowledge spaces — paste notes or upload PDFs, then ask '
          'StudyFlow AI anything about them, with citations back to the source.',
      note: 'Coming next in the mobile build. The web app already has this.',
    );
  }
}

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
