import 'dart:js_interop';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:web/web.dart' as web;

import 'podcast_player_interface.dart';

/// Web player: plays the downloaded bytes from an in-memory blob URL (the
/// browser's media element can't attach the session cookie to the
/// cross-origin stream endpoint, so we play the authenticated download).
class JustAudioPodcastPlayer implements PodcastPlayer {
  JustAudioPodcastPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(Uint8List bytes) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/mpeg'),
    );
    final url = web.URL.createObjectURL(blob);
    try {
      await _player.setUrl(url);
    } finally {
      web.URL.revokeObjectURL(url);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get completedStream => _player.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  @override
  bool get playing => _player.playing;

  @override
  double get speed => _player.speed;

  @override
  Future<void> dispose() => _player.dispose();
}

PodcastPlayer createPodcastPlayer() => JustAudioPodcastPlayer();
