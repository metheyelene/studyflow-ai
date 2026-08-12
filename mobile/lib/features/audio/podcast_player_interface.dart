import 'dart:async';
import 'dart:typed_data';

/// Playback abstraction so screens (and tests) never touch the concrete
/// player. Episodes are downloaded through the authenticated API client
/// and played from bytes — a bare media element cannot send the session
/// cookie cross-origin, so there is no streaming URL to point it at.
abstract class PodcastPlayer {
  Future<void> load(Uint8List bytes);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<void> get completedStream;
  bool get playing;
  double get speed;
  Future<void> dispose();
}
