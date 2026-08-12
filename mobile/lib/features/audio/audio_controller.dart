import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_models.dart';
import 'audio_repository.dart';

/// Library state for the "My Audio" screen.
class AudioLibraryState {
  const AudioLibraryState({required this.episodes});

  final List<AudioEpisode> episodes;

  AudioLibraryState copyWith({List<AudioEpisode>? episodes}) {
    return AudioLibraryState(episodes: episodes ?? this.episodes);
  }
}

class AudioController extends AsyncNotifier<AudioLibraryState> {
  @override
  Future<AudioLibraryState> build() async {
    final episodes = await ref.read(audioRepositoryProvider).list();
    return AudioLibraryState(episodes: episodes);
  }

  AudioRepository get _repo => ref.read(audioRepositoryProvider);

  /// Creates a podcast episode and polls the backend until the job is
  /// "ready" or "failed". The [onStage] callback receives the real
  /// pipeline stage the backend reports, so the UI only ever shows stages
  /// the server is actually performing. Throws [AudioException] with the
  /// backend's friendly error when the job fails.
  Future<AudioEpisode> createPodcast(
    String notebookId, {
    String style = 'focused',
    String length = 'standard',
    void Function(String stage)? onStage,
  }) async {
    var episode = await _repo.create(notebookId, style: style, length: length);
    if (episode.isReady) return episode;
    if (episode.isFailed)
      throw AudioException(episode.errorMessage ?? 'Generation failed.');

    // Poll the job. The POST returns immediately (202) and the pipeline
    // runs server-side — never keep the request open client-side.
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (episode.isProcessing && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      episode = await _repo.episode(episode.id);
      onStage?.call(episode.pipelineStage);
    }
    if (episode.isFailed) {
      throw AudioException(
        episode.errorMessage ?? 'Generation failed. Please try again.',
      );
    }
    if (episode.isProcessing) {
      throw const AudioException(
        'Your episode is still being prepared. Check back in a moment.',
      );
    }
    return episode;
  }

  Future<void> delete(String episodeId) async {
    await _repo.delete(episodeId);
    final current = await future;
    state = AsyncData(
      current.copyWith(
        episodes: current.episodes.where((e) => e.id != episodeId).toList(),
      ),
    );
  }

  /// Adds or refreshes an episode in the list (used after generation and
  /// after the player saves a playback position).
  void upsert(AudioEpisode episode) {
    final current = state.valueOrNull;
    if (current == null) return;
    final rest = current.episodes.where((e) => e.id != episode.id).toList();
    state = AsyncData(AudioLibraryState(episodes: [episode, ...rest]));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final episodes = await _repo.list();
    state = AsyncData(AudioLibraryState(episodes: episodes));
  }
}

final audioControllerProvider =
    AsyncNotifierProvider<AudioController, AudioLibraryState>(
      AudioController.new,
    );
