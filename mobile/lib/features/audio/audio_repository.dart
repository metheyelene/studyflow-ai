import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/networking/api_client.dart';
import 'audio_models.dart';

/// Podcast data access. [AudioException] carries a user-safe message.
abstract class AudioRepository {
  Future<List<AudioEpisode>> list();
  Future<AudioEpisode> create(String notebookId, {String style, String length});
  Future<AudioEpisode> episode(String episodeId);
  Future<void> savePosition(String episodeId, int positionSec);
  Future<void> delete(String episodeId);
  /// Download the generated MP3 through the authenticated client (the
  /// player plays these bytes — the stream endpoint is cookie-authed, so
  /// a bare media element can't fetch it cross-origin).
  Future<Uint8List> download(String episodeId, {void Function(int, int?)? onProgress});
}

class ApiAudioRepository implements AudioRepository {
  ApiAudioRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<AudioEpisode>> list() async {
    final res = await _client.get<dynamic>('/api/audio');
    final data = res.data;
    final list = data is Map ? data['episodes'] : null;
    if (list is! List) throw const AudioException('Could not load your audio library.');
    return [
      for (final e in list)
        if (e is Map) AudioEpisode.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  @override
  Future<AudioEpisode> create(String notebookId, {String style = 'focused', String length = 'standard'}) async {
    final res = await _client.post<dynamic>('/api/audio', data: {
      'notebookId': notebookId,
      'style': style,
      'length': length,
    });
    final data = res.data;
    if (data is! Map) throw const AudioException('Could not start that podcast.');
    final episode = data['episode'];
    if (episode is! Map) throw const AudioException('Could not start that podcast.');
    return AudioEpisode.fromJson(Map<String, dynamic>.from(episode));
  }

  @override
  Future<AudioEpisode> episode(String episodeId) async {
    final res = await _client.get<dynamic>('/api/audio/$episodeId');
    final data = res.data;
    if (data is! Map) throw const AudioException('Could not load that episode.');
    final episode = data['episode'];
    if (episode is! Map) throw const AudioException('Could not load that episode.');
    return AudioEpisode.fromJson(Map<String, dynamic>.from(episode));
  }

  @override
  Future<void> savePosition(String episodeId, int positionSec) =>
      _client.patch<dynamic>('/api/audio/$episodeId', data: {'playbackPositionSec': positionSec});

  @override
  Future<void> delete(String episodeId) => _client.delete<dynamic>('/api/audio/$episodeId');

  @override
  Future<Uint8List> download(String episodeId, {void Function(int, int?)? onProgress}) async {
    final res = await _client.get<dynamic>(
      '/api/audio/$episodeId/stream',
      onReceiveProgress: onProgress,
      asBytes: true,
    );
    final body = res.data;
    if (body is! Uint8List) throw const AudioException('Could not download that episode.');
    return body;
  }
}

class AudioException implements Exception {
  const AudioException(this.message);
  final String message;
}

final audioRepositoryProvider = Provider<AudioRepository>(
  (ref) => ApiAudioRepository(ref.watch(apiClientProvider)),
);
