import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'podcast_player_interface.dart';

/// Native (Android/iOS) player: writes the downloaded MP3 to a temp file
/// and plays it with just_audio, so seeking, speed, and resume all work
/// against a local file.
class JustAudioPodcastPlayer implements PodcastPlayer {
  JustAudioPodcastPlayer([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/studyflow_episode_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await file.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(file.path);
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
