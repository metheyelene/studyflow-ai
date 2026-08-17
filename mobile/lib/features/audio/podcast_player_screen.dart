import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import 'audio_controller.dart';
import 'audio_export.dart';
import 'audio_models.dart';
import 'audio_playback_service.dart';
import 'now_playing.dart';
import 'audio_repository.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Full-screen audio player: downloads the episode through the
/// authenticated client, plays it, remembers the position, exposes
/// chapters + transcript with tap-to-jump, and exports the MP3.
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
      // Best-effort final position save; never blocks teardown.
      unawaited(_savePosition());
    }
    // Intentionally do NOT dispose the player: it is a provider singleton,
    // and playback must continue after this screen pops so the shell's
    // mini-player can take over control (play/pause, reopen).
    super.dispose();
  }

  /// Save the latest tracked position (listener-fed, so no stream read or
  /// dangling timeout timer at teardown).
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
    } catch (_) {
      // Offline/best-effort: resume sync is non-critical.
    }
  }

  Future<void> _load() async {
    try {
      var episode = await _repo.episode(widget.episodeId);
      // A still-processing episode: poll the backend until it resolves.
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
          } catch (_) {
            // Transient poll failure — keep waiting.
          }
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
      // Track position continuously and persist every 5s while listening,
      // so a crash or swipe away never loses the spot.
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
    final g = context.glass;
    final episode = _episode;

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 26, color: g.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'Could not play this episode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
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
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _episode = null;
                          _bytes = null;
                          _downloadProgress = null;
                        });
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
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
            : _buildPlayer(g, episode),
      ),
    );
  }

  Widget _buildPlayer(GlassTheme g, AudioEpisode episode) {
    if (_player == null || _bytes == null) {
      return _DownloadingView(progress: _downloadProgress, episode: episode);
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              children: [
                // Shared element: this artwork is the flight destination
                // of the shell mini-player's artwork (same hero tag), so
                // tapping the mini-player morphs it into the player.
                Hero(
                  tag: 'podcast-artwork-${episode.id}',
                  child: _Artwork(title: episode.title),
                ),
                const SizedBox(height: 18),
                Text(
                  episode.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (episode.notebookTitle != null) episode.notebookTitle!,
                    kPodcastStyleLabels[episode.style] ?? episode.style,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: g.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _ProgressBar(player: player, episode: episode),
                const SizedBox(height: 4),
                _TimeRow(player: player, episode: episode),
                const SizedBox(height: 8),
                _Controls(
                  player: player,
                  onToggle: _togglePlay,
                  onCycleSpeed: _cycleSpeed,
                ),
                const SizedBox(height: 6),
                _SpeedLabel(speed: player.speed),
                const SizedBox(height: 24),
                _ChaptersTranscript(episode: episode, player: player),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── player sub-widgets ───────────────────────────────────────────────

class _Artwork extends StatelessWidget {
  const _Artwork({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    // The gradient + glow are the episode's hero moment, in the warm coral
    // audio accent (the low tier renders a flat tile with no shadow).
    final effects = !g.reducedEffects;
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        gradient: effects
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g.audio, g.audio.withValues(alpha: 0.55)],
              )
            : null,
        color: effects ? null : g.audio,
        borderRadius: BorderRadius.circular(30),
        boxShadow: effects
            ? [
                BoxShadow(
                  color: g.audio.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.headphones,
          size: 56,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
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
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
    final g = context.glass;
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(position.inSeconds),
                    style: TextStyle(color: g.textMuted, fontSize: 12),
                  ),
                  Text(
                    _fmt(duration.inSeconds),
                    style: TextStyle(color: g.textMuted, fontSize: 12),
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
            ),
            const SizedBox(width: 18),
            // `playing` is read fresh each build; toggling setState()s the
            // parent screen so the icon flips immediately.
            _PlayButton(playing: player.playing, onTap: onToggle),
            const SizedBox(width: 18),
            _IconButton(
              icon: Icons.forward_10,
              tooltip: 'Forward 15 seconds',
              onTap: () => player.seek(position + const Duration(seconds: 15)),
            ),
            const SizedBox(width: 18),
            _IconButton(
              icon: Icons.speed,
              tooltip: 'Playback speed',
              onTap: onCycleSpeed,
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
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: g.surfaceSubtle,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 22, color: g.textPrimary),
        ),
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
    final g = context.glass;
    final effects = !g.reducedEffects;
    return Material(
      color: g.audio,
      shape: const CircleBorder(),
      elevation: effects ? 4 : 0,
      shadowColor: g.audio.withValues(alpha: effects ? 0.45 : 0),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            size: 34,
            color: Colors.white,
          ),
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
    final g = context.glass;
    final label = speed == 1.0
        ? '1×'
        : speed == speed.roundToDouble()
        ? '${speed.toInt()}×'
        : '$speed×';
    return Text(label, style: TextStyle(color: g.textMuted, fontSize: 12.5));
  }
}

class _ChaptersTranscript extends StatelessWidget {
  const _ChaptersTranscript({required this.episode, required this.player});

  final AudioEpisode episode;
  final PodcastPlayer player;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chapters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final s in sections) ...[
              _ChapterRow(
                section: s,
                active: s.heading == currentHeading,
                onTap: () => player.seek(Duration(seconds: s.startSec)),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 20),
            Text('Transcript', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tap a paragraph to jump to that moment. Sources shown are the ones that section is grounded in.',
              style: TextStyle(color: g.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            for (final s in sections) ...[
              _TranscriptBlock(
                section: s,
                onTap: () => player.seek(Duration(seconds: s.startSec)),
              ),
              const SizedBox(height: 12),
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
    final g = context.glass;
    return Material(
      color: active ? g.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.play_circle,
                size: 18,
                color: active ? g.primary : g.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.heading,
                  style: TextStyle(
                    color: active ? g.primary : g.textPrimary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${section.startSec ~/ 60}:${(section.startSec % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: g.textMuted, fontSize: 12.5),
              ),
            ],
          ),
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
    final g = context.glass;
    return GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.heading,
                        style: TextStyle(
                          color: g.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${section.startSec ~/ 60}:${(section.startSec % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(color: g.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  section.text,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (section.sources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final source in section.sources)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: g.surfaceSubtle,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            source,
                            style: TextStyle(
                              color: g.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
    final g = context.glass;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              episode.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              kPipelineStageLabels[episode.pipelineStage] ??
                  'Preparing your episode…',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.episode, required this.onRetry});

  final AudioEpisode episode;
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
              Icon(Icons.error, size: 26, color: g.danger),
              const SizedBox(height: 12),
              Text(
                'This episode failed to generate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                episode.errorMessage ?? 'Something went wrong.',
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

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.progress, required this.episode});

  final double? progress;
  final AudioEpisode episode;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final pct = progress == null ? null : (progress! * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              episode.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              pct == null
                  ? 'Loading your episode…'
                  : 'Loading your episode… $pct%',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.textMuted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}
