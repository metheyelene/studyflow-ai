import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'notebooks_controller.dart';
import 'notebook.dart';

/// Notebooks screen — Swiss editorial list of study spaces.
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notebooksControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SwissSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const SwissEyebrow(text: 'Study spaces'),
            const SizedBox(height: SwissSpacing.sm),
            Text(
              'YOUR\nKNOWLEDGE',
              style: SwissTypography.display.copyWith(fontSize: 36),
            ),
            const SizedBox(height: SwissSpacing.xl),

            // Content
            Expanded(
              child: state.when(
                loading: () => const SwissProcessingState(
                  label: 'Loading study spaces',
                ),
                error: (e, _) => SwissErrorState(
                  title: 'Error',
                  message: 'Could not load your study spaces.',
                  onRetry: () =>
                      ref.read(notebooksControllerProvider.notifier).refresh(),
                ),
                data: (notebooks) {
                  if (notebooks.isEmpty) {
                    return SwissEmptyState(
                      sectionNumber: '01',
                      title: 'No study spaces',
                      description:
                          'Create your first study space to start learning.',
                      actionLabel: 'Create',
                      onAction: () => _showCreateSheet(context),
                    );
                  }

                  return ListView.builder(
                    itemCount: notebooks.length,
                    itemBuilder: (context, index) {
                      final notebook = notebooks[index];
                      return _NotebookItem(
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
            const SizedBox(height: SwissSpacing.md),
            SwissButton(
              label: 'Create study space',
              icon: Icons.add,
              variant: SwissButtonVariant.primary,
              fullWidth: true,
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

/// Notebook item — Swiss numbered list.
class _NotebookItem extends StatelessWidget {
  const _NotebookItem({
    required this.notebook,
    required this.onTap,
  });

  final Notebook notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = notebook.sourceCount;

    return Column(
      children: [
        SwissNumberedItem(
          index: notebook.title.hashCode.abs() % 99 + 1,
          title: notebook.title,
          subtitle: count == 1 ? '1 source' : '$count sources',
          onTap: onTap,
        ),
        const SwissHairline(),
      ],
    );
  }
}
