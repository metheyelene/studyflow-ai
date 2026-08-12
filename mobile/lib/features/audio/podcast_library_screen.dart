import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import '../../core/utils/time.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import '../../shared/widgets/glass/glass_sheet.dart';
import '../notebooks/notebook.dart';
import '../notebooks/notebooks_controller.dart';
import 'audio_controller.dart';
import 'audio_models.dart';
import 'audio_repository.dart';

/// The podcast library ("My Audio"): generated episodes, generation flow,
/// and entry into the full-screen player.
class PodcastLibraryScreen extends ConsumerWidget {
  const PodcastLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioControllerProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.popOrHome(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'My Audio',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                GlassButton(
                  label: 'New podcast',
                  icon: Icons.mic_none,
                  size: GlassButtonSize.small,
                  onPressed: () => _openGenerateSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.when(
              loading: () => const _EpisodesLoading(),
              error: (err, _) => _EpisodesError(
                message: err is AudioException
                    ? err.message
                    : 'Could not load your audio.',
                onRetry: () =>
                    ref.read(audioControllerProvider.notifier).refresh(),
              ),
              data: (s) {
                if (s.episodes.isEmpty) {
                  return _EmptyLibrary(
                    onGenerate: () => _openGenerateSheet(context, ref),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    context.isPhone ? 96 : 24,
                  ),
                  itemCount: s.episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _EpisodeCard(
                    episode: s.episodes[i],
                    onOpen: () =>
                        context.push('${AppRoutes.audio}/${s.episodes[i].id}'),
                    onDelete: () => _confirmDelete(context, ref, s.episodes[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerateSheet(BuildContext context, WidgetRef ref) async {
    final episode = await showGlassSheet<AudioEpisode>(
      context: context,
      builder: (_) => const _GeneratePodcastSheet(),
    );
    if (episode == null || !context.mounted) return;
    if (episode.isReady) {
      ref.read(audioControllerProvider.notifier).upsert(episode);
      context.push('${AppRoutes.audio}/${episode.id}');
    } else if (episode.isProcessing) {
      ref.read(audioControllerProvider.notifier).upsert(episode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your episode is still being prepared.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AudioEpisode episode,
  ) async {
    final confirmed = await showGlassModal<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete this episode?',
            style: Theme.of(dialogContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '“${episode.title}” and its transcript will be removed. This can\'t be undone.',
            style: TextStyle(
              color: context.glass.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GlassButton(
                label: 'Cancel',
                variant: GlassButtonVariant.text,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: GlassButtonVariant.primary,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(audioControllerProvider.notifier).delete(episode.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the episode. Please try again.'),
        ),
      );
    }
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.onOpen,
    required this.onDelete,
  });

  final AudioEpisode episode;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final subtitle = switch (episode.status) {
      'processing' =>
        kPipelineStageLabels[episode.pipelineStage] ??
            'Preparing your episode…',
      'failed' => episode.errorMessage ?? 'Generation failed.',
      _ => _episodeMeta(episode),
    };

    return GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: episode.isReady ? onOpen : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: episode.isReady ? g.primarySoft : g.surfaceSubtle,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    episode.isReady ? Icons.play_arrow_rounded : Icons.mic_none,
                    size: 22,
                    color: episode.isReady ? g.primary : g.textMuted,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: episode.isFailed
                                    ? g.danger
                                    : g.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (episode.isProcessing)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: g.textMuted,
                  ),
                  tooltip: 'Delete episode',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _episodeMeta(AudioEpisode e) {
    final parts = <String>[
      if (e.durationSec != null) _fmtDuration(e.durationSec!),
      if (e.wordCount != null) '${e.wordCount} words',
      kPodcastStyleLabels[e.style] ?? e.style,
    ];
    final when = 'created ${relativeTime(e.createdAt, DateTime.now())}';
    return '${parts.join(' · ')} · $when';
  }

  String _fmtDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _EpisodesLoading extends StatelessWidget {
  const _EpisodesLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => GlassCard(
        child: Row(
          children: [
            const GlassSkeleton(width: 42, height: 42, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  GlassSkeleton(width: 170, height: 15),
                  SizedBox(height: 8),
                  GlassSkeleton(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodesError extends StatelessWidget {
  const _EpisodesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 26, color: g.textMuted),
              const SizedBox(height: 12),
              Text(
                'Could not load your audio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: 'Try again',
                icon: Icons.refresh,
                variant: GlassButtonVariant.glass,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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
              child: Icon(
                Icons.headphones_outlined,
                size: 24,
                color: g.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No podcasts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Turn a notebook into a Study Podcast. StudyFlow organizes your '
              'notes, writes a source-grounded script, and narrates it — so you '
              'can revise while walking, commuting, or just listening.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Start a podcast',
              icon: Icons.mic_none,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a notebook, style, and length, then watch the real
/// pipeline stages while the backend generates the episode.
class _GeneratePodcastSheet extends ConsumerStatefulWidget {
  const _GeneratePodcastSheet();

  @override
  ConsumerState<_GeneratePodcastSheet> createState() =>
      _GeneratePodcastSheetState();
}

class _GeneratePodcastSheetState extends ConsumerState<_GeneratePodcastSheet> {
  String? _notebookId;
  String _style = 'focused';
  String _length = 'standard';
  bool _busy = false;
  String? _stage;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
      _stage = 'Queued…';
    });
    try {
      final episode = await ref
          .read(audioControllerProvider.notifier)
          .createPodcast(
            _notebookId!,
            style: _style,
            length: _length,
            onStage: (stage) {
              if (mounted) {
                setState(() => _stage = kPipelineStageLabels[stage] ?? stage);
              }
            },
          );
      if (!mounted) return;
      Navigator.of(context).pop(episode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = null;
        _error = e is AudioException
            ? e.message
            : 'Could not create that podcast. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final notebooks = ref.watch(notebooksControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a Study Podcast',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'StudyFlow reads the notebook\'s sources, organizes the material, '
              'writes a grounded script, and narrates it as an MP3 episode.',
              style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Notebook',
              style: TextStyle(color: g.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            if (notebooks.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (notebooks.hasError ||
                (notebooks.valueOrNull ?? const []).isEmpty)
              Text(
                'You don\'t have any notebooks yet. Create one, add a source, then come back.',
                style: TextStyle(color: g.textMuted, fontSize: 13, height: 1.4),
              )
            else
              _NotebookPicker(
                notebooks: notebooks.valueOrNull!,
                selectedId: _notebookId,
                onSelect: (id) => setState(() => _notebookId = id),
              ),
            const SizedBox(height: 16),
            Text('Style', style: TextStyle(color: g.textMuted, fontSize: 12.5)),

            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in kPodcastStyleLabels.entries)
                  _ChoicePill(
                    label: style.value,
                    selected: _style == style.key,
                    onTap: _busy
                        ? null
                        : () => setState(() => _style = style.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Length',
              style: TextStyle(color: g.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final length in kPodcastLengthLabels.entries)
                  _ChoicePill(
                    label: length.value,
                    selected: _length == length.key,
                    onTap: _busy
                        ? null
                        : () => setState(() => _length = length.key),
                  ),
              ],
            ),
            if (_stage != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _stage!,
                      style: TextStyle(color: g.textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: g.danger, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            GlassButton(
              label: _busy ? 'Creating…' : 'Generate episode',
              icon: Icons.mic_none,
              expand: true,
              onPressed: _busy || _notebookId == null ? null : _generate,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookPicker extends StatelessWidget {
  const _NotebookPicker({
    required this.notebooks,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Notebook> notebooks;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final nb in notebooks)
          _ChoicePill(
            label: nb.title,
            selected: selectedId == nb.id,
            onTap: () => onSelect(nb.id),
          ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: selected ? g.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? g.primary : g.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? g.primary : g.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
