import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../core/utils/time.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'notebook.dart';
import 'notebook_create_sheet.dart';
import 'notebooks_controller.dart';

/// Notebook list — search, create, and open.
class NotebookListPane extends ConsumerStatefulWidget {
  const NotebookListPane({super.key, required this.selectedId});

  final String? selectedId;

  @override
  ConsumerState<NotebookListPane> createState() => _NotebookListPaneState();
}

class _NotebookListPaneState extends ConsumerState<NotebookListPane> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncNotebooks = ref.watch(notebooksControllerProvider);
    final query = _query.trim().toLowerCase();
    final selectedId = widget.selectedId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'NOTEBOOKS',
                    style: SwissTypography.section.copyWith(color: fg),
                  ),
                ),
                SwissButton(
                  label: 'New',
                  icon: Icons.add,
                  compact: true,
                  onPressed: () => showCreateNotebookSheet(context),
                ),
              ],
            ),
          ),
          const SwissDivider(thickness: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, SwissSpacing.md, 20, 0),
            child: SwissInput(
              hintText: 'Search notebooks',
              prefixIcon: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: SwissSpacing.md),
          Expanded(
            child: asyncNotebooks.when(
              loading: () => const _LoadingState(),
              error: (_, _) => _ErrorState(
                onRetry: () =>
                    ref.read(notebooksControllerProvider.notifier).refresh(),
              ),
              data: (notebooks) {
                final visible = query.isEmpty
                    ? notebooks
                    : [
                        for (final n in notebooks)
                          if (n.title.toLowerCase().contains(query)) n,
                      ];
                if (visible.isEmpty) {
                  return _EmptyState(hasQuery: query.isNotEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SwissHairline(),
                  itemBuilder: (context, i) {
                    final n = visible[i];
                    return _NotebookCard(
                      notebook: n,
                      index: i + 1,
                      selected: n.id == selectedId,
                      onTap: () => _open(context, n),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Notebook notebook) {
    final path = AppRoutes.notebookDetail.replaceFirst(':id', notebook.id);
    if (context.isPhone) {
      context.push(path);
    } else {
      context.go(path);
    }
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final Notebook notebook;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: SwissSpacing.md,
          horizontal: 0,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: selected ? SwissColors.red : Colors.transparent,
              width: SwissShapes.borderMedium,
            ),
          ),
        ),
        child: Row(
          children: [
            // Index number
            SizedBox(
              width: 36,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: SwissTypography.label.copyWith(
                  color: selected ? SwissColors.red : mutedFg,
                ),
              ),
            ),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notebook.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwissTypography.subheading.copyWith(
                      color: fg,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xxs),
                  Text(
                    '${notebook.sourceCount} SOURCES · UPDATED ${relativeTime(notebook.updatedAt, DateTime.now())}',
                    style: SwissTypography.caption.copyWith(color: mutedFg),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: mutedFg),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SwissHairline(),
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: SwissSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 15,
              color: isDark ? SwissColors.darkMuted : SwissColors.muted,
            ),
            const SizedBox(width: SwissSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 15,
                    color: isDark ? SwissColors.darkMuted : SwissColors.muted,
                  ),
                  const SizedBox(height: SwissSpacing.xs),
                  Container(
                    width: 110,
                    height: 12,
                    color: isDark ? SwissColors.darkMuted : SwissColors.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SwissErrorState(
      title: 'COULD NOT LOAD YOUR NOTEBOOKS',
      message: 'Check your connection and try again.',
      onRetry: onRetry,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hasQuery = false});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return SwissEmptyState(
      sectionNumber: '01',
      title: hasQuery ? 'NO MATCHING NOTEBOOKS' : 'NO NOTEBOOKS YET',
      description: hasQuery
          ? 'Nothing matches your search. Try a different name or create a new notebook.'
          : 'Create your first notebook and add your notes — StudyFlow AI will '
                'answer questions and build flashcards, quizzes, and study guides from them.',
      actionLabel: hasQuery ? null : 'New notebook',
      onAction: hasQuery ? null : () => showCreateNotebookSheet(context),
    );
  }
}
