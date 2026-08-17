import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/networking/connectivity_controller.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/tts/tts_service.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_nav.dart';
import '../../shared/widgets/glass/glass_pill.dart';
import '../../shared/widgets/glass/glass_progress.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../../shared/widgets/graphics/sf_graphics.dart';
import '../../shared/widgets/ai/studyflow_ai_orb.dart';
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
        // The note editor's contextual AI toolbar: transform the selected
        // text (explain/summarize/simplify/quiz) or read it aloud. TTS
        // comes from the provider so tests can inject a recorder.
        tts: ref.read(ttsServiceProvider),
        onAssist: (mode, text) => ref
            .read(notebooksRepositoryProvider)
            .assistText(widget.notebook.id, mode: mode, text: text),
      ),
    );
    if (added == true && mounted) {
      _reloadSources();
      // Keep the header source progress in sync with the server. The list
      // updating is the success feedback — no toast needed.
      ref.read(notebooksControllerProvider.notifier).refresh();
    }
  }

  /// The Add Source sheet — upload files or paste text. Uploads go through
  /// the real repository (native picker → validation → multipart upload →
  /// backend extraction), and the sources list reloads with the returned,
  /// server-confirmed sources.
  Future<void> _openAddSourceSheet() async {
    final repo = ref.read(notebooksRepositoryProvider);
    final added = await showGlassSheet<bool>(
      context: context,
      builder: (sheetContext) => AddSourceSheet(
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

  /// Removes a source after an explicit confirmation. Explains that the
  /// indexed content leaves the Study Space while the user's original
  /// device file (if any) is never touched.
  Future<void> _deleteSource(NotebookSource source) async {
    final confirmed = await showGlassModal<bool>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remove this source?',
            style: Theme.of(ctx).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '“${source.title}” and its indexed content will be removed from '
            'this Study Space. Your original file on this device is never '
            'touched.',
            style: TextStyle(
              color: ctx.glass.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassButton(
                label: 'Cancel',
                variant: GlassButtonVariant.text,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Remove',
                variant: GlassButtonVariant.primary,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
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
      showGlassToast(
        context,
        e is NotebooksException
            ? e.message
            : 'Could not remove that source. Please try again.',
        error: true,
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
    // Global network state: when offline, every AI surface in this
    // workspace is disabled with honest copy. Local features (sources
    // list, review) keep working — they surface their own errors.
    final offline = ref.watch(isOfflineProvider).value ?? false;

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
              aiEnabled: !offline,
            ),
          ),
          SizedBox(height: context.isPhone ? 10 : 16),
          // Study actions float on the canvas below the anchor — the
          // glass-contrast rhythm (canvas → glossy anchor → floating
          // controls) instead of one box stacking progress, CTA, and chips.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _FloatingAiActions(
              flashcardBusy: _flashcardBusy,
              onFlashcards: offline || _flashcardBusy
                  ? null
                  : _generateFlashcards,
              quizBusy: _quizBusy,
              onQuiz: offline || _quizBusy ? null : _generateQuiz,
              podcastBusy: _podcastBusy,
              onPodcast: offline || _podcastBusy ? null : _createPodcast,
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

/// The workspace anchor — a glossy surface carrying the real source
/// progress as one large moment (ready/total in the center of a big ring,
/// with a caption naming the actual workspace state) and the primary Ask
/// StudyFlow CTA as the anchor's action. The study actions are NOT boxed
/// here — they float on the canvas below (see [NotebookDetailPane]), so
/// the workspace reads as canvas → glossy anchor → floating controls.
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
    final isPhone = context.isPhone;
    final ringSize = isPhone ? 96.0 : 112.0;
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
                return _SourceProgressSkeleton(ringSize: ringSize);
              }
              if (snapshot.hasError) {
                return _SourceProgressError(onRetry: onReload);
              }
              return _SourceProgress(
                sources: snapshot.data ?? const [],
                ringSize: ringSize,
              );
            },
          ),
          SizedBox(height: isPhone ? 10 : 18),
          _AskStudyFlowCta(
            onTap: onAskAi,
            compact: isPhone,
            enabled: aiEnabled,
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
    final failed = sources.where((s) => s.status == SourceStatus.failed).length;
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
          builder: (context, value, _) =>
              GlassRing(value: value, label: '$ready/$total', size: ringSize),
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
                    GlassBadge(label: 'Grounded', icon: Icons.auto_awesome),
                ],
              ),
              const SizedBox(height: 2),
              Text(caption, style: AppText.small.copyWith(color: g.textMuted)),
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
          Icons.cloud_off,
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
  const _AskStudyFlowCta({
    required this.onTap,
    this.compact = false,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final bool compact;
  final bool enabled;

  @override
  State<_AskStudyFlowCta> createState() => _AskStudyFlowCtaState();
}

class _AskStudyFlowCtaState extends State<_AskStudyFlowCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final enabled = widget.enabled;
    final iconColor = enabled
        ? g.textOnPrimary
        : g.textMuted.withValues(alpha: 0.55);
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? 'Ask StudyFlow' : "You're offline — AI is paused",
      child: AnimatedScale(
        scale: _pressed && enabled ? 0.97 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: !enabled
                ? null
                : (_) => setState(() => _pressed = true),
            onPointerUp: !enabled
                ? null
                : (_) => setState(() => _pressed = false),
            onPointerCancel: !enabled
                ? null
                : (_) => setState(() => _pressed = false),
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: EdgeInsets.symmetric(
                  vertical: widget.compact ? 12 : 15,
                ),
                decoration: BoxDecoration(
                  gradient: enabled
                      ? LinearGradient(
                          colors: [
                            g.primary,
                            Color.lerp(g.primary, g.ai, 0.35)!,
                          ],
                        )
                      : null,
                  color: enabled ? null : g.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: enabled
                        ? g.highlight.withValues(alpha: 0.6)
                        : g.border,
                  ),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: g.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      enabled ? Icons.auto_awesome : Icons.cloud_off,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      enabled ? 'Ask StudyFlow' : 'AI paused — offline',
                      style: TextStyle(
                        color: iconColor,
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
            icon: Icons.style,
            label: 'Flashcards',
            busy: flashcardBusy,
            onTap: onFlashcards,
          ),
          const SizedBox(width: 10),
          _AiActionChip(
            icon: Icons.quiz,
            label: 'Quiz',
            busy: quizBusy,
            onTap: onQuiz,
          ),
          const SizedBox(width: 10),
          _AiActionChip(
            icon: Icons.mic,
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
    // Disabled = no handler AND not busy (busy keeps its own spinner).
    final disabled = widget.onTap == null && !widget.busy;
    final accent = disabled ? g.textMuted.withValues(alpha: 0.55) : g.primary;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.95 : 1.0,
        duration: _pressed
            ? AppMotion.pressInDuration
            : AppMotion.pressOutDuration,
        curve: _pressed ? AppMotion.pressIn : AppMotion.pressOut,
        child: Material(
          color: Colors.transparent,
          child: Listener(
            onPointerDown: disabled
                ? null
                : (_) => setState(() => _pressed = true),
            onPointerUp: disabled
                ? null
                : (_) => setState(() => _pressed = false),
            onPointerCancel: disabled
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
                  border: Border.all(
                    color: disabled
                        ? g.border.withValues(alpha: 0.5)
                        : g.border,
                  ),
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
                        color: disabled
                            ? g.textPrimary.withValues(alpha: 0.06)
                            : g.primarySoft,
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
                          : Icon(
                              disabled ? Icons.cloud_off : widget.icon,
                              size: 16,
                              color: accent,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: disabled
                            ? g.textMuted.withValues(alpha: 0.7)
                            : g.textPrimary,
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
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...actions,
                    ],
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
    final g = context.glass;
    return FutureBuilder<List<NotebookSource>>(
      future: sourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SourcesLoading();
        }
        if (snapshot.hasError) {
          return _TabScaffold(
            icon: Icons.cloud_off,
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
            icon: Icons.description,
            title: 'No sources yet',
            description:
                'Paste your notes and StudyFlow AI indexes them — answers, '
                'flashcards, and quizzes then come straight from your material, '
                'with citations back to the source.',
            actions: [
              // Two compact actions side by side so the empty state stays
              // one visual moment (stacked buttons push the second one
              // below the fold on short viewports).
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Add source',
                      icon: Icons.add,
                      expand: true,
                      onPressed: onAddSource,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      label: 'Paste text',
                      icon: Icons.content_paste,
                      variant: GlassButtonVariant.glass,
                      expand: true,
                      onPressed: onPaste,
                    ),
                  ),
                ],
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
                    onPressed: onAddSource,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add source'),
                    style: TextButton.styleFrom(
                      foregroundColor: g.primary,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onPaste,
                    style: TextButton.styleFrom(
                      foregroundColor: g.textMuted,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Paste text'),
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
  const _SourceCard({required this.source, this.onAddAnother, this.onDelete});

  final NotebookSource source;
  final VoidCallback? onAddAnother;
  final VoidCallback? onDelete;

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
                    isPasted ? Icons.notes : Icons.picture_as_pdf,
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
                        style: TextStyle(color: g.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                GlassBadge(label: statusLabel, color: statusColor),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    color: g.textMuted.withValues(alpha: 0.7),
                    tooltip: 'Remove source',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                  ),
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
                      style: TextStyle(color: g.textMuted, fontSize: 12),
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
  const _PasteSourceSheet({
    required this.onSubmit,
    required this.onAssist,
    this.tts,
  });

  final Future<NotebookSource> Function(String title, String text) onSubmit;

  /// Transforms the selected note text (explain / summarize / simplify /
  /// quiz) through the backend and returns the transformed text.
  final Future<String> Function(NoteAssistMode mode, String text) onAssist;

  /// Reads the selection aloud. Defaults to the app's [ttsServiceProvider]
  /// in production; tests inject a recorder.
  final TtsService? tts;

  @override
  State<_PasteSourceSheet> createState() => _PasteSourceSheetState();
}

class _PasteSourceSheetState extends State<_PasteSourceSheet> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  final _textFocus = FocusNode();
  late final TtsService _tts = widget.tts ?? SystemTtsService();
  bool _busy = false;
  String? _error;
  bool _hasSelection = false;
  NoteAssistMode? _busyMode;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    // Selection changes come through the controller; the toolbar only
    // shows while the field actually has focus.
    _text.addListener(_syncSelection);
    _textFocus.addListener(_syncSelection);
    _tts.speaking.addListener(_syncSpeaking);
  }

  @override
  void dispose() {
    _text.removeListener(_syncSelection);
    _textFocus.removeListener(_syncSelection);
    _tts.speaking.removeListener(_syncSpeaking);
    _title.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _syncSelection() {
    final sel = _text.selection;
    final has = _textFocus.hasFocus && sel.isValid && !sel.isCollapsed;
    if (has != _hasSelection) setState(() => _hasSelection = has);
  }

  void _syncSpeaking() {
    if (!mounted) return;
    setState(() => _listening = _tts.speaking.value);
  }

  /// The currently selected substring, or null when the caret is
  /// collapsed, the selection is invalid, or the field is unfocused.
  String? get _selectedText {
    final sel = _text.selection;
    if (!sel.isValid || sel.isCollapsed) return null;
    final t = sel.textInside(_text.text).trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _runTransform(NoteAssistMode mode) async {
    final selected = _selectedText;
    if (selected == null || _busyMode != null) return;
    setState(() => _busyMode = mode);
    try {
      final result = await widget.onAssist(mode, selected);
      if (!mounted) return;
      final label = switch (mode) {
        NoteAssistMode.explain => 'EXPLAINED',
        NoteAssistMode.summarize => 'SUMMARY',
        NoteAssistMode.simplify => 'SIMPLIFIED',
        NoteAssistMode.quiz => 'QUIZ',
      };
      // Insert the result below the selection (never overwrite the
      // user's words) and collapse the caret past it, which hides the
      // toolbar.
      final sel = _text.selection;
      final insertion = '\n\n▸ $label\n${result.trim()}\n';
      setState(() {
        _text.text = _text.text.replaceRange(sel.end, sel.end, insertion);
        _text.selection = TextSelection.collapsed(
          offset: sel.end + insertion.length,
        );
        _busyMode = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyMode = null;
        _error = e is NotebooksException
            ? e.message
            : 'Could not run that action. Please try again.';
      });
    }
  }

  Future<void> _toggleListen() async {
    final selected = _selectedText;
    if (selected == null) return;
    if (_listening) {
      await _tts.stop();
    } else {
      await _tts.speak(selected);
    }
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
          // The editor: a floating glass AI toolbar appears over the
          // bottom of the field when text is selected — Explain,
          // Summarize, Simplify, Quiz, and Listen.
          Stack(
            children: [
              GlassInput(
                controller: _text,
                focusNode: _textFocus,
                label: 'Text',
                hintText: 'Paste your notes here…',
                maxLines: 8,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  reverseDuration: AppMotion.fast,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                  child: _hasSelection
                      ? _SelectionAiToolbar(
                          key: const ValueKey('selection-ai-toolbar'),
                          busyMode: _busyMode,
                          listening: _listening,
                          onTransform: _runTransform,
                          onListen: _toggleListen,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
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

/// The contextual AI toolbar that floats over the note editor while a
/// non-collapsed selection is active. Five actions: the four transforms
/// (Explain, Summarize, Simplify, Quiz) plus Listen (read the selection
/// aloud, toggling to Stop while speaking).
class _SelectionAiToolbar extends StatelessWidget {
  const _SelectionAiToolbar({
    super.key,
    required this.busyMode,
    required this.listening,
    required this.onTransform,
    required this.onListen,
  });

  final NoteAssistMode? busyMode;
  final bool listening;
  final ValueChanged<NoteAssistMode> onTransform;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      container: true,
      label: 'AI actions for the selected text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: g.floating,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: g.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarAction(
                icon: Icons.lightbulb,
                label: 'Explain',
                busy: busyMode == NoteAssistMode.explain,
                enabled: busyMode == null,
                onTap: () => onTransform(NoteAssistMode.explain),
              ),
              _ToolbarAction(
                icon: Icons.summarize,
                label: 'Summarize',
                busy: busyMode == NoteAssistMode.summarize,
                enabled: busyMode == null,
                onTap: () => onTransform(NoteAssistMode.summarize),
              ),
              _ToolbarAction(
                icon: Icons.short_text,
                label: 'Simplify',
                busy: busyMode == NoteAssistMode.simplify,
                enabled: busyMode == null,
                onTap: () => onTransform(NoteAssistMode.simplify),
              ),
              _ToolbarAction(
                icon: Icons.quiz,
                label: 'Quiz',
                busy: busyMode == NoteAssistMode.quiz,
                enabled: busyMode == null,
                onTap: () => onTransform(NoteAssistMode.quiz),
              ),
              _ToolbarAction(
                icon: listening ? Icons.stop_circle : Icons.volume_up,
                label: listening ? 'Stop' : 'Listen',
                busy: false,
                enabled: true,
                onTap: onListen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(g.primary),
                  ),
                )
              else
                Icon(icon, size: 15, color: g.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? g.textPrimary : g.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Ask AI ───────────────────────────

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
                Icon(Icons.description, size: 18, color: context.glass.primary),
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final chat = ref.watch(notebookChatControllerProvider(widget.notebookId));
    final messages = chat.messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: chat.messages.isEmpty
              ? _ChatEmptyState(onSuggestion: _ask)
              : ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    context.isPhone ? 96 : 16,
                  ),
                  itemCount: messages.length + (chat.busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length && chat.busy) {
                      return const _ThinkingRow();
                    }
                    final message = messages[i];
                    return message.isUser
                        ? _UserMessage(message: message)
                        : _AiMessage(
                            message: message,
                            onShowCitation: (c) => _showCitation(context, c),
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
        if (!widget.online)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 15,
                  color: g.textMuted.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're offline — reconnect to ask StudyFlow.",
                    style: TextStyle(color: g.textMuted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
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
                  prefixIcon: Icons.question_answer,
                  textInputAction: TextInputAction.send,
                  enabled: widget.online,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Ask',
                icon: Icons.send,
                semanticLabel: 'Ask',
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
    final g = context.glass;
    const suggestions = [
      'Summarize this notebook',
      'What are the key concepts?',
      'Quiz me on the material',
    ];
    return SingleChildScrollView(
      key: const Key('chat-empty-state'),
      padding: EdgeInsets.fromLTRB(24, 16, 24, context.isPhone ? 96 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      g.primary.withValues(alpha: 0.16),
                      g.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: const StudyFlowAiOrb(size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                'Ask StudyFlow',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Answers are grounded in your sources and come with '
                'citations you can tap to see the original material.',
                textAlign: TextAlign.center,
                style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions)
                    _SuggestionChip(label: s, onTap: () => onSuggestion(s)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small glass suggestion pill. Tapping sends the prompt to the chat.
class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
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
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: g.floating,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: g.primary.withValues(alpha: 0.28)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: g.primary),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: g.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet thinking state — a small source-retrieval graphic and a muted
/// line on the open canvas. The graphic carries the motion (a pulse
/// travelling the node network — SOURCES → RETRIEVAL → ANSWER); the text
/// carries the meaning.
class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          const SFSourceSearchGraphic(size: Size(40, 40)),
          const SizedBox(width: 12),
          Text(
            'Reading your sources…',
            style: TextStyle(color: g.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Minimal user message — a quiet right-aligned column on the open
/// canvas, no bubble. The question stays the smallest visual element of a
/// turn so the answer remains the focus of the reading experience.
class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'YOU',
            style: TextStyle(
              color: g.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message.content,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: g.textPrimary.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reading-first AI response — open canvas, editorial typography, a
/// SOURCES divider with dark glass citation chips, and contextual
/// actions. No chat bubble.
class _AiMessage extends ConsumerStatefulWidget {
  const _AiMessage({
    required this.message,
    required this.onShowCitation,
    this.flashcardBusy = false,
    this.onFlashcards,
    this.quizBusy = false,
    this.onQuiz,
  });

  final ChatMessage message;
  final ValueChanged<ChatCitation> onShowCitation;
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
    final g = context.glass;
    final message = widget.message;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StudyFlowAiOrb(size: 15),
              const SizedBox(width: 8),
              Text(
                'STUDYFLOW',
                style: TextStyle(
                  color: g.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.content,
            style: TextStyle(color: g.textPrimary, fontSize: 16, height: 1.65),
          ),
          if (message.citations.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(color: g.textPrimary.withValues(alpha: 0.08)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'SOURCES',
                    style: TextStyle(
                      color: g.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: g.textPrimary.withValues(alpha: 0.08)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in message.citations)
                  _CitationChip(
                    citation: c,
                    onTap: () => widget.onShowCitation(c),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ValueListenableBuilder<bool>(
            valueListenable: _tts.speaking,
            builder: (context, speaking, _) => Wrap(
              key: const Key('chat-answer-actions'),
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionPill(
                  icon: speaking ? Icons.stop : Icons.volume_up,
                  label: speaking ? 'Stop' : 'Listen',
                  onTap: _toggleListen,
                ),
                _ActionPill(
                  icon: Icons.style,
                  label: 'Flashcards',
                  onTap: widget.onFlashcards,
                  disabled: widget.flashcardBusy || widget.onFlashcards == null,
                ),
                _ActionPill(
                  icon: Icons.quiz,
                  label: 'Quiz',
                  onTap: widget.onQuiz,
                  disabled: widget.quizBusy || widget.onQuiz == null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small contextual action pill under an AI answer — Listen speaks the
/// answer aloud (toggling to Stop), Flashcards and Quiz run the same
/// notebook-grounded generations as the workspace header.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final effectiveOnTap = disabled ? null : onTap;
    return Semantics(
      button: true,
      enabled: effectiveOnTap != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: g.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: disabled
                    ? g.border.withValues(alpha: 0.5)
                    : g.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: disabled
                      ? g.textMuted.withValues(alpha: 0.5)
                      : g.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled
                        ? g.textMuted.withValues(alpha: 0.6)
                        : g.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A source citation — a dark glass chip with a thin accent edge. Tapping
/// opens the excerpt the answer is grounded in.
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
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 7),
          decoration: BoxDecoration(
            color: g.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: g.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description, size: 13, color: g.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    citation.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: g.textPrimary, fontSize: 12.5),
                  ),
                ),
              ],
            ),
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

  final VoidCallback? onAskAi;
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
                    : Icon(Icons.style, size: 22, color: g.primary),
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
                    : Icon(Icons.quiz, size: 22, color: g.primary),
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
                    : Icon(Icons.mic, size: 22, color: g.primary),
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
                leading: Icon(Icons.summarize, size: 22, color: g.primary),
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
                leading: Icon(Icons.menu_book, size: 22, color: g.primary),
                onTap: onAskAi,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
