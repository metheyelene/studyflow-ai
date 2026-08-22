import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'notebook_create_sheet.dart';
import 'notebook_detail_pane.dart';
import 'notebooks_controller.dart';
import 'notebook.dart';

/// Notebooks screen — Swiss editorial list of study spaces.
/// When [selectedId] is provided, shows the notebook detail pane.
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notebooksControllerProvider);

    return SafeArea(
      child: state.when(
        loading: () => const Center(
          child: SwissProcessingState(label: 'Loading study spaces'),
        ),
        error: (e, _) => Center(
          child: SwissErrorState(
            title: 'Error',
            message: 'Could not load your study spaces.',
            onRetry: () =>
                ref.read(notebooksControllerProvider.notifier).refresh(),
          ),
        ),
        data: (notebooks) {
          if (selectedId != null) {
            final notebook =
                notebooks.where((n) => n.id == selectedId).firstOrNull;
            if (notebook != null) {
              return NotebookDetailPane(notebook: notebook, showBack: true);
            }
          }

          return _NotebooksList(
            notebooks: notebooks,
            onRefresh: () =>
                ref.read(notebooksControllerProvider.notifier).refresh(),
          );
        },
      ),
    );
  }
}

/// Notebook list — Swiss editorial layout.
class _NotebooksList extends StatelessWidget {
  const _NotebooksList({
    required this.notebooks,
    required this.onRefresh,
  });

  final List<Notebook> notebooks;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: notebooks.isEmpty
                ? SwissEmptyState(
                    sectionNumber: '01',
                    title: 'No study spaces',
                    description:
                        'Create your first study space to start learning.',
                    actionLabel: 'Create',
                    onAction: () => _showCreateSheet(context),
                  )
                : ListView.builder(
                    itemCount: notebooks.length,
                    itemBuilder: (context, index) {
                      final notebook = notebooks[index];
                      return _NotebookItem(
                        notebook: notebook,
                        onTap: () =>
                            context.push('/notebooks/${notebook.id}'),
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
    );
  }

  void _showCreateSheet(BuildContext context) {
    showCreateNotebookSheet(context);
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
