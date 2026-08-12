import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time.dart';
import '../../core/theme/responsive.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import 'notebook.dart';
import 'notebook_create_sheet.dart';
import 'notebooks_controller.dart';

/// Notebook list — search, create, and open. On phones this is the whole
/// tab; on tablet/desktop it is the left pane of the master-detail split.
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
                    'Notebooks',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                GlassButton(
                  label: 'New',
                  icon: Icons.add,
                  size: GlassButtonSize.small,
                  onPressed: () => showCreateNotebookSheet(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassInput(
              hintText: 'Search notebooks',
              prefixIcon: Icons.search,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 12),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = visible[i];
                    return _NotebookCard(
                      notebook: n,
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
    // Phone: push so back returns to the list. Wide screens already show
    // the detail pane — just update the selected notebook via the URL.
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
    required this.selected,
    required this.onTap,
  });

  final Notebook notebook;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return GlassCard(
      tone: selected ? GlassTone.floating : GlassTone.surface,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: g.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.library_books_outlined,
                    size: 20,
                    color: g.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notebook.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${notebook.sourceCount} sources · updated ${relativeTime(notebook.updatedAt, DateTime.now())}',
                        style: TextStyle(color: g.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: g.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => GlassCard(
        child: Row(
          children: [
            const GlassSkeleton(width: 40, height: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  GlassSkeleton(width: 160, height: 15),
                  SizedBox(height: 8),
                  GlassSkeleton(width: 110, height: 12),
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
    final g = context.glass;
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: g.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load your notebooks',
              style: TextStyle(
                color: g.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              style: TextStyle(color: g.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            GlassButton(
              label: 'Try again',
              icon: Icons.refresh,
              variant: GlassButtonVariant.glass,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hasQuery = false});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: GlassCard(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: g.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.library_books_outlined,
                  size: 26,
                  color: g.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasQuery ? 'No matching notebooks' : 'No notebooks yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                hasQuery
                    ? 'Nothing matches your search. Try a different name or create a new notebook.'
                    : 'Create your first notebook and add your notes — StudyFlow AI will '
                          'answer questions and build flashcards, quizzes, and study guides '
                          'from them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: g.textMuted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (!hasQuery) ...[
                const SizedBox(height: 16),
                GlassButton(
                  label: 'New notebook',
                  icon: Icons.add,
                  onPressed: () => showCreateNotebookSheet(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
