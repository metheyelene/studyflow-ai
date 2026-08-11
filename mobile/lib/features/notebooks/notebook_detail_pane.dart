import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_nav.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../flashcards/flashcards_controller.dart';
import '../flashcards/flashcards_repository.dart';
import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebook_sources.dart';
import 'notebooks_controller.dart';
import 'notebooks_repository.dart';

/// The notebook workspace — sources, AI chat, and study tools.
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
              0 => _SourcesTab(notebookId: notebook.id),
              1 => _AskAiTab(notebookId: notebook.id),
              _ => _StudyToolsTab(
                    notebookId: notebook.id,
                    onAskAi: () => setState(() => _tab = 1),
                  ),
            },
          ),
        ],
      ),
    );
  }
}

/// Shared empty-state scaffold for the tab panes.
class _TabScaffold extends StatelessWidget {
  const _TabScaffold({
    required this.icon,
    required this.title,
    required this.description,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 40),
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

// ─────────────────────────── Sources ───────────────────────────

class _SourcesTab extends ConsumerStatefulWidget {
  const _SourcesTab({required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends ConsumerState<_SourcesTab> {
  late Future<List<NotebookSource>> _sourcesFuture;

  @override
  void initState() {
    super.initState();
    _sourcesFuture = _load();
  }

  Future<List<NotebookSource>> _load() =>
      ref.read(notebooksRepositoryProvider).listSources(widget.notebookId);

  void _reload() {
    setState(() {
      _sourcesFuture = _load();
    });
  }

  Future<void> _openPasteSheet() async {
    final added = await showGlassSheet<bool>(
      context: context,
      builder: (sheetContext) => _PasteSourceSheet(
        onSubmit: (title, text) =>
            ref.read(notebooksRepositoryProvider).addPastedSource(
                  widget.notebookId,
                  title: title,
                  text: text,
                ),
      ),
    );
    if (added == true && mounted) {
      _reload();
      // Keep the header source-count badge in sync with the server. The
      // list updating is the success feedback — no toast needed.
      ref.read(notebooksControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NotebookSource>>(
      future: _sourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SourcesLoading();
        }
        if (snapshot.hasError) {
          return _TabScaffold(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load sources',
            description: 'Check your connection and try again.',
            actions: [
              GlassButton(
                label: 'Try again',
                icon: Icons.refresh,
                variant: GlassButtonVariant.glass,
                onPressed: _reload,
              ),
            ],
          );
        }
        final sources = snapshot.data ?? const <NotebookSource>[];
        if (sources.isEmpty) {
          return _TabScaffold(
            icon: Icons.description_outlined,
            title: 'No sources yet',
            description:
                'Paste your notes and StudyFlow AI will index them — then answers, '
                'flashcards, and quizzes come straight from your material, with '
                'citations back to the source.',
            actions: [
              GlassButton(
                label: 'Paste text',
                icon: Icons.content_paste,
                onPressed: _openPasteSheet,
              ),
            ],
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 24),
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _SourceCard(
            source: sources[i],
            onAddAnother: i == sources.length - 1 ? _openPasteSheet : null,
          ),
        );
      },
    );
  }
}

class _SourcesLoading extends StatelessWidget {
  const _SourcesLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 24),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => GlassCard(
        child: Row(
          children: [
            const GlassSkeleton(width: 40, height: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  GlassSkeleton(width: 160, height: 15),
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

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, this.onAddAnother});

  final NotebookSource source;
  final VoidCallback? onAddAnother;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final (statusLabel, statusColor) = switch (source.status) {
      SourceStatus.ready => ('Ready', g.success),
      SourceStatus.processing => ('Indexing', g.warning),
      SourceStatus.failed => ('Failed', g.danger),
      SourceStatus.unknown => ('—', g.textMuted),
    };
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    source.kind == 'pasted' ? Icons.notes : Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: g.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    source.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: g.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GlassBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    source.sizeLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: g.textMuted, fontSize: 12.5),
                  ),
                ),
                if (onAddAnother != null)
                  TextButton.icon(
                    onPressed: onAddAnother,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Paste another'),
                    style: TextButton.styleFrom(
                      foregroundColor: g.primary,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: title + pasted text → POST source. Returns true when the
/// source was added so the tab can refresh.
class _PasteSourceSheet extends StatefulWidget {
  const _PasteSourceSheet({required this.onSubmit});

  final Future<NotebookSource> Function(String title, String text) onSubmit;

  @override
  State<_PasteSourceSheet> createState() => _PasteSourceSheetState();
}

class _PasteSourceSheetState extends State<_PasteSourceSheet> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    final text = _text.text.trim();
    if (title.isEmpty || text.isEmpty) {
      setState(() => _error = 'Add a title and the text you want to study.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(title, text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is NotebooksException ? e.message : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
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
          Text('Paste text', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'StudyFlow AI indexes it and answers, flashcards, and quizzes come '
            'from this material.',
            style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          GlassInput(
            controller: _title,
            label: 'Title',
            hintText: 'e.g. Lecture 4 — Photosynthesis',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          GlassInput(
            controller: _text,
            label: 'Text',
            hintText: 'Paste your notes here…',
            maxLines: 8,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: g.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          GlassButton(
            label: _busy ? 'Adding…' : 'Add source',
            icon: Icons.add,
            expand: true,
            onPressed: _busy ? null : _add,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Ask AI ───────────────────────────

class _AskAiTab extends ConsumerStatefulWidget {
  const _AskAiTab({required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<_AskAiTab> createState() => _AskAiTabState();
}

class _AskAiTabState extends ConsumerState<_AskAiTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
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
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, context.isPhone ? 96 : 12),
                  itemCount: messages.length + (chat.busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length && chat.busy) {
                      return const _ThinkingBubble();
                    }
                    return _MessageBubble(message: messages[i]);
                  },
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
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 96 : 12),
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

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: g.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(g.primary),
                backgroundColor: g.primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Reading your sources…',
              style: TextStyle(color: g.textMuted, fontSize: 13),
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
          border: isUser ? null : Border.all(color: g.border),
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

// ─────────────────────────── Study tools ───────────────────────────

/// Honest study-tools tab: tools are generated from a notebook's sources
/// via the AI. Flashcards is wired end-to-end (generate → study session);
/// the rest route to asking the notebook.
class _StudyToolsTab extends ConsumerStatefulWidget {
  const _StudyToolsTab({required this.notebookId, required this.onAskAi});

  final String notebookId;
  final VoidCallback onAskAi;

  @override
  ConsumerState<_StudyToolsTab> createState() => _StudyToolsTabState();
}

class _StudyToolsTabState extends ConsumerState<_StudyToolsTab> {
  bool _flashcardBusy = false;

  Future<void> _generateFlashcards() async {
    setState(() => _flashcardBusy = true);
    try {
      final detail = await ref
          .read(flashcardsControllerProvider.notifier)
          .generate(widget.notebookId);
      if (!mounted) return;
      context.push('${AppRoutes.flashcards}/${detail.deck.id}');
    } catch (e) {
      if (!mounted) return;
      final message = e is FlashcardsException
          ? e.message
          : 'Could not generate that deck. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _flashcardBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, context.isPhone ? 110 : 24),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Generate from your sources', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Every tool builds on the material in this notebook — paste text '
                'under Sources, then ask the notebook or generate study material.',
                style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              GlassButton(
                label: 'Ask your notebook',
                icon: Icons.auto_awesome,
                onPressed: widget.onAskAi,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              GlassListTile(
                title: 'Flashcards',
                subtitle: _flashcardBusy
                    ? 'Reading your sources…'
                    : 'Source-grounded front/back cards from your notes',
                leading: _flashcardBusy
                    ? Padding(
                        padding: const EdgeInsets.all(2),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(g.primary),
                          ),
                        ),
                      )
                    : Icon(Icons.style_outlined, size: 22, color: g.primary),
                trailing: Icon(Icons.chevron_right, size: 20, color: g.textMuted),
                onTap: _flashcardBusy ? null : _generateFlashcards,
              ),
              Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1, indent: 50),
              GlassListTile(
                title: 'Quizzes',
                subtitle: 'MCQs generated from your material',
                leading: Icon(Icons.quiz_outlined, size: 22, color: g.primary),
                onTap: widget.onAskAi,
              ),
              Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1, indent: 50),
              GlassListTile(
                title: 'Summaries',
                subtitle: 'Short, detailed, or exam-focused summaries of your material',
                leading: Icon(Icons.summarize_outlined, size: 22, color: g.primary),
                onTap: widget.onAskAi,
              ),
              Divider(color: g.textPrimary.withValues(alpha: 0.06), height: 1, indent: 50),
              GlassListTile(
                title: 'Study guides',
                subtitle: 'Key concepts, definitions, and formulas',
                leading: Icon(Icons.menu_book_outlined, size: 22, color: g.primary),
                onTap: widget.onAskAi,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
