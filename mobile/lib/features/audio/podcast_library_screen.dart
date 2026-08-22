import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import 'audio_controller.dart';

/// Podcast library screen — Bauhaus editorial list of episodes.
class PodcastLibraryScreen extends ConsumerWidget {
  const PodcastLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(audioControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Audio'),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              'LISTEN\nTO YOUR\nNOTES.',
              style: BauhausTypography.hero.copyWith(fontSize: 36),
            ),
            const SizedBox(height: BauhausSpacing.xl),

            // Content
            Expanded(
              child: asyncState.when(
                loading: () => const BauhausProcessingState(
                  label: 'Loading episodes',
                ),
                error: (e, _) => BauhausErrorState(
                  title: 'Error',
                  message: 'Could not load your episodes.',
                  onRetry: () =>
                      ref.read(audioControllerProvider.notifier).refresh(),
                ),
                data: (state) {
                  if (state.episodes.isEmpty) {
                    return BauhausEmptyState(
                      title: 'No episodes',
                      description:
                          'Generate a podcast from your study spaces to start listening.',
                      composition: const BauhausComposition(
                        width: 120,
                        height: 120,
                        circleColor: BauhausColors.red,
                        squareColor: BauhausColors.yellow,
                        triangleColor: BauhausColors.blue,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: state.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = state.episodes[index];
                      return _EpisodeCard(
                        episode: episode,
                        onTap: () {
                          // TODO: Navigate to episode player
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Episode card — Bauhaus style with audio accent.
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.onTap,
  });

  final dynamic episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BauhausSpacing.md),
      child: BauhausCard(
        accent: BauhausCardAccent.triangle,
        accentColor: BauhausColors.yellow,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              episode.title.toUpperCase(),
              style: BauhausTypography.section.copyWith(fontSize: 22),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            BauhausLine(height: 2, color: BauhausColors.muted),
            const SizedBox(height: BauhausSpacing.sm),
            Row(
              children: [
                BauhausEyebrow(
                  text: episode.style?.toUpperCase() ?? 'STANDARD',
                ),
                const SizedBox(width: BauhausSpacing.md),
                if (episode.durationSec != null)
                  BauhausEyebrow(
                    text: '${(episode.durationSec / 60).round()} MIN',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
