import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/networking/connectivity_controller.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/responsive.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../core/tts/tts_service.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import '../audio/audio_controller.dart';
import '../audio/audio_repository.dart';
import '../flashcards/flashcards_controller.dart';
import '../flashcards/flashcards_repository.dart';
import '../quizzes/quizzes_controller.dart';
import '../quizzes/quizzes_repository.dart';
import 'add_source_sheet.dart';
import 'note_assist.dart';
import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebook_sources.dart';
import 'notebooks_controller.dart';
import 'notebooks_repository.dart';

/// The notebook workspace — sources, AI chat, and study tools.
class NotebookDetailPane extends ConsumerStatefulWidget {
  const NotebookDetailPane({
    super.key,
    required this.notebook,
    this.showBack = false,
  });

  final Notebook notebook;
  final bool showBack;

  @override
  ConsumerState<NotebookDetailPane> createState() => _NotebookDetailPaneState();
}

class _NotebookDetailPaneState extends ConsumerState<NotebookDetailPane> {
  int _tab = 0;
  bool _flashcardBusy = false;
  bool _quizBusy = false;
  bool _podcastBusy = false;
  late Future<List<NotebookSource>> _sourcesFuture;

  @override
  void initState() {
    super.initState();
    _sourcesFuture = _loadSources();
  }

  Future<List<NotebookSource>> _loadSources() =>
      ref.read(notebooksRepositoryProvider).listSources(widget.notebook.id);

  void _reloadSources() {
    setState(() {
      _sourcesFuture = _loadSources();
    });
  }

  Future<void> _openPasteSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PasteSourceSheet(
        onSubmit: (title, text) => ref
            .read(notebooksRepositoryProvider)
            .addPastedSource(widget.notebook.id, title: title, text: text),
        tts: ref.read(ttsServiceProvider),
        onAssist: (mode, text) => ref
            .read(notebooksRepositoryProvider)
            .assistText(widget.notebook.id, mode: mode, text: text),
      ),
    );
    if (added == true && mounted) {
      _reloadSources();
      ref.read(notebooksControllerProvider.notifier).refresh();
    }
  }

  Future<void> _openAddSourceSheet() async {
    final repo = ref.read(notebooksRepositoryProvider);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSourceSheet(
        onUpload: (files, onProgress) => repo.uploadFiles(
          widget.notebook.id,
          files: files,
          onProgress: onProgress,
        ),
        onPaste: _openPasteSheet,
      ),
    );
    if (added == true && mounted) {
      _reloadSources();
      ref.read(notebooksControllerProvider.notifier).refresh();
    }
  }

  Future<void> _deleteSource(NotebookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
        final mutedFg = isDark
            ? SwissColors.darkForeground.withValues(alpha: 0.5)
            : SwissColors.black.withValues(alpha: 0.5);
        return AlertDialog(
          backgroundColor: isDark ? SwissColors.darkSurface : SwissColors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'REMOVE THIS SOURCE?',
            style: SwissTypography.subheading.copyWith(color: fg),
          ),
          content: Text(
            '"${source.title}" and its indexed content will be removed. Your original file is never touched.',
            style: SwissTypography.body.copyWith(color: mutedFg),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('CANCEL', style: SwissTypography.label),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'REMOVE',
                style: SwissTypography.label.copyWith(color: SwissColors.red),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(notebooksRepositoryProvider)
          .deleteSource(widget.notebook.id, source.id);
      if (!mounted) return;
      _reloadSources();
      ref.read(notebooksControllerProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is NotebooksException
                ? e.message
                : 'Could not remove that source.',
          ),
        ),
      );
    }
  }

  Future<void> _generateFlashcards() async {
    setState(() => _flashcardBusy = true);
    try {
      final detail = await ref
          .read(flashcardsControllerProvider.notifier)
          .generate(widget.notebook.id);
      if (!mounted) return;
      context.push('${AppRoutes.flashcards}/${detail.deck.id}');
    } catch (e) {
      if (!mounted) return;
      final message = e is FlashcardsException
          ? e.message
          : 'Could not generate that deck.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _flashcardBusy = false);
    }
  }

  Future<void> _generateQuiz() async {
    setState(() => _quizBusy = true);
    try {
      final detail = await ref
          .read(quizzesControllerProvider.notifier)
          .generate(widget.notebook.id);
      if (!mounted) return;
      context.push('${AppRoutes.quizzes}/${detail.quiz.id}');
    } catch (e) {
      if (!mounted) return;
      final message = e is QuizzesException
          ? e.message
          : 'Could not generate that quiz.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _quizBusy = false);
    }
  }

  Future<void> _createPodcast() async {
    setState(() => _podcastBusy = true);
    try {
      final episode = await ref
          .read(audioControllerProvider.notifier)
          .createPodcast(
            widget.notebook.id,
            style: 'focused',
            length: 'standard',
          );
      if (!mounted) return;
      if (episode.isReady) {
        context.push('${AppRoutes.audio}/${episode.id}');
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is AudioException
          ? e.message
          : 'Could not create that podcast.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _podcastBusy = false);
    }
  }

  void _openAskAi() => setState(() => _tab = 1);

  @override
  Widget build(BuildContext context) {
    final notebook = widget.notebook;
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              context.isPhone ? 12 : 16,
              20,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showBack) ...[
                  IconButton(
                    onPressed: () => context.popOrHome(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SwissEyebrow(
                        text: 'Study Space',
                        color: null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notebook.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SwissTypography.section.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwissSpacing.md),
          const SwissDivider(thickness: 2),

          // Hero
          Padding(
            padding: const EdgeInsets.fromLTRB(20, SwissSpacing.md, 20, 0),
            child: _WorkspaceHero(
              sourcesFuture: _sourcesFuture,
              onReload: _reloadSources,
              onAskAi: _openAskAi,
              aiEnabled: !offline,
            ),
          ),
          const SizedBox(height: SwissSpacing.md),

          // Study actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _StudyActions(
              flashcardBusy: _flashcardBusy,
              onFlashcards: offline || _flashcardBusy ? null : _generateFlashcards,
              quizBusy: _quizBusy,
              onQuiz: offline || _quizBusy ? null : _generateQuiz,
              podcastBusy: _podcastBusy,
              onPodcast: offline || _podcastBusy ? null : _createPodcast,
            ),
          ),
          const SizedBox(height: SwissSpacing.md),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SwissTabBar(
              tabs: const ['SOURCES', 'ASK AI', 'STUDY'],
              currentIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: SwissSpacing.md),

          // Tab content
          Expanded(
            child: switch (_tab) {
              0 => _SourcesTab(
                sourcesFuture: _sourcesFuture,
                onReload: _reloadSources,
                onPaste: _openPasteSheet,
                onAddSource: _openAddSourceSheet,
                onDeleteSource: _deleteSource,
              ),
              1 => _AskAiTab(
                notebookId: notebook.id,
                online: !offline,
                flashcardBusy: _flashcardBusy,
                onFlashcards: offline || _flashcardBusy
                    ? null
                    : _generateFlashcards,
                quizBusy: _quizBusy,
                onQuiz: offline || _quizBusy ? null : _generateQuiz,
              ),
              _ => _StudyToolsTab(
                onAskAi: offline ? null : _openAskAi,
                flashcardBusy: _flashcardBusy,
                onFlashcards: offline || _flashcardBusy
                    ? null
                    : _generateFlashcards,
                quizBusy: _quizBusy,
                onQuiz: offline || _quizBusy ? null : _generateQuiz,
                podcastBusy: _podcastBusy,
                onPodcast: offline || _podcastBusy ? null : _createPodcast,
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ── Swiss Tab Bar ──

class _SwissTabBar extends StatelessWidget {
  const _SwissTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: SwissSpacing.lg),
          GestureDetector(
            onTap: () => onChanged(i),
            child: Text(
              tabs[i],
              style: SwissTypography.label.copyWith(
                color: i == currentIndex ? fg : mutedFg,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (i == currentIndex)
            Container(
              margin: const EdgeInsets.only(left: 6),
              width: 16,
              height: 3,
              color: SwissColors.red,
            ),
        ],
      ],
    );
  }
}

// ── Workspace Hero ──

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.sourcesFuture,
    required this.onReload,
    required this.onAskAi,
    this.aiEnabled = true,
  });

  final Future<List<NotebookSource>> sourcesFuture;
  final VoidCallback onReload;
  final VoidCallback onAskAi;
  final bool aiEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return SwissCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<NotebookSource>>(
            future: sourcesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container(
                  height: 80,
                  color: isDark ? SwissColors.darkMuted : SwissColors.muted,
                );
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Icon(Icons.cloud_off, size: 20, color: mutedFg),
                    const SizedBox(width: SwissSpacing.sm),
                    Expanded(
                      child: Text(
                        'Could not load sources.',
                        style: SwissTypography.body.copyWith(color: mutedFg),
                      ),
                    ),
                    SwissButton(
                      label: 'Retry',
                      variant: SwissButtonVariant.ghost,
                      compact: true,
                      onPressed: onReload,
                    ),
                  ],
                );
              }
              final sources = snapshot.data ?? const [];
              final total = sources.length;
              final ready =
                  sources.where((s) => s.status == SourceStatus.ready).length;
              final failed =
                  sources.where((s) => s.status == SourceStatus.failed).length;
              final pending = total - ready - failed;

              final caption = total == 0
                  ? 'ADD YOUR FIRST SOURCE.'
                  : failed > 0
                  ? '$failed SOURCE${failed == 1 ? '' : 'S'} FAILED.'
                  : pending > 0
                  ? '$pending SOURCE${pending == 1 ? '' : 'S'} INDEXING.'
                  : 'ALL SOURCES GROUNDED.';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Progress bar
                      Expanded(
                        child: SwissProgressBar(
                          value: total == 0 ? 0 : ready / total,
                          height: 6,
                        ),
                      ),
                      const SizedBox(width: SwissSpacing.md),
                      Text(
                        '$ready/$total',
                        style: SwissTypography.label.copyWith(
                          color: fg,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SwissSpacing.sm),
                  Text(
                    caption,
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: SwissSpacing.lg),
          SwissButton(
            label: aiEnabled ? 'Ask StudyFlow' : 'AI paused — offline',
            icon: aiEnabled ? Icons.auto_awesome : Icons.cloud_off,
            fullWidth: true,
            variant:
                aiEnabled ? SwissButtonVariant.primary : SwissButtonVariant.ghost,
            onPressed: aiEnabled ? onAskAi : null,
          ),
        ],
      ),
    );
  }
}

// ── Study Actions ──

class _StudyActions extends StatelessWidget {
  const _StudyActions({
    required this.flashcardBusy,
    required this.onFlashcards,
    required this.quizBusy,
    required this.onQuiz,
    required this.podcastBusy,
    required this.onPodcast,
  });

  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;
  final bool podcastBusy;
  final VoidCallback? onPodcast;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SwissButton(
            label: flashcardBusy ? '…' : 'Flashcards',
            icon: Icons.style,
            compact: true,
            variant: SwissButtonVariant.secondary,
            onPressed: onFlashcards,
          ),
        ),
        const SizedBox(width: SwissSpacing.sm),
        Expanded(
          child: SwissButton(
            label: quizBusy ? '…' : 'Quiz',
            icon: Icons.quiz,
            compact: true,
            variant: SwissButtonVariant.secondary,
            onPressed: onQuiz,
          ),
        ),
        const SizedBox(width: SwissSpacing.sm),
        Expanded(
          child: SwissButton(
            label: podcastBusy ? '…' : 'Podcast',
            icon: Icons.mic,
            compact: true,
            variant: SwissButtonVariant.secondary,
            onPressed: onPodcast,
          ),
        ),
      ],
    );
  }
}

// ── Sources Tab ──

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({
    required this.sourcesFuture,
    required this.onReload,
    required this.onPaste,
    required this.onAddSource,
    required this.onDeleteSource,
  });

  final Future<List<NotebookSource>> sourcesFuture;
  final VoidCallback onReload;
  final VoidCallback onPaste;
  final VoidCallback onAddSource;
  final ValueChanged<NotebookSource> onDeleteSource;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final bottomPad = context.isPhone ? 110.0 : 24.0;

    return FutureBuilder<List<NotebookSource>>(
      future: sourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        if (snapshot.hasError) {
          return SwissErrorState(
            title: 'COULD NOT LOAD SOURCES',
            message: 'Check your connection and try again.',
            onRetry: onReload,
          );
        }
        final sources = snapshot.data ?? const <NotebookSource>[];
        if (sources.isEmpty) {
          return SwissEmptyState(
            sectionNumber: '01',
            title: 'NO SOURCES YET',
            description:
                'Paste your notes and StudyFlow AI indexes them — answers, flashcards, and quizzes come from your material.',
            actionLabel: 'Add source',
            onAction: onAddSource,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'YOUR SOURCES',
                      style: SwissTypography.label.copyWith(
                        color: mutedFg,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  SwissButton(
                    label: 'Add',
                    icon: Icons.add,
                    compact: true,
                    variant: SwissButtonVariant.ghost,
                    onPressed: onAddSource,
                  ),
                  const SizedBox(width: SwissSpacing.sm),
                  SwissButton(
                    label: 'Paste',
                    compact: true,
                    variant: SwissButtonVariant.ghost,
                    onPressed: onPaste,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SwissHairline(),
                itemBuilder: (context, i) => _SourceCard(
                  source: sources[i],
                  index: i + 1,
                  onAddAnother: i == sources.length - 1 ? onPaste : null,
                  onDelete: () => onDeleteSource(sources[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.index,
    this.onAddAnother,
    this.onDelete,
  });

  final NotebookSource source;
  final int index;
  final VoidCallback? onAddAnother;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    final (statusLabel) = switch (source.status) {
      SourceStatus.ready => ('READY',),
      SourceStatus.processing => ('INDEXING',),
      SourceStatus.failed => ('FAILED',),
      SourceStatus.unknown => ('—',),
    };
    final isPasted = source.kind == 'pasted';

    return InkWell(
      onTap: onAddAnother,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.md),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 36,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: SwissTypography.label.copyWith(color: mutedFg),
              ),
            ),
            const SizedBox(width: SwissSpacing.sm),
            // Icon
            Container(
              width: 40,
              height: 40,
              color: source.status == SourceStatus.ready
                  ? fg
                  : (isDark ? SwissColors.darkMuted : SwissColors.muted),
              alignment: Alignment.center,
              child: Icon(
                isPasted ? Icons.notes : Icons.picture_as_pdf,
                size: 20,
                color: source.status == SourceStatus.ready
                    ? SwissColors.white
                    : fg,
              ),
            ),
            const SizedBox(width: SwissSpacing.md),
            // Title + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwissTypography.subheading.copyWith(
                      color: fg,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xxs),
                  Text(
                    source.sizeLabel.toUpperCase(),
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
            ),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SwissSpacing.sm,
                vertical: SwissSpacing.xxs,
              ),
              color: source.status == SourceStatus.ready
                  ? fg
                  : source.status == SourceStatus.failed
                  ? SwissColors.red
                  : (isDark ? SwissColors.darkMuted : SwissColors.muted),
              child: Text(
                statusLabel.$1,
                style: SwissTypography.label.copyWith(
                  color: source.status == SourceStatus.ready
                      ? SwissColors.white
                      : source.status == SourceStatus.failed
                      ? SwissColors.white
                      : fg,
                  fontSize: 10,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 18),
                color: mutedFg,
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ask AI Tab ──

class _AskAiTab extends ConsumerStatefulWidget {
  const _AskAiTab({
    required this.notebookId,
    this.online = true,
    this.flashcardBusy = false,
    this.onFlashcards,
    this.quizBusy = false,
    this.onQuiz,
  });

  final String notebookId;
  final bool online;
  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;

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
    if (!widget.online) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref
        .read(notebookChatControllerProvider(widget.notebookId).notifier)
        .send(text);
  }

  void _ask(String prompt) {
    ref
        .read(notebookChatControllerProvider(widget.notebookId).notifier)
        .send(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(notebookChatControllerProvider(widget.notebookId));
    final messages = chat.messages.reversed.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final bottomPad = context.isPhone ? 96.0 : 16.0;

    return Column(
      children: [
        Expanded(
          child: chat.messages.isEmpty
              ? _ChatEmptyState(onSuggestion: _ask)
              : ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                  itemCount: messages.length + (chat.busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length && chat.busy) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: SwissColors.red,
                            ),
                            const SizedBox(width: SwissSpacing.sm),
                            Text(
                              'READING YOUR SOURCES…',
                              style: SwissTypography.caption
                                  .copyWith(color: mutedFg),
                            ),
                          ],
                        ),
                      );
                    }
                    final message = messages[i];
                    return message.isUser
                        ? _UserMessage(message: message)
                        : _AiMessage(
                            message: message,
                            flashcardBusy: widget.flashcardBusy,
                            onFlashcards: widget.onFlashcards,
                            quizBusy: widget.quizBusy,
                            onQuiz: widget.onQuiz,
                          );
                  },
                ),
        ),
        if (chat.error != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SwissSpacing.sm),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: SwissColors.red,
                    width: SwissShapes.borderMedium,
                  ),
                ),
              ),
              child: Text(
                chat.error!.toUpperCase(),
                style: SwissTypography.caption.copyWith(color: SwissColors.red),
              ),
            ),
          ),
          const SizedBox(height: SwissSpacing.xs),
        ],
        if (!widget.online)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              "OFFLINE — RECONNECT TO ASK STUDYFLOW.",
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SwissInput(
                  controller: _controller,
                  hintText: 'Ask your notebook…',
                  prefixIcon: const Icon(Icons.question_answer),
                ),
              ),
              const SizedBox(width: SwissSpacing.sm),
              SwissButton(
                label: 'Ask',
                icon: Icons.send,
                compact: true,
                onPressed: !widget.online || chat.busy ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Summarize this notebook',
      'What are the key concepts?',
      'Quiz me on the material',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, context.isPhone ? 96 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: SwissSpacing.xxl),
          Text(
            'ASK STUDYFLOW',
            style: SwissTypography.section.copyWith(color: fg),
          ),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            'Answers are grounded in your sources with citations.',
            style: SwissTypography.body.copyWith(color: mutedFg),
          ),
          const SizedBox(height: SwissSpacing.xxl),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: SwissSpacing.sm),
              child: InkWell(
                onTap: () => onSuggestion(s),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SwissSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? SwissColors.darkBorder
                          : SwissColors.black,
                      width: SwissShapes.borderThin,
                    ),
                  ),
                  child: Text(
                    s.toUpperCase(),
                    style: SwissTypography.body.copyWith(color: fg),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'YOU',
            style: SwissTypography.label.copyWith(
              color: SwissColors.red,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            textAlign: TextAlign.right,
            style: SwissTypography.body.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AiMessage extends ConsumerStatefulWidget {
  const _AiMessage({
    required this.message,
    this.flashcardBusy = false,
    this.onFlashcards,
    this.quizBusy = false,
    this.onQuiz,
  });

  final ChatMessage message;
  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;

  @override
  ConsumerState<_AiMessage> createState() => _AiMessageState();
}

class _AiMessageState extends ConsumerState<_AiMessage> {
  late final TtsService _tts = ref.read(ttsServiceProvider);

  Future<void> _toggleListen() async {
    if (_tts.speaking.value) {
      await _tts.stop();
    } else {
      await _tts.speak(widget.message.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI',
            style: SwissTypography.label.copyWith(
              color: SwissColors.red,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: SwissSpacing.sm),
          Text(
            message.content,
            style: SwissTypography.body.copyWith(height: 1.65),
          ),
          if (message.citations.isNotEmpty) ...[
            const SizedBox(height: SwissSpacing.lg),
            const SwissDivider(thickness: 1),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'SOURCES',
              style: SwissTypography.label.copyWith(
                color: mutedFg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SwissSpacing.sm),
            for (final c in message.citations)
              Padding(
                padding: const EdgeInsets.only(bottom: SwissSpacing.xs),
                child: SwissCitation(sourceTitle: c.label),
              ),
          ],
          const SizedBox(height: SwissSpacing.md),
          ValueListenableBuilder<bool>(
            valueListenable: _tts.speaking,
            builder: (context, speaking, _) => Row(
              children: [
                _ActionLabel(
                  icon: speaking ? Icons.stop : Icons.volume_up,
                  label: speaking ? 'Stop' : 'Listen',
                  onTap: _toggleListen,
                ),
                const SizedBox(width: SwissSpacing.md),
                if (widget.onFlashcards != null)
                  _ActionLabel(
                    icon: Icons.style,
                    label: 'Flashcards',
                    onTap: widget.onFlashcards,
                  ),
                if (widget.onQuiz != null) ...[
                  const SizedBox(width: SwissSpacing.md),
                  _ActionLabel(
                    icon: Icons.quiz,
                    label: 'Quiz',
                    onTap: widget.onQuiz,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SwissColors.red),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: SwissTypography.caption.copyWith(
              color: SwissColors.red,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Study Tools Tab ──

class _StudyToolsTab extends StatelessWidget {
  const _StudyToolsTab({
    required this.onAskAi,
    required this.flashcardBusy,
    required this.onFlashcards,
    required this.quizBusy,
    required this.onQuiz,
    required this.podcastBusy,
    required this.onPodcast,
  });

  final VoidCallback? onAskAi;
  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;
  final bool podcastBusy;
  final VoidCallback? onPodcast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final bottomPad = context.isPhone ? 110.0 : 24.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
      children: [
        SwissCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GENERATE FROM YOUR SOURCES',
                style: SwissTypography.subheading.copyWith(color: fg),
              ),
              const SizedBox(height: SwissSpacing.xs),
              Text(
                'Every tool builds on the material in this notebook.',
                style: SwissTypography.body.copyWith(color: mutedFg),
              ),
              const SizedBox(height: SwissSpacing.md),
              SwissButton(
                label: 'Ask your notebook',
                icon: Icons.auto_awesome,
                fullWidth: true,
                onPressed: onAskAi,
              ),
            ],
          ),
        ),
        const SizedBox(height: SwissSpacing.lg),
        // Tool list
        SwissCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ToolRow(
                icon: Icons.style,
                title: 'FLASHCARDS',
                subtitle: flashcardBusy
                    ? 'Reading your sources…'
                    : 'Source-grounded cards from your notes',
                busy: flashcardBusy,
                onTap: onFlashcards,
              ),
              const SwissHairline(),
              _ToolRow(
                icon: Icons.quiz,
                title: 'QUIZZES',
                subtitle: quizBusy
                    ? 'Reading your sources…'
                    : 'MCQs generated from your material',
                busy: quizBusy,
                onTap: onQuiz,
              ),
              const SwissHairline(),
              _ToolRow(
                icon: Icons.mic,
                title: 'STUDY PODCAST',
                subtitle: podcastBusy
                    ? 'Organizing your notes…'
                    : 'Turn this notebook into a narrated audio episode',
                busy: podcastBusy,
                onTap: onPodcast,
              ),
              const SwissHairline(),
              _ToolRow(
                icon: Icons.summarize,
                title: 'SUMMARIES',
                subtitle: 'Short or exam-focused summaries',
                onTap: onAskAi,
              ),
              const SwissHairline(),
              _ToolRow(
                icon: Icons.menu_book,
                title: 'STUDY GUIDES',
                subtitle: 'Key concepts, definitions, and formulas',
                onTap: onAskAi,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SwissSpacing.md,
          vertical: SwissSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: SwissSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SwissTypography.subheading.copyWith(
                      color: fg,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xxs),
                  Text(
                    busy ? subtitle.toUpperCase() : subtitle,
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: mutedFg),
          ],
        ),
      ),
    );
  }
}

// ── Paste Source Sheet ──

class _PasteSourceSheet extends StatefulWidget {
  const _PasteSourceSheet({
    required this.onSubmit,
    required this.onAssist,
    this.tts,
  });

  final Future<NotebookSource> Function(String title, String text) onSubmit;
  final Future<String> Function(NoteAssistMode mode, String text) onAssist;
  final TtsService? tts;

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
      setState(() => _error = 'ADD A TITLE AND THE TEXT YOU WANT TO STUDY.');
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
        _error = e is NotebooksException
            ? e.message
            : 'SOMETHING WENT WRONG.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

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
          const SwissDivider(thickness: 4),
          const SizedBox(height: SwissSpacing.lg),
          Text(
            'PASTE TEXT',
            style: SwissTypography.section.copyWith(color: fg),
          ),
          const SizedBox(height: SwissSpacing.xs),
          Text(
            'StudyFlow AI indexes it and answers come from this material.',
            style: SwissTypography.body.copyWith(color: mutedFg),
          ),
          const SizedBox(height: SwissSpacing.xl),
          SwissInput(
            controller: _title,
            label: 'Title',
            hintText: 'e.g. Lecture 4 — Photosynthesis',
          ),
          const SizedBox(height: SwissSpacing.md),
          SwissInput(
            controller: _text,
            label: 'Text',
            hintText: 'Paste your notes here…',
            maxLines: 8,
          ),
          if (_error != null) ...[
            const SizedBox(height: SwissSpacing.sm),
            Text(
              _error!,
              style: SwissTypography.caption.copyWith(color: SwissColors.red),
            ),
          ],
          const SizedBox(height: SwissSpacing.xl),
          SwissButton(
            label: _busy ? 'Adding…' : 'Add source',
            icon: Icons.add,
            fullWidth: true,
            onPressed: _busy ? null : _add,
          ),
        ],
      ),
    );
  }
}
