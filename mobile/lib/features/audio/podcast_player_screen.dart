import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'audio_controller.dart';
import 'audio_export.dart';
import 'audio_models.dart';
import 'audio_playback_service.dart';
import 'now_playing.dart';
import 'audio_repository.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Full-screen audio player.
class PodcastPlayerScreen extends ConsumerStatefulWidget {
  const PodcastPlayerScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  ConsumerState<PodcastPlayerScreen> createState() =>
      _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends ConsumerState<PodcastPlayerScreen> {
  PodcastPlayer? _player;
  AudioEpisode? _episode;
  Uint8List? _bytes;
  double? _downloadProgress;
  String? _error;
  Timer? _pollTimer;
  Timer? _saveTimer;
  StreamSubscription<Duration>? _positionSub;
  Duration _lastPosition = Duration.zero;
  bool _ended = false;

  AudioRepository get _repo => ref.read(audioRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _saveTimer?.cancel();
    _positionSub?.cancel();
    final ep = _episode;
    if (ep != null && ep.isReady && _lastPosition.inSeconds > 0) {
      unawaited(_savePosition());
    }
    super.dispose();
  }

  Future<void> _savePosition() async {
    final ep = _episode;
    if (ep == null || !ep.isReady) return;
    final sec = _lastPosition.inSeconds;
    if (sec <= 0) return;
    try {
      await _repo.savePosition(ep.id, sec);
      if (mounted) {
        ref
            .read(audioControllerProvider.notifier)
            .upsert(ep.copyWith(playbackPositionSec: sec));
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      var episode = await _repo.episode(widget.episodeId);
      if (episode.isProcessing) {
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
          try {
            final fresh = await _repo.episode(widget.episodeId);
            if (!mounted) return;
            setState(() => _episode = fresh);
            if (!fresh.isProcessing) {
              _pollTimer?.cancel();
              await _startPlayback();
            }
          } catch (_) {}
        });
      }
      if (!mounted) return;
      setState(() => _episode = episode);
      if (episode.isReady) await _startPlayback();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is AudioException
            ? e.message
            : 'Could not load that episode.',
      );
    }
  }

  Future<void> _startPlayback() async {
    final episode = _episode;
    if (episode == null || !episode.isReady) return;
    try {
      final bytes = await _repo.download(
        episode.id,
        onProgress: (received, total) {
          if (total != null && total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      if (!mounted) return;
      final player = ref.read(podcastPlayerProvider);
      await player.load(bytes);
      if (episode.playbackPositionSec > 0) {
        await player.seek(Duration(seconds: episode.playbackPositionSec));
      }
      await player.play();
      if (!mounted) return;
      ref
          .read(nowPlayingProvider.notifier)
          .setEpisode(
            episodeId: episode.id,
            title: episode.title,
            subtitle: episode.notebookTitle ?? 'Study podcast',
          );
      setState(() {
        _player = player;
        _bytes = bytes;
        _downloadProgress = 1;
      });
      _positionSub = player.positionStream.listen((p) => _lastPosition = p);
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final p = _player;
        if (p != null && p.playing) unawaited(_savePosition());
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is AudioException
            ? e.message
            : 'Could not play that episode.',
      );
    }
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      if (_ended) {
        await player.seek(Duration.zero);
        _ended = false;
      }
      await player.play();
    }
    ref.read(nowPlayingProvider.notifier).setPlaying(player.playing);
    if (mounted) setState(() {});
  }

  Future<void> _cycleSpeed() async {
    final player = _player;
    if (player == null) return;
    final next = _speeds[(_speeds.indexOf(player.speed) + 1) % _speeds.length];
    await player.setSpeed(next);
    if (mounted) setState(() {});
  }

  String _safeFileName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'StudyFlow_Study_Podcast' : cleaned;
  }

  Future<void> _export() async {
    final episode = _episode;
    final bytes = _bytes;
    if (episode == null || bytes == null) return;
    final name = '${_safeFileName(episode.title)}.mp3';
    try {
      await exportAudio(bytes, name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export the audio file. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final episode = _episode;

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: SwissErrorState(
            title: 'COULD NOT PLAY THIS EPISODE',
            message: _error!,
            onRetry: () {
              setState(() {
                _error = null;
                _episode = null;
                _bytes = null;
                _downloadProgress = null;
              });
              _load();
            },
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: episode == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : episode.isProcessing
            ? _PreparingView(episode: episode)
            : episode.isFailed
            ? _FailedView(episode: episode, onRetry: () => _load())
            : _buildPlayer(isDark, fg, mutedFg, episode),
      ),
    );
  }

  Widget _buildPlayer(
    bool isDark,
    Color fg,
    Color mutedFg,
    AudioEpisode episode,
  ) {
    if (_player == null || _bytes == null) {
      return _DownloadingView(
        progress: _downloadProgress,
        episode: episode,
        isDark: isDark,
        fg: fg,
        mutedFg: mutedFg,
      );
    }
    final player = _player!;
    return Column(
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
              const Spacer(),
              IconButton(
                onPressed: _export,
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export MP3',
              ),
            ],
          ),
        ),
        const SwissDivider(thickness: 2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artwork
                Hero(
                  tag: 'podcast-artwork-${episode.id}',
                  child: _Artwork(title: episode.title),
                ),
                const SizedBox(height: SwissSpacing.lg),
                Text(
                  episode.title.toUpperCase(),
                  style: SwissTypography.section.copyWith(color: fg),
                ),
                const SizedBox(height: SwissSpacing.xs),
                Text(
                  [
                    if (episode.notebookTitle != null) episode.notebookTitle!,
                    kPodcastStyleLabels[episode.style] ?? episode.style,
                  ].join(' · ').toUpperCase(),
                  style: SwissTypography.caption.copyWith(color: mutedFg),
                ),
                const SizedBox(height: SwissSpacing.xl),
                _ProgressBar(player: player, episode: episode),
                const SizedBox(height: SwissSpacing.xs),
                _TimeRow(player: player, episode: episode),
                const SizedBox(height: SwissSpacing.md),
                _Controls(
                  player: player,
                  onToggle: _togglePlay,
                  onCycleSpeed: _cycleSpeed,
                ),
                const SizedBox(height: SwissSpacing.xs),
                _SpeedLabel(speed: player.speed),
                const SizedBox(height: SwissSpacing.xxl),
                const SwissDivider(thickness: 2),
                const SizedBox(height: SwissSpacing.lg),
                _ChaptersTranscript(episode: episode, player: player),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 168,
      height: 168,
      color: isDark ? SwissColors.darkSurface : SwissColors.black,
      alignment: Alignment.center,
      child: const Icon(Icons.headphones, size: 56, color: SwissColors.white),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player, required this.episode});

  final PodcastPlayer player;
  final AudioEpisode episode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnap) {
        final duration =
            durationSnap.data ?? Duration(seconds: episode.durationSec ?? 0);
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
              ),
              child: Slider(
                value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                max: max,
                onChanged: (v) =>
                    player.seek(Duration(milliseconds: v.toInt())),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.player, required this.episode});

  final PodcastPlayer player;
  final AudioEpisode episode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durSnap) {
            final duration =
                durSnap.data ?? Duration(seconds: episode.durationSec ?? 0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(position.inSeconds),
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                  Text(
                    _fmt(duration.inSeconds),
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.player,
    required this.onToggle,
    required this.onCycleSpeed,
  });

  final PodcastPlayer player;
  final VoidCallback onToggle;
  final VoidCallback onCycleSpeed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconButton(
              icon: Icons.replay_10,
              tooltip: 'Back 15 seconds',
              onTap: () => player.seek(position - const Duration(seconds: 15)),
              fg: fg,
            ),
            const SizedBox(width: SwissSpacing.lg),
            _PlayButton(playing: player.playing, onTap: onToggle),
            const SizedBox(width: SwissSpacing.lg),
            _IconButton(
              icon: Icons.forward_10,
              tooltip: 'Forward 15 seconds',
              onTap: () => player.seek(position + const Duration(seconds: 15)),
              fg: fg,
            ),
            const SizedBox(width: SwissSpacing.lg),
            _IconButton(
              icon: Icons.speed,
              tooltip: 'Playback speed',
              onTap: onCycleSpeed,
              fg: fg,
            ),
          ],
        );
      },
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.fg,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(SwissSpacing.md),
        child: Icon(icon, size: 22, color: fg),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        color: SwissColors.red,
        alignment: Alignment.center,
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          size: 34,
          color: SwissColors.white,
        ),
      ),
    );
  }
}

class _SpeedLabel extends StatelessWidget {
  const _SpeedLabel({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    final label = speed == 1.0
        ? '1×'
        : speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '$speed×';
    return Text(label, style: SwissTypography.caption.copyWith(color: mutedFg));
  }
}

class _ChaptersTranscript extends StatelessWidget {
  const _ChaptersTranscript({required this.episode, required this.player});

  final AudioEpisode episode;
  final PodcastPlayer player;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);
    final sections = episode.transcript;
    if (sections.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        final currentHeading = _currentSection(
          sections,
          position.inSeconds,
        )?.heading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CHAPTERS',
              style: SwissTypography.label.copyWith(
                color: mutedFg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SwissSpacing.md),
            for (final s in sections) ...[
              _ChapterRow(
                section: s,
                active: s.heading == currentHeading,
                onTap: () => player.seek(Duration(seconds: s.startSec)),
              ),
              const SizedBox(height: SwissSpacing.xs),
            ],
            const SizedBox(height: SwissSpacing.xxl),
            const SwissDivider(thickness: 1),
            const SizedBox(height: SwissSpacing.lg),
            Text(
              'TRANSCRIPT',
              style: SwissTypography.label.copyWith(
                color: mutedFg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: SwissSpacing.md),
            for (final s in sections) ...[
              _TranscriptBlock(
                section: s,
                onTap: () => player.seek(Duration(seconds: s.startSec)),
              ),
              const SizedBox(height: SwissSpacing.md),
            ],
          ],
        );
      },
    );
  }

  static TranscriptSection? _currentSection(
    List<TranscriptSection> sections,
    int positionSec,
  ) {
    TranscriptSection? current;
    for (final s in sections) {
      if (s.startSec <= positionSec) current = s;
    }
    return current;
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.section,
    required this.active,
    required this.onTap,
  });

  final TranscriptSection section;
  final bool active;
  final VoidCallback onTap;

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
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.sm),
        child: Row(
          children: [
            if (active)
              Container(
                width: 3,
                height: 24,
                margin: const EdgeInsets.only(right: SwissSpacing.sm),
                color: SwissColors.red,
              )
            else
              const SizedBox(width: SwissSpacing.sm + 3),
            Expanded(
              child: Text(
                section.heading.toUpperCase(),
                style: SwissTypography.body.copyWith(
                  color: active ? SwissColors.red : fg,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${section.startSec ~/ 60}:${(section.startSec % 60).toString().padLeft(2, '0')}',
              style: SwissTypography.caption.copyWith(color: mutedFg),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({required this.section, required this.onTap});

  final TranscriptSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwissSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: SwissColors.red,
              width: SwissShapes.borderMedium,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.heading.toUpperCase(),
                    style: SwissTypography.label.copyWith(
                      color: SwissColors.red,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  '${section.startSec ~/ 60}:${(section.startSec % 60).toString().padLeft(2, '0')}',
                  style: SwissTypography.caption.copyWith(color: mutedFg),
                ),
              ],
            ),
            const SizedBox(height: SwissSpacing.xs),
            Text(section.text, style: SwissTypography.body.copyWith(color: fg)),
            if (section.sources.isNotEmpty) ...[
              const SizedBox(height: SwissSpacing.sm),
              for (final source in section.sources)
                SwissCitation(sourceTitle: source),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView({required this.episode});

  final AudioEpisode episode;

  @override
  Widget build(BuildContext context) {
    return SwissProcessingState(
      label: episode.title,
      steps: [
        (label: 'UPLOADED', done: true),
        (
          label: 'SCRIPT',
          done:
              episode.pipelineStage == 'script' ||
              episode.pipelineStage == 'voice' ||
              episode.isReady,
        ),
        (
          label: 'VOICE',
          done: episode.pipelineStage == 'voice' || episode.isReady,
        ),
        (label: 'READY', done: episode.isReady),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.episode, required this.onRetry});

  final AudioEpisode episode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SwissErrorState(
      title: 'EPISODE FAILED',
      message: episode.errorMessage ?? 'Something went wrong.',
      onRetry: onRetry,
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({
    required this.progress,
    required this.episode,
    required this.isDark,
    required this.fg,
    required this.mutedFg,
  });

  final double? progress;
  final AudioEpisode episode;
  final bool isDark;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    final pct = progress == null ? null : (progress! * 100).round();
    return SwissProcessingState(
      label: episode.title,
      steps: [
        (label: 'DOWNLOADING', done: pct != null && pct >= 100),
        (label: 'LOADING', done: false),
      ],
    );
  }
}
