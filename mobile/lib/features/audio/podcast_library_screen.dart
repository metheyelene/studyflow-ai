import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'audio_controller.dart';

/// Podcast library screen — Swiss editorial list of episodes.
class PodcastLibraryScreen extends ConsumerWidget {
  const PodcastLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(audioControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              onPressed: () => context.popOrHome(),
              tooltip: 'Back',
            ),
            const SizedBox(height: SwissSpacing.lg),

            const SwissEyebrow(text: 'Audio'),
            const SizedBox(height: SwissSpacing.sm),
            Text('LISTEN\nTO YOUR\nNOTES.', style: SwissTypography.display.copyWith(fontSize: 36)),
            const SizedBox(height: SwissSpacing.xl),
            Expanded(
              child: asyncState.when(
                loading: () => const SwissProcessingState(label: 'Loading episodes'),
                error: (e, _) => SwissErrorState(title: 'Error', message: 'Could not load your episodes.',
                  onRetry: () => ref.read(audioControllerProvider.notifier).refresh()),
                data: (state) {
                  if (state.episodes.isEmpty) {
                    return SwissEmptyState(sectionNumber: '01', title: 'No episodes',
                      description: 'Generate a podcast from your study spaces to start listening.');
                  }
                  return ListView.builder(
                    itemCount: state.episodes.length,
                    itemBuilder: (context, index) {
                      final ep = state.episodes[index];
                      return Column(children: [
                        SwissNumberedItem(
                          index: index + 1, title: ep.title,
                          subtitle: '${ep.style.toUpperCase()}${ep.durationSec != null ? " · ${(ep.durationSec! / 60).round()} MIN" : ""}',
                          onTap: () => context.push('${AppRoutes.audio}/${ep.id}'),
                        ),
                        const SwissHairline(),
                      ]);
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
