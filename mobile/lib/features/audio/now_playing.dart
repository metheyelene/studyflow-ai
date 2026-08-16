import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_playback_service.dart';

/// How long the collapsed (completed) mini-player pill lingers before it
/// auto-dismisses. Long enough to replay or reopen, short enough that a
/// finished episode never parks on screen forever.
const Duration kCollapsedDismissAfter = Duration(seconds: 10);

/// What is currently playing, surfaced globally so the shell can float a
/// mini-player above navigation after the user leaves the full-screen
/// player. The full-screen player publishes here on load and on every
/// play/pause toggle; the mini-player reads it and drives the same
/// singleton [PodcastPlayer] through the notifier.
class NowPlaying {
  const NowPlaying({
    required this.episodeId,
    required this.title,
    required this.subtitle,
    required this.playing,
    this.progress = 0,
    this.completed = false,
  });

  final String episodeId;
  final String title;
  final String subtitle;
  final bool playing;

  /// 0..1 fraction of the current episode (driven by the player's own
  /// position stream, so it is real progress, not a clock).
  final double progress;

  /// True when the player reported completion — the mini-player collapses.
  final bool completed;

  NowPlaying copyWith({bool? playing, double? progress, bool? completed}) =>
      NowPlaying(
        episodeId: episodeId,
        title: title,
        subtitle: subtitle,
        playing: playing ?? this.playing,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
      );
}

class NowPlayingController extends Notifier<NowPlaying?> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _completedSub;
  Timer? _dismissTimer;
  Duration _duration = Duration.zero;

  @override
  NowPlaying? build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _durationSub?.cancel();
      _completedSub?.cancel();
      _dismissTimer?.cancel();
    });
    return null;
  }

  void _cancelDismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  /// Called by the full-screen player once playback actually starts. Tracks
  /// real position/duration while playing so the mini-player's progress bar
  /// keeps moving after the user leaves the screen.
  void setEpisode({
    required String episodeId,
    required String title,
    required String subtitle,
  }) {
    _cancelDismiss();
    _duration = Duration.zero;
    _subscribe();
    state = NowPlaying(
      episodeId: episodeId,
      title: title,
      subtitle: subtitle,
      playing: true,
    );
  }

  void setPlaying(bool playing) {
    final cur = state;
    if (cur == null) return;
    _cancelDismiss();
    if (playing) {
      _subscribe();
    } else {
      _unsubscribe();
    }
    state = cur.copyWith(playing: playing, completed: false);
  }

  /// Scrub to a fraction of the current episode (driven live by the
  /// mini-player's draggable playhead). Seeks the real player and snaps
  /// the tracked progress so the bar matches the finger immediately.
  Future<void> seekToFraction(double fraction) async {
    final cur = state;
    if (cur == null || _duration.inMilliseconds <= 0) return;
    final f = fraction.clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (f * _duration.inMilliseconds).round(),
    );
    await ref.read(podcastPlayerProvider).seek(target);
    state = cur.copyWith(progress: f);
  }

  /// Restart the finished episode from zero (the collapsed mini-player's
  /// action) and resume live progress.
  Future<void> replay() async {
    _cancelDismiss();
    final player = ref.read(podcastPlayerProvider);
    await player.seek(Duration.zero);
    await player.play();
    _subscribe();
    final cur = state;
    if (cur != null) {
      state = cur.copyWith(playing: true, completed: false, progress: 0);
    }
  }

  /// Subscribe to the player's streams (duration + position + completion).
  /// Safe to call repeatedly — previous subscriptions are dropped first, so
  /// a replay followed by another completion still collapses correctly.
  void _subscribe() {
    _unsubscribe();
    final player = ref.read(podcastPlayerProvider);
    _durationSub = player.durationStream.listen((d) {
      if (d != null) _duration = d;
    });
    _positionSub = player.positionStream.listen((p) {
      final cur = state;
      if (cur == null) return;
      final frac = _duration.inMilliseconds > 0
          ? (p.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      state = cur.copyWith(progress: frac);
    });
    _completedSub = player.completedStream.listen((_) {
      final cur = state;
      if (cur == null) return;
      // Playback finished: freeze progress, collapse the mini-player.
      _positionSub?.cancel();
      _positionSub = null;
      state = cur.copyWith(playing: false, completed: true, progress: 1);
      // Auto-dismiss the collapsed pill after a quiet spell, unless the
      // user replays or opens the player first.
      _cancelDismiss();
      _dismissTimer = Timer(kCollapsedDismissAfter, () {
        if (state?.completed ?? false) state = null;
        _dismissTimer = null;
      });
    });
  }

  void _unsubscribe() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _completedSub?.cancel();
    _completedSub = null;
  }
}

final nowPlayingProvider = NotifierProvider<NowPlayingController, NowPlaying?>(
  NowPlayingController.new,
);
