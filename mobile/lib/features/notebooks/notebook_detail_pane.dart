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
import '../../shared/widgets/glass/glass_progress.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../../shared/widgets/ai/studyflow_ai_orb.dart';
import '../audio/audio_controller.dart';
import '../audio/audio_repository.dart';
import '../flashcards/flashcards_controller.dart';
import '../flashcards/flashcards_repository.dart';
import '../quizzes/quizzes_controller.dart';
import '../quizzes/quizzes_repository.dart';
import 'notebook.dart';
import 'notebook_chat.dart';
import 'notebook_sources.dart';
import 'notebooks_controller.dart';
import 'notebooks_repository.dart';

/// The notebook workspace — sources, AI chat, and study tools.
///
/// Editorial composition: an eyebrow and display-scale title sit on the
/// open canvas, then a glossy hero surface carries the real source
/// progress (ready/total), the primary Ask StudyFlow CTA, and the
/// floating study actions (Flashcards, Quiz, Podcast). Sources render as
/// an elegant workspace — a composed section header above intelligent
/// glass source objects. The generation actions live here — one source
/// of truth shared by the hero and the Study tools tab.
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
    final added = await showGlassSheet<bool>(
      context: context,
      builder: (sheetContext) => _PasteSourceSheet(
        onSubmit: (title, text) => ref
            .read(notebooksRepositoryProvider)
            .addPastedSource(widget.notebook.id, title: title, text: text),
      ),
    );
    if (added == true && mounted) {
      _reloadSources();
      // Keep the header source progress in sync with the server. The list
      // updating is the success feedback — no toast needed.
      ref.read(notebooksControllerProvider.notifier).refresh();
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
          : 'Could not generate that deck. Please try again.';
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
          : 'Could not generate that quiz. Please try again.';
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
          : 'Could not create that podcast. Please try again.';
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
    final g = context.glass;
    final notebook = widget.notebook;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Editorial title moment — eyebrow and display-scale title on the
          // open canvas, mirroring the dashboard's composition.
          Padding(
            padding: EdgeInsets.fromLTRB(20, context.isPhone ? 12 : 16, 20, 0),
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
                      Text(
                        'STUDY SPACE',
                        style: AppText.eyebrow.copyWith(color: g.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notebook.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.isPhone ? 14 : AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _WorkspaceHero(
              sourcesFuture: _sourcesFuture,
              onReload: _reloadSources,
              onAskAi: _openAskAi,
              flashcardBusy: _flashcardBusy,
              onFlashcards: _flashcardBusy ? null : _generateFlashcards,
              quizBusy: _quizBusy,
              onQuiz: _quizBusy ? null : _generateQuiz,
              podcastBusy: _podcastBusy,
              onPodcast: _podcastBusy ? null : _createPodcast,
            ),
          ),
          SizedBox(height: context.isPhone ? 10 : 16),
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
              0 => _SourcesTab(
                sourcesFuture: _sourcesFuture,
                onReload: _reloadSources,
                onPaste: _openPasteSheet,
              ),
              1 => _AskAiTab(notebookId: notebook.id),
              _ => _StudyToolsTab(
                onAskAi: _openAskAi,
                flashcardBusy: _flashcardBusy,
                onFlashcards: _flashcardBusy ? null : _generateFlashcards,
                quizBusy: _quizBusy,
                onQuiz: _quizBusy ? null : _generateQuiz,
                podcastBusy: _podcastBusy,
                onPodcast: _podcastBusy ? null : _createPodcast,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// The workspace hero — a glossy surface carrying the real source progress
/// (ready/total from the sources list), the primary Ask StudyFlow CTA, and
/// the floating study actions. Mirrors the dashboard's editorial language:
/// one big honest moment, then contextual controls.
class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.sourcesFuture,
    required this.onReload,
    required this.onAskAi,
    required this.flashcardBusy,
    required this.onFlashcards,
    required this.quizBusy,
    required this.onQuiz,
    required this.podcastBusy,
    required this.onPodcast,
  });

  final Future<List<NotebookSource>> sourcesFuture;
  final VoidCallback onReload;
  final VoidCallback onAskAi;
  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;
  final bool podcastBusy;
  final VoidCallback? onPodcast;

  @override
  Widget build(BuildContext context) {
    final isPhone = context.isPhone;
    return GlassCard(
      tone: GlassTone.floating,
      glossy: true,
      radius: AppShapes.hero,
      padding: EdgeInsets.all(isPhone ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<NotebookSource>>(
            future: sourcesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _SourceProgressSkeleton(ringSize: isPhone ? 64 : 84);
              }
              if (snapshot.hasError) {
                return _SourceProgressError(onRetry: onReload);
              }
              return _SourceProgress(
                sources: snapshot.data ?? const [],
                ringSize: isPhone ? 64 : 84,
              );
            },
          ),
          SizedBox(height: isPhone ? 10 : 18),
          _AskStudyFlowCta(onTap: onAskAi, compact: isPhone),
          SizedBox(height: isPhone ? 8 : 14),
          _FloatingAiActions(
            flashcardBusy: flashcardBusy,
            onFlashcards: onFlashcards,
            quizBusy: quizBusy,
            onQuiz: onQuiz,
            podcastBusy: podcastBusy,
            onPodcast: onPodcast,
          ),
        ],
      ),
    );
  }
}

/// Honest source progress — the ring animates 0 → ready/total on first
/// appearance, and the caption names the actual workspace state.
class _SourceProgress extends StatelessWidget {
  const _SourceProgress({required this.sources, this.ringSize = 84});

  final List<NotebookSource> sources;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final total = sources.length;
    final ready = sources.where((s) => s.status == SourceStatus.ready).length;
    final failed = sources
        .where((s) => s.status == SourceStatus.failed)
        .length;
    final pending = total - ready - failed;

    final caption = total == 0
        ? 'Add your first source — paste text and StudyFlow indexes it.'
        : failed > 0
            ? '$failed ${failed == 1 ? 'source' : 'sources'} failed — delete and paste again.'
            : pending > 0
                ? '$pending ${pending == 1 ? 'source' : 'sources'} indexing — ready for AI when done.'
                : 'All sources grounded — answers cite your material.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: total == 0 ? 0 : ready / total),
          duration: AppMotion.medium,
          curve: AppMotion.emphasized,
          builder: (context, value, _) => GlassRing(
            value: value,
            label: '$ready/$total',
            size: ringSize,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sources ready',
                      style: AppText.bodyMedium.copyWith(color: g.textPrimary),
                    ),
                  ),
                  if (total > 0 && ready == total)
                    GlassBadge(
                      label: 'Grounded',
                      icon: Icons.auto_awesome,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: AppText.small.copyWith(color: g.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceProgressSkeleton extends StatelessWidget {
  const _SourceProgressSkeleton({this.ringSize = 84});

  final double ringSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassSkeleton(width: ringSize, height: ringSize, radius: ringSize / 2),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              GlassSkeleton(width: 130, height: 15),
              SizedBox(height: 8),
              GlassSkeleton(width: 190, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceProgressError extends StatelessWidget {
  const _SourceProgressError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 22,
          color: g.textMuted.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Could not load your sources.',
            style: AppText.small.copyWith(color: g.textMuted),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: g.primary),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

/// Glossy primary CTA — a teal→cyan gradient button that springs under
/// press. "Ask StudyFlow" opens the grounded AI chat for this workspace.
class _AskStudyFlowCta extends StatefulWidget {
  const _AskStudyFlowCta({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  State<_AskStudyFlowCta> createState() => _AskStudyFlowCtaState();
}

class _AskStudyFlowCtaState extends State<_AskStudyFlowCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: 'Ask StudyFlow',
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: (_) => setState(() => _pressed = true),
            onPointerUp: (_) => setState(() => _pressed = false),
            onPointerCancel: (_) => setState(() => _pressed = false),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: EdgeInsets.symmetric(
                  vertical: widget.compact ? 12 : 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      g.primary,
                      Color.lerp(g.primary, g.ai, 0.35)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: g.highlight.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: g.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: g.textOnPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ask StudyFlow',
                      style: TextStyle(
                        color: g.textOnPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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
}

/// The three floating study actions: glossy elevated buttons that compress
/// on press and spring back, with an inline spinner while a generation runs.
class _FloatingAiActions extends StatelessWidget {
  const _FloatingAiActions({
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
    // One row on every screen: the row scales down (never wraps) when the
    // three actions exceed the available width on narrow phones.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AiActionChip(
            icon: Icons.style_outlined,
            label: 'Flashcards',
            busy: flashcardBusy,
            onTap: onFlashcards,
          ),
          const SizedBox(width: 10),
          _AiActionChip(
            icon: Icons.quiz_outlined,
            label: 'Quiz',
            busy: quizBusy,
            onTap: onQuiz,
          ),
          const SizedBox(width: 10),
          _AiActionChip(
            icon: Icons.mic_none,
            label: 'Podcast',
            busy: podcastBusy,
            onTap: onPodcast,
          ),
        ],
      ),
    );
  }
}

class _AiActionChip extends StatefulWidget {
  const _AiActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_AiActionChip> createState() => _AiActionChipState();
}

class _AiActionChipState extends State<_AiActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed && widget.onTap != null ? 0.95 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = true),
            onPointerUp: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = false),
            onPointerCancel: widget.onTap == null
                ? null
                : (_) => setState(() => _pressed = false),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: g.floating,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: g.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: widget.busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(g.primary),
                              ),
                            )
                          : Icon(widget.icon, size: 16, color: g.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
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
}

/// Shared empty-state scaffold for the tab panes. The card is centered in
/// the area ABOVE the floating nav (the bottom clearance lives on the
/// scroll view, not inside the content), so the CTA always sits clear of
/// the nav — and when the card is taller than that area it scrolls, with
/// the button still reachable above the nav.
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
    final bottomPad = context.isPhone ? 110.0 : 40.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = (constraints.maxHeight - bottomPad).clamp(
          0.0,
          double.infinity,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (area - 16).clamp(0.0, double.infinity),
            ),
            child: Center(
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 21, color: g.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: g.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (actions.isNotEmpty) ...[const SizedBox(height: 12), ...actions],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Sources ───────────────────────────

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({
    required this.sourcesFuture,
    required this.onReload,
    required this.onPaste,
  });

  final Future<List<NotebookSource>> sourcesFuture;
  final VoidCallback onReload;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return FutureBuilder<List<NotebookSource>>(
      future: sourcesFuture,
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
                onPressed: onReload,
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
                'Paste your notes and StudyFlow AI indexes them — answers, '
                'flashcards, and quizzes then come straight from your material, '
                'with citations back to the source.',
            actions: [
              GlassButton(
                label: 'Paste text',
                icon: Icons.content_paste,
                onPressed: onPaste,
              ),
            ],
          );
        }
        // Sources as an elegant workspace: a composed section header above
        // the intelligent glass source objects.
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
                      style: AppText.eyebrow.copyWith(color: g.textMuted),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onPaste,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Paste text'),
                    style: TextButton.styleFrom(
                      foregroundColor: g.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  context.isPhone ? 110 : 24,
                ),
                itemCount: sources.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _SourceCard(
                  source: sources[i],
                  onAddAnother: i == sources.length - 1 ? onPaste : null,
                ),
              ),
            ),
          ],
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

/// A source as an intelligent glass object: kind-tinted icon tile, honest
/// processing status, size metadata, and — once Ready — a subtle "grounded
/// for AI" sheen so sources read as knowledge objects, not file rows.
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
    final isPasted = source.kind == 'pasted';

    return GlassCard(
      tone: source.status == SourceStatus.ready
          ? GlassTone.floating
          : GlassTone.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Kind-tinted icon tile: pasted notes vs documents. The tint
                // shifts with processing state so the object reads as alive.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    isPasted
                        ? Icons.notes
                        : Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.sizeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassBadge(label: statusLabel, color: statusColor),
              ],
            ),
            if (source.status == SourceStatus.ready) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: g.primary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Grounded for AI — answers cite this source',
                      style: TextStyle(
                        color: g.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (onAddAnother != null)
                    TextButton.icon(
                      onPressed: onAddAnother,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Paste another'),
                      style: TextButton.styleFrom(
                        foregroundColor: g.primary,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (onAddAnother != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onAddAnother,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Paste another'),
                    style: TextButton.styleFrom(
                      foregroundColor: g.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        _error = e is NotebooksException
            ? e.message
            : 'Something went wrong. Please try again.';
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
    ref
        .read(notebookChatControllerProvider(widget.notebookId).notifier)
        .send(text);
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
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    context.isPhone ? 96 : 12,
                  ),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: g.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.auto_awesome, size: 21, color: g.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask your notebook',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Answers are grounded in your sources and come with citations '
              'you can tap to see the original material.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
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
            const StudyFlowAiOrb(active: true, size: 18),
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
            if (!isUser && message.citations.isNotEmpty) ...[
              getCitations(context, message.citations),
            ],
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
              _CitationChip(
                citation: c,
                onTap: () => _showCitation(context, c),
              ),
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
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: context.glass.primary,
                ),
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
                style: TextStyle(
                  color: g.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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
/// via the AI. The generation actions are owned by the workspace header
/// (single source of truth) and surfaced here as the same actions.
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

  final VoidCallback onAskAi;
  final bool flashcardBusy;
  final VoidCallback? onFlashcards;
  final bool quizBusy;
  final VoidCallback? onQuiz;
  final bool podcastBusy;
  final VoidCallback? onPodcast;

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
              Text(
                'Generate from your sources',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                onPressed: onAskAi,
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
                subtitle: flashcardBusy
                    ? 'Reading your sources…'
                    : 'Source-grounded front/back cards from your notes',
                leading: flashcardBusy
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
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: g.textMuted,
                ),
                onTap: onFlashcards,
              ),
              Divider(
                color: g.textPrimary.withValues(alpha: 0.06),
                height: 1,
                indent: 50,
              ),
              GlassListTile(
                title: 'Quizzes',
                subtitle: quizBusy
                    ? 'Reading your sources…'
                    : 'MCQs generated from your material',
                leading: quizBusy
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
                    : Icon(Icons.quiz_outlined, size: 22, color: g.primary),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: g.textMuted,
                ),
                onTap: onQuiz,
              ),
              Divider(
                color: g.textPrimary.withValues(alpha: 0.06),
                height: 1,
                indent: 50,
              ),
              GlassListTile(
                title: 'Study Podcast',
                subtitle: podcastBusy
                    ? 'Organizing your notes…'
                    : 'Turn this notebook into a narrated audio episode',
                leading: podcastBusy
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
                    : Icon(Icons.mic_none, size: 22, color: g.primary),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: g.textMuted,
                ),
                onTap: onPodcast,
              ),
              Divider(
                color: g.textPrimary.withValues(alpha: 0.06),
                height: 1,
                indent: 50,
              ),
              GlassListTile(
                title: 'Summaries',
                subtitle:
                    'Short, detailed, or exam-focused summaries of your material',
                leading: Icon(
                  Icons.summarize_outlined,
                  size: 22,
                  color: g.primary,
                ),
                onTap: onAskAi,
              ),
              Divider(
                color: g.textPrimary.withValues(alpha: 0.06),
                height: 1,
                indent: 50,
              ),
              GlassListTile(
                title: 'Study guides',
                subtitle: 'Key concepts, definitions, and formulas',
                leading: Icon(
                  Icons.menu_book_outlined,
                  size: 22,
                  color: g.primary,
                ),
                onTap: onAskAi,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
