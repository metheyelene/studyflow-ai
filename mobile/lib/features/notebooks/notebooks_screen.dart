import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/responsive.dart';
import 'notebook.dart';
import 'notebook_detail_pane.dart';
import 'notebook_list_pane.dart';
import 'notebooks_controller.dart';

/// Notebooks tab body. Reads the selected notebook from the route id:
/// - phone: list, or detail when a notebook is open (pushed)
/// - tablet/desktop: master-detail — list left, detail right
class NotebooksScreen extends ConsumerWidget {
  const NotebooksScreen({super.key, this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks =
        ref.watch(notebooksControllerProvider).valueOrNull ??
        const <Notebook>[];
    Notebook? selected;
    for (final n in notebooks) {
      if (n.id == selectedId) {
        selected = n;
        break;
      }
    }

    if (context.isPhone) {
      if (selected != null) {
        return NotebookDetailPane(notebook: selected, showBack: true);
      }
      return NotebookListPane(selectedId: null);
    }

    // Master-detail: the list stays visible; the right pane shows the open
    // notebook or a "select a notebook" hint.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 340,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: context.glass.border.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: NotebookListPane(selectedId: selectedId),
          ),
        ),
        Expanded(
          child: selected == null
              ? const _SelectHint()
              : NotebookDetailPane(notebook: selected),
        ),
      ],
    );
  }
}

class _SelectHint extends StatelessWidget {
  const _SelectHint();

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 44,
            color: g.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a notebook',
            style: TextStyle(
              color: g.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
