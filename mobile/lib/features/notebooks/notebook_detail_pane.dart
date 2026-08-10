import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_nav.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import 'notebook.dart';

/// The notebook workspace — sources, AI chat, and study tools. Structure
/// mirrors the web app; the backend wiring (upload, chat, actions) lands
/// in Phases 8–10. Until then every action is honest about what is coming.
class NotebookDetailPane extends StatefulWidget {
  const NotebookDetailPane({super.key, required this.notebook, this.showBack = false});

  final Notebook notebook;
  final bool showBack;

  @override
  State<NotebookDetailPane> createState() => _NotebookDetailPaneState();
}

class _NotebookDetailPaneState extends State<NotebookDetailPane> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final notebook = widget.notebook;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                if (widget.showBack) ...[
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    notebook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                GlassBadge(
                  label: notebook.sourceCount == 0 ? '0 sources' : '${notebook.sourceCount} sources',
                  icon: Icons.description_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassTabBar(
              tabs: const ['Sources', 'Ask AI', 'Study tools'],
              currentIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_tab) {
              0 => const _SourcesTab(),
              1 => const _AskAiTab(),
              _ => const _StudyToolsTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _TabScaffold extends StatelessWidget {
  const _TabScaffold({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
              child: Icon(icon, size: 24, color: g.primary),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}

class _SourcesTab extends StatelessWidget {
  const _SourcesTab();

  void _notReady(BuildContext context, String feature) {
    showGlassToast(
      context,
      '$feature arrives with sign-in and the backend (next phases).',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TabScaffold(
      icon: Icons.description_outlined,
      title: 'No sources yet',
      description:
          'Paste text or upload a PDF and StudyFlow AI will index it — then '
          'answers, flashcards, and quizzes come straight from your material, '
          'with citations back to the source.',
      actions: [
        GlassButton(
          label: 'Paste text',
          icon: Icons.content_paste,
          variant: GlassButtonVariant.glass,
          onPressed: () => _notReady(context, 'Adding sources'),
        ),
        const SizedBox(height: 8),
        GlassButton(
          label: 'Upload PDF',
          icon: Icons.upload_file,
          variant: GlassButtonVariant.glass,
          onPressed: () => _notReady(context, 'Uploading documents'),
        ),
      ],
    );
  }
}

class _AskAiTab extends StatefulWidget {
  const _AskAiTab();

  @override
  State<_AskAiTab> createState() => _AskAiTabState();
}

class _AskAiTabState extends State<_AskAiTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.auto_awesome, size: 24, color: g.primary),
                ),
                const SizedBox(height: 14),
                Text('Ask your notebook', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Questions get source-grounded answers with citations once '
                  'your material is added. Notebook AI arrives with the backend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassInput(
            controller: _controller,
            hintText: 'e.g. Summarize the key concepts…',
            prefixIcon: Icons.question_answer_outlined,
            suffix: IconButton(
              icon: Icon(Icons.send, size: 18, color: g.primary),
              tooltip: 'Ask',
              onPressed: () => showGlassToast(
                context,
                'Notebook AI arrives with the backend (next phases).',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyToolsTab extends StatelessWidget {
  const _StudyToolsTab();

  void _notReady(BuildContext context) {
    showGlassToast(context, 'Study tools arrive with the backend (next phases).');
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    const tools = [
      (Icons.summarize_outlined, 'Summarize', 'Short, detailed, or exam-focused summaries'),
      (Icons.style_outlined, 'Flashcards', 'Source-grounded front/back cards'),
      (Icons.quiz_outlined, 'Quiz', 'MCQs generated from your material'),
      (Icons.menu_book_outlined, 'Study guide', 'Key concepts, definitions, and formulas'),
      (Icons.account_tree_outlined, 'Mind map', 'A concept map linked back to sources'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                if (i > 0) Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1, indent: 50),
                GlassListTile(
                  title: tools[i].$2,
                  subtitle: tools[i].$3,
                  leading: Icon(tools[i].$1, size: 22, color: g.primary),
                  trailing: Icon(Icons.chevron_right, size: 20, color: g.textMuted),
                  onTap: () => _notReady(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
