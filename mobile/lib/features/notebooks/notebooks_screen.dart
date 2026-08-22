import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bauhaus_tokens.dart';
import '../../shared/widgets/bauhaus/bauhaus.dart';
import 'notebooks_controller.dart';
import 'notebook.dart';

/// Notebooks screen — Bauhaus editorial list of study spaces.
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notebooksControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BauhausSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const BauhausEyebrow(text: 'Study spaces'),
            const SizedBox(height: BauhausSpacing.sm),
            Text(
              'YOUR\nKNOWLEDGE',
              style: BauhausTypography.hero.copyWith(fontSize: 36),
            ),
            const SizedBox(height: BauhausSpacing.xl),

            // Content
            Expanded(
              child: state.when(
                loading: () => const BauhausProcessingState(
                  label: 'Loading study spaces',
                ),
                error: (e, _) => BauhausErrorState(
                  title: 'Error',
                  message: 'Could not load your study spaces.',
                  onRetry: () =>
                      ref.read(notebooksControllerProvider.notifier).refresh(),
                ),
                data: (notebooks) {
                  if (notebooks.isEmpty) {
                    return BauhausEmptyState(
                      title: 'No study spaces',
                      description:
                          'Create your first study space to start learning.',
                      actionLabel: 'Create',
                      onAction: () => _showCreateSheet(context),
                      composition: const BauhausComposition(
                        width: 140,
                        height: 140,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notebooks.length,
                    itemBuilder: (context, index) {
                      final notebook = notebooks[index];
                      return _NotebookCard(
                        notebook: notebook,
                        onTap: () =>
                            context.push('/notebooks/${notebook.id}'),
                      );
                    },
                  );
                },
              ),
            ),

            // Create button
            const SizedBox(height: BauhausSpacing.md),
            BauhausButton(
              label: 'Create study space',
              icon: Icons.add,
              variant: BauhausButtonVariant.primary,
              expand: true,
              onPressed: () => _showCreateSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    // TODO: Show create notebook sheet
  }
}

/// Notebook card — Bauhaus style with geometric accent.
class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.onTap,
  });

  final Notebook notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = notebook.sourceCount;
    final accents = [
      BauhausCardAccent.circle,
      BauhausCardAccent.square,
      BauhausCardAccent.triangle,
    ];
    final accentColors = [
      BauhausColors.red,
      BauhausColors.blue,
      BauhausColors.yellow,
    ];
    final accentIndex = notebook.title.hashCode.abs() % 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: BauhausSpacing.md),
      child: BauhausCard(
        accent: accents[accentIndex],
        accentColor: accentColors[accentIndex],
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notebook.title.toUpperCase(),
              style: BauhausTypography.section.copyWith(fontSize: 22),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: BauhausSpacing.sm),
            BauhausHairline(),
            const SizedBox(height: BauhausSpacing.sm),
            Row(
              children: [
                BauhausEyebrow(
                  text: count == 1 ? '1 source' : '$count sources',
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: BauhausColors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
