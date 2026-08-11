import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_nav.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebooks_controller.dart';

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
              1 => _AskAiTab(notebookId: notebook.id),
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

class _AskAiTab extends ConsumerStatefulWidget {
  const _AskAiTab({required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<_AskAiTab> createState() => _AskAiTabState();
}

class _AskAiTabState extends ConsumerState<_AskAiTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(notebookChatControllerProvider(widget.notebookId).notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final chat = ref.watch(notebookChatControllerProvider(widget.notebookId));
    final messages = chat.messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: chat.messages.isEmpty
              ? const _ChatEmptyState()
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _MessageBubble(message: messages[i]),
                ),
        ),
        if (chat.error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: g.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: g.danger.withValues(alpha: 0.35)),
              ),
              child: Text(
                chat.error!,
                style: TextStyle(color: g.danger, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          // Phones: the floating bottom nav overlays the branch content
          // (the shell's Stack sits above the pushed route), so the input
          // needs clearance to stay tappable above it.
          padding: EdgeInsets.fromLTRB(16, 0, 16, context.isPhone ? 96 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: GlassInput(
                  controller: _controller,
                  hintText: 'Ask your notebook…',
                  prefixIcon: Icons.question_answer_outlined,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Ask',
                icon: Icons.send,
                semanticLabel: 'Ask',
                onPressed: chat.busy ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
              child: Icon(Icons.auto_awesome, size: 24, color: g.primary),
            ),
            const SizedBox(height: 14),
            Text('Ask your notebook', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Answers are grounded in your sources and come with citations '
              'you can tap to see the original material.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isUser ? g.primary : g.surface,
          borderRadius: BorderRadius.circular(16),
          border: isUser
              ? null
              : Border.all(color: g.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? g.textOnPrimary : g.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (!isUser && message.citations.isNotEmpty) ...[getCitations(context, message.citations)],
          ],
        ),
      ),
    );
  }

  Widget getCitations(BuildContext context, List<ChatCitation> citations) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Sources',
          style: TextStyle(
            color: g.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in citations)
              _CitationChip(citation: c, onTap: () => _showCitation(context, c)),
          ],
        ),
      ],
    );
  }

  void _showCitation(BuildContext context, ChatCitation citation) {
    showGlassSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, size: 18, color: context.glass.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    citation.label,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              citation.excerpt,
              style: TextStyle(
                color: context.glass.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation, required this.onTap});

  final ChatCitation citation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: g.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: g.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '[${citation.marker}] ',
                style: TextStyle(color: g.primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Flexible(
                child: Text(
                  citation.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: g.textPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
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
